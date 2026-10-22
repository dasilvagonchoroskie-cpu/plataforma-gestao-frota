#!/usr/bin/env python3
"""Gera os textos legais dos apps e as páginas públicas a partir de docs/legal.

Fonte única: docs/legal/termos-de-uso.md e docs/legal/politica-de-privacidade.md,
com os dados de quem oferece a Plataforma em docs/legal/operador.json (os textos
usam {{OPERADOR}}, {{OPERADOR_CURTO}}, {{EMAIL}} e {{CIDADE}}). Para trocar de
pessoa física para empresa com CNPJ, mude só o operador.json e a versão.
Saídas:
  packages/visual/lib/src/textos_legais.dart  (textos dentro dos dois apps)
  apps/gestor/web/termos.html e privacidade.html  (publicadas com o painel web)

A versão (VERSAO) tem de ser a mesma de public.versao_termos() na migration;
o script confere e para com erro se estiver diferente.
Uso: python3 ferramentas/legal/gerar.py
"""
import html
import json
import pathlib
import re
import sys

VERSAO = "2026-10-22"
RAIZ = pathlib.Path(__file__).resolve().parents[2]
FONTES = {
    "termosDeUso": ("termos-de-uso.md", "termos.html", "Termos de Uso"),
    "politicaDePrivacidade": ("politica-de-privacidade.md", "privacidade.html", "Política de Privacidade"),
}


def dados_operador() -> dict:
    o = json.loads((RAIZ / "docs" / "legal" / "operador.json").read_text(encoding="utf-8"))
    for campo in ("tipo", "nome", "marca", "cidade", "email"):
        if not str(o.get(campo, "")).strip():
            sys.exit(f"operador.json: falta o campo {campo}")
    if o["tipo"] == "pessoa_fisica":
        completo = f"{o['nome']}, pessoa física, responsável pela marca {o['marca']}, com atendimento em {o['cidade']}"
        curto = f"{o['nome']}, titular da marca {o['marca']}"
    elif o["tipo"] == "pessoa_juridica":
        if not str(o.get("documento", "")).strip():
            sys.exit("operador.json: pessoa jurídica precisa do CNPJ em documento")
        completo = f"{o['nome']}, inscrita no CNPJ {o['documento']}, com sede em {o['cidade']}"
        curto = o["nome"]
    else:
        sys.exit("operador.json: tipo deve ser pessoa_fisica ou pessoa_juridica")
    return {"{{OPERADOR}}": completo, "{{OPERADOR_CURTO}}": curto,
            "{{EMAIL}}": o["email"], "{{CIDADE}}": o["cidade"]}


def preencher(texto: str, dados: dict) -> str:
    for chave, valor in dados.items():
        texto = texto.replace(chave, valor)
    if "{{" in texto:
        sys.exit("texto legal com marcador sem valor: " + texto[texto.index("{{"):][:30])
    return texto


def conferir_versao():
    achou = False
    for m in sorted((RAIZ / "supabase" / "migrations").glob("*.sql")):
        t = m.read_text(encoding="utf-8")
        for v in re.findall(r"function public\.versao_termos\(\).*?select '(\d{4}-\d{2}-\d{2})'::text", t, re.S):
            achou = v
    if achou != VERSAO:
        sys.exit(f"versão diferente: gerar.py tem {VERSAO}, a migration tem {achou}")


def para_html(md: str, titulo: str) -> str:
    partes, lista = [], False
    for linha in md.splitlines():
        if linha.startswith("- "):
            if not lista:
                partes.append("<ul>")
                lista = True
            partes.append(f"<li>{html.escape(linha[2:])}</li>")
            continue
        if lista:
            partes.append("</ul>")
            lista = False
        if linha.startswith("# "):
            partes.append(f"<h1>{html.escape(linha[2:])}</h1>")
        elif linha.startswith("## "):
            partes.append(f"<h2>{html.escape(linha[3:])}</h2>")
        elif linha.strip():
            partes.append(f"<p>{html.escape(linha)}</p>")
    if lista:
        partes.append("</ul>")
    corpo = "\n".join(partes)
    return f"""<!doctype html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{titulo} | Plataforma de Gestão de Frota</title>
<style>
:root {{ --fundo: #f6f7f4; --texto: #1d2420; --fraco: #5b665f; --verde: #0b6b3a; }}
@media (prefers-color-scheme: dark) {{ :root {{ --fundo: #111614; --texto: #e7ece8; --fraco: #a4b0a8; --verde: #5fc48d; }} }}
body {{ margin: 0; background: var(--fundo); color: var(--texto); font: 17px/1.55 system-ui, -apple-system, "Segoe UI", Roboto, sans-serif; }}
main {{ max-width: 760px; margin: 0 auto; padding: 24px 16px 64px; }}
h1 {{ color: var(--verde); font-size: 30px; margin: 8px 0 4px; }}
h2 {{ font-size: 20px; margin: 28px 0 6px; }}
p, li {{ color: var(--texto); }}
main > p:first-of-type {{ color: var(--fraco); }}
ul {{ padding-left: 22px; }}
</style>
</head>
<body><main>
{corpo}
</main></body>
</html>
"""


def main():
    conferir_versao()
    operador = dados_operador()
    dart = [
        "// Gerado por ferramentas/legal/gerar.py a partir de docs/legal. Não editar à mão.",
        "",
        "/// Versão dos Termos de Uso e da Política de Privacidade (igual a public.versao_termos()).",
        f"const versaoTermos = '{VERSAO}';",
        "",
    ]
    for nome, (md, pagina, titulo) in FONTES.items():
        texto = preencher((RAIZ / "docs" / "legal" / md).read_text(encoding="utf-8").strip(), operador)
        if "'''" in texto or f"{VERSAO[8:10]} de outubro de {VERSAO[:4]}" not in texto:
            sys.exit(f"{md}: texto com ''' ou sem a data da versão {VERSAO}")
        dart.append(f"/// {titulo} (docs/legal/{md}).")
        dart.append(f"const {nome} = r'''{texto}''';")
        dart.append("")
        (RAIZ / "apps" / "gestor" / "web" / pagina).write_text(para_html(texto, titulo), encoding="utf-8")
    (RAIZ / "packages" / "visual" / "lib" / "src" / "textos_legais.dart").write_text("\n".join(dart), encoding="utf-8")
    print("textos legais gerados, versão", VERSAO)


if __name__ == "__main__":
    main()
