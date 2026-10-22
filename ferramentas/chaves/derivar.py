#!/usr/bin/env python3
"""Deriva as chaves da plataforma a partir de UM segredo: CHAVE_MESTRA.

Por que assim: o dono ainda não tem cofre de senhas. O único segredo que
existe é a CHAVE_MESTRA, guardada nos segredos do GitHub (Settings > Secrets
and variables > Actions) e numa cópia em papel com o dono. Tudo o mais nasce
dela, sempre igual, e nunca é gravado em lugar nenhum:

  segredo <rotulo>          senha forte para um uso (ex.: frota-backup-v1 é a
                            senha que cifra o backup). Sai só na saída padrão,
                            para ser capturada por $(...) e mascarada.
  chave-android <pasta>     chave de assinatura dos APKs (RSA 3072) e o
                            certificado dela. O certificado sai sempre igual
                            (datas e número fixos), então todo APK da esteira
                            tem a mesma assinatura e o celular aceita a
                            atualização. Imprime só a impressão digital
                            (SHA-256) do certificado, que é pública.
  impressao-android         só a impressão digital, sem gravar nada.

Sem bibliotecas de fora: só a biblioteca padrão do Python 3.8+.
Trocar a CHAVE_MESTRA muda TODAS as chaves: os APKs passam a ter outra
assinatura (reinstalar uma vez) e os backups antigos só abrem com a chave antiga.
"""
from __future__ import annotations

import base64
import hashlib
import hmac
import os
import pathlib
import sys

SAL = b"plataforma-gestao-frota/chave-mestra/v1"
MINIMO = 24


def raiz() -> bytes:
    chave = os.environ.get("CHAVE_MESTRA", "")
    if len(chave) < MINIMO:
        sys.exit(f"CHAVE_MESTRA ausente ou curta (mínimo {MINIMO} caracteres).")
    # scrypt deixa cada tentativa de adivinhar a chave lenta e cara.
    return hashlib.scrypt(chave.encode("utf-8"), salt=SAL, n=2**17, r=8, p=1,
                          maxmem=256 * 1024 * 1024, dklen=32)


def derivar(r: bytes, rotulo: str) -> bytes:
    return hmac.new(r, rotulo.encode("utf-8"), hashlib.sha256).digest()


# --------------------------------------------------------------- RSA determinístico

