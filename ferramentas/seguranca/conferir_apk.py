#!/usr/bin/env python3
"""Confere que o APK não leva nenhum segredo do servidor.

Procura dentro de todos os arquivos do APK:
  - chave secreta do Supabase (sb_secret_...);
  - token JWT com papel service_role (a chave antiga do servidor);
  - chave de assinatura ou arquivo de chave (.jks, .keystore, .p12, .pem).
A chave pública (sb_publishable_...) pode estar: ela é feita para os apps.
Nunca imprime o segredo achado, só o tipo e o arquivo.
Uso: python3 ferramentas/seguranca/conferir_apk.py app-release.apk
"""
import base64
import json
import re
import sys
import zipfile

SECRETA = re.compile(rb"sb_secret_[A-Za-z0-9_-]{10,}")
JWT = re.compile(rb"eyJ[A-Za-z0-9_-]{10,}\.(eyJ[A-Za-z0-9_-]{10,})\.[A-Za-z0-9_-]{10,}")
ARQUIVOS_CHAVE = re.compile(r"\.(jks|keystore|p12|pfx|pem)$", re.I)


def papel(parte: bytes) -> str:
    try:
        dados = base64.urlsafe_b64decode(parte + b"=" * (-len(parte) % 4))
        return str(json.loads(dados).get("role", ""))
    except Exception:
        return ""


def main(apk: str) -> int:
    achados = []
    with zipfile.ZipFile(apk) as z:
        for nome in z.namelist():
            if ARQUIVOS_CHAVE.search(nome):
                achados.append(("arquivo de chave", nome))
            dados = z.read(nome)
            if SECRETA.search(dados):
                achados.append(("chave secreta do Supabase", nome))
            for m in JWT.finditer(dados):
                if papel(m.group(1)) == "service_role":
                    achados.append(("token service_role", nome))
        total = len(z.namelist())
    print(f"arquivos conferidos no APK: {total}; segredos achados: {len(achados)}")
    for tipo, nome in achados:
        print(f"::error::{tipo} dentro do APK em {nome}")
    return 1 if achados else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
