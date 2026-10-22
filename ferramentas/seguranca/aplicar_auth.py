#!/usr/bin/env python3
"""Aplica as regras de login (supabase/auth-nuvem.json) no Supabase da nuvem.

Usa a Management API com SUPABASE_ACCESS_TOKEN (segredo do GitHub). Só mexe
nos campos do arquivo e só imprime esses campos: a configuração completa tem
segredos (por exemplo a senha do e-mail) e nunca aparece no registro.
Uso: PROJETO=ref python3 ferramentas/seguranca/aplicar_auth.py supabase/auth-nuvem.json
"""
import json
import os
import sys
import urllib.error
import urllib.request


def chamar(metodo: str, corpo: dict | None = None) -> dict:
    url = f"https://api.supabase.com/v1/projects/{os.environ['PROJETO']}/config/auth"
    pedido = urllib.request.Request(url, method=metodo, data=json.dumps(corpo).encode() if corpo else None, headers={
        "Authorization": f"Bearer {os.environ['SUPABASE_ACCESS_TOKEN']}",
        "Content-Type": "application/json",
        "User-Agent": "plataforma-gestao-frota",
    })
    with urllib.request.urlopen(pedido, timeout=60) as r:
        return json.load(r)


def main(caminho: str) -> int:
    alvo = json.load(open(caminho, encoding="utf-8"))
    atual = chamar("GET")
    mudar = {k: v for k, v in alvo["config"].items() if atual.get(k) != v}
    for k in alvo["config"]:
        print(f"{k}: {atual.get(k)!r} -> {alvo['config'][k]!r}" if k in mudar else f"{k}: já está {atual.get(k)!r}")
    if mudar:
        chamar("PATCH", mudar)
        print(f"regras de login atualizadas: {len(mudar)}")
    for k, v in alvo.get("somente_pago", {}).items():
        if atual.get(k) == v:
            print(f"{k}: já está {v!r}")
            continue
        try:
            chamar("PATCH", {k: v})
            print(f"{k}: aplicado {v!r}")
        except urllib.error.HTTPError as e:
            print(f"::notice::{k} não foi aplicado (HTTP {e.code}); costuma exigir o plano Pro do Supabase.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