class Fluxo:
    """Bytes pseudoaleatórios determinísticos (SHAKE-256 em modo contador)."""

    def __init__(self, semente: bytes):
        self.semente = semente
        self.contador = 0

    def ler(self, n: int) -> bytes:
        self.contador += 1
        return hashlib.shake_256(self.semente + self.contador.to_bytes(8, "big")).digest(n)

    def inteiro(self, bits: int) -> int:
        return int.from_bytes(self.ler((bits + 7) // 8), "big") >> ((8 - bits % 8) % 8)


PRIMOS_PEQUENOS = [p for p in range(3, 2000) if all(p % d for d in range(2, int(p ** 0.5) + 1))]


def provavel_primo(n: int, fluxo: Fluxo, rodadas: int = 64) -> bool:
    if any(n % p == 0 for p in PRIMOS_PEQUENOS):
        return n in PRIMOS_PEQUENOS
    d, s = n - 1, 0
    while d % 2 == 0:
        d //= 2
        s += 1
    for _ in range(rodadas):
        a = 2 + fluxo.inteiro(n.bit_length()) % (n - 3)
        x = pow(a, d, n)
        if x in (1, n - 1):
            continue
        for _ in range(s - 1):
            x = pow(x, 2, n)
            if x == n - 1:
                break
        else:
            return False
    return True


def gerar_primo(bits: int, fluxo: Fluxo, e: int) -> int:
    while True:
        c = fluxo.inteiro(bits) | (3 << (bits - 2)) | 1
        if provavel_primo(c, fluxo) and (c - 1) % e != 0:
            return c


def gerar_rsa(semente: bytes, bits: int = 3072, e: int = 65537):
    fluxo = Fluxo(semente)
    while True:
        p = gerar_primo(bits // 2, fluxo, e)
        q = gerar_primo(bits // 2, fluxo, e)
        if p == q or abs(p - q).bit_length() < bits // 2 - 100:
            continue
        if p < q:
            p, q = q, p
        n = p * q
        if n.bit_length() != bits:
            continue
        fi = (p - 1) * (q - 1)
        d = pow(e, -1, fi)
        return n, e, d, p, q


# ------------------------------------------------------------------- DER mínimo

def _tamanho(n: int) -> bytes:
    if n < 0x80:
        return bytes([n])
    b = n.to_bytes((n.bit_length() + 7) // 8, "big")
    return bytes([0x80 | len(b)]) + b


def tlv(tag: int, conteudo: bytes) -> bytes:
    return bytes([tag]) + _tamanho(len(conteudo)) + conteudo


def inteiro(v: int) -> bytes:
    b = v.to_bytes(v.bit_length() // 8 + 1, "big")  # +1 byte: nunca negativo
    while len(b) > 1 and b[0] == 0 and b[1] < 0x80:
        b = b[1:]
    return tlv(0x02, b)


def seq(*partes: bytes) -> bytes:
    return tlv(0x30, b"".join(partes))


def conjunto(*partes: bytes) -> bytes:
    return tlv(0x31, b"".join(partes))


def oid(texto: str) -> bytes:
    nums = [int(x) for x in texto.split(".")]
    corpo = bytes([nums[0] * 40 + nums[1]])
    for n in nums[2:]:
        partes = [n & 0x7F]
        n >>= 7
        while n:
            partes.insert(0, 0x80 | (n & 0x7F))
            n >>= 7
        corpo += bytes(partes)
    return tlv(0x06, corpo)


NULO = b"\x05\x00"
RSA = seq(oid("1.2.840.113549.1.1.1"), NULO)
SHA256_RSA = seq(oid("1.2.840.113549.1.1.11"), NULO)


def nome(cn: str, o: str, c: str) -> bytes:
    return seq(
        conjunto(seq(oid("2.5.4.6"), tlv(0x13, c.encode()))),
        conjunto(seq(oid("2.5.4.10"), tlv(0x0C, o.encode("utf-8")))),
        conjunto(seq(oid("2.5.4.3"), tlv(0x0C, cn.encode("utf-8")))),
    )


def chave_publica_der(n: int, e: int) -> bytes:
    return seq(RSA, tlv(0x03, b"\x00" + seq(inteiro(n), inteiro(e))))


def assinar_pkcs1_sha256(dados: bytes, n: int, d: int) -> bytes:
    resumo = seq(seq(oid("2.16.840.1.101.3.4.2.1"), NULO), tlv(0x04, hashlib.sha256(dados).digest()))
    k = (n.bit_length() + 7) // 8
    em = b"\x00\x01" + b"\xff" * (k - len(resumo) - 3) + b"\x00" + resumo
    return pow(int.from_bytes(em, "big"), d, n).to_bytes(k, "big")


def certificado(n: int, e: int, d: int, serie: int) -> bytes:
    emissor = nome("Plataforma de Gestao de Frota", "Fortaleza Digital Security", "BR")
    spki = chave_publica_der(n, e)
    ski = hashlib.sha1(seq(inteiro(n), inteiro(e))).digest()
    extensoes = tlv(0xA3, seq(
        seq(oid("2.5.29.14"), tlv(0x04, tlv(0x04, ski))),
        seq(oid("2.5.29.19"), tlv(0x04, seq())),
    ))
    validade = seq(tlv(0x17, b"260101000000Z"), tlv(0x18, b"20760101000000Z"))
    tbs = seq(tlv(0xA0, inteiro(2)), inteiro(serie), SHA256_RSA, emissor, validade, emissor, spki, extensoes)
    return seq(tbs, SHA256_RSA, tlv(0x03, b"\x00" + assinar_pkcs1_sha256(tbs, n, d)))


def chave_privada_der(n, e, d, p, q) -> bytes:
    return seq(inteiro(0), inteiro(n), inteiro(e), inteiro(d), inteiro(p), inteiro(q),
               inteiro(d % (p - 1)), inteiro(d % (q - 1)), inteiro(pow(q, -1, p)))


def pem(rotulo: str, der: bytes) -> str:
    b64 = base64.encodebytes(der).decode().replace("\n", "")
    linhas = [b64[i:i + 64] for i in range(0, len(b64), 64)]
    return f"-----BEGIN {rotulo}-----\n" + "\n".join(linhas) + f"\n-----END {rotulo}-----\n"


def chave_android(r: bytes):
    semente = derivar(r, "frota-assinatura-android-v1")
    n, e, d, p, q = gerar_rsa(semente)
    serie = int.from_bytes(derivar(r, "frota-assinatura-serie-v1")[:8], "big") >> 1 or 1
    cert = certificado(n, e, d, serie)
    return cert, chave_privada_der(n, e, d, p, q)


def impressao(cert: bytes) -> str:
    return ":".join(f"{b:02X}" for b in hashlib.sha256(cert).digest())


def main(args: list[str]) -> None:
    if not args:
        sys.exit(__doc__)
    r = raiz()
    if args[0] == "segredo" and len(args) == 2:
        print(derivar(r, args[1]).hex())
    elif args[0] == "chave-android" and len(args) == 2:
        pasta = pathlib.Path(args[1])
        pasta.mkdir(parents=True, exist_ok=True)
        cert, priv = chave_android(r)
        alvo = pasta / "chave.pem"
        fd = os.open(alvo, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
        with os.fdopen(fd, "w") as f:
            f.write(pem("RSA PRIVATE KEY", priv))
        (pasta / "certificado.pem").write_text(pem("CERTIFICATE", cert))
        print(impressao(cert))
    elif args[0] == "impressao-android":
        print(impressao(chave_android(r)[0]))
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main(sys.argv[1:])
