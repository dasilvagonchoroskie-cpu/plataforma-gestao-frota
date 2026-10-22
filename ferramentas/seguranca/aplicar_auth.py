#!/usr/bin/env python3
"""Aplica as regras de login (supabase/auth-nuvem.json) no Supabase da nuvem.

Usa a Management API com SUPABASE_ACCESS_TOKEN (segredo do GitHub). Só mexe
nos campos do arquivo e só imprime esses campos: a configuração completa tem
segredos (por exemplo a senha do e-mail) e nunca aparece no registro.
Uso: PROJETO=ref [PAINEL_URL=https://.../] python3 ferramentas/seguranca/aplicar_auth.py supabase/auth-nuvem.json
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
    raiz = os.path.dirname(os.path.dirname(os.path.abspath(caminho)))
    for campo, arquivo in alvo.get("modelos", {}).items():
        alvo["config"][campo] = open(os.path.join(raiz, arquivo), encoding="utf-8").read()
    # Painel em outro endereço (repositório público só do painel): os links dos
    # e-mails passam a abrir lá; o endereço antigo continua aceito.
    painel = os.environ.get("PAINEL_URL", "").strip()
    if painel:
        antigos = [u for u in alvo["config"].get("uri_allow_list", "").split(",") if u]
        alvo["config"]["site_url"] = painel
        alvo["config"]["uri_allow_list"] = ",".join([painel + "**"] + [u for u in antigos if u != painel + "**"])
    atual = chamar("GET")
    mudar = {k: v for k, v in alvo["config"].items() if atual.get(k) != v}
    for k in alvo["config"]:
        if k in alvo.get("modelos", {}):
            print(f"{k}: {'atualizado' if k in mudar else 'já está'} ({len(alvo['config'][k])} caracteres)")
        else:
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
    conferir_smtp(atual)
    return 0


def conferir_smtp(atual: dict) -> None:
    """Só confere o e-mail próprio (SMTP), que o dono configura no painel do
    Supabase. Nunca imprime a senha nem o usuário do SMTP; do remetente, só o
    domínio."""
    host = atual.get("smtp_host") or ""
    if not host:
        print("::warning::E-mail próprio (SMTP) desligado: os links de senha só chegam para a equipe do "
              "projeto, no máximo 2 por hora (docs/EMAIL.md).")
        return
    remetente = (atual.get("smtp_admin_email") or "").split("@")[-1] or "(vazio)"
    print(f"e-mail próprio (SMTP): ligado | servidor {host}:{atual.get('smtp_port')} | "
          f"remetente @{remetente} | nome {atual.get('smtp_sender_name')!r} | "
          f"usuário {'preenchido' if atual.get('smtp_user') else 'VAZIO'} | "
          f"limite {atual.get('rate_limit_email_sent')} e-mails por hora")


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
