#!/usr/bin/env python3
"""Regra do dono: migration que apaga dados só entra com aprovação escrita.

Procura, nas migrations a partir da parte 4 (as anteriores já estavam na nuvem
quando a regra nasceu), comandos que apagam dados: DELETE FROM, TRUNCATE,
DROP TABLE/SCHEMA/COLUMN/DATABASE (fora de comentários). Toda migration
assim precisa de uma linha no começo:

    -- aprovado-por: Evandro em DD/MM/AAAA (o que foi aprovado)

Sem a linha, a esteira e o fluxo do banco da nuvem param antes de aplicar.
Uso: python3 ferramentas/seguranca/conferir_aprovacao.py supabase/migrations
"""
import pathlib
import re
import sys

CORTE = "20261017213600"
# TRUNCATE só como comando (começo de linha); "before truncate on" de gatilho não conta.
APAGA = re.compile(r"\bdelete\s+from\b|^\s*truncate\b|\bdrop\s+(table|schema|column|database)\b", re.I | re.M)
APROVADO = re.compile(r"^--\s*aprovado-por:\s*\S+", re.I | re.M)


def sem_comentarios(sql: str) -> str:
    sql = re.sub(r"/\*.*?\*/", " ", sql, flags=re.S)
    return re.sub(r"--[^\n]*", " ", sql)


def main(pasta: str) -> int:
    falhas, conferidas = [], 0
    for arq in sorted(pathlib.Path(pasta).glob("*.sql")):
        if arq.name.split("_")[0] < CORTE:
            continue
        conferidas += 1
        texto = arq.read_text(encoding="utf-8")
        if APAGA.search(sem_comentarios(texto)) and not APROVADO.search(texto):
            falhas.append(arq.name)
    print(f"migrations conferidas: {conferidas}; sem aprovação para apagar dados: {len(falhas)}")
    for f in falhas:
        print(f"::error::{f} apaga dados e não tem a linha '-- aprovado-por: ...' (regra do dono)")
    return 1 if falhas else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "supabase/migrations"))
