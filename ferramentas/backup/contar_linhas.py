"""Conta as linhas de cada tabela num arquivo de dados do pg_dump (COPY ou INSERT).

Uso: python3 contar_linhas.py 3-dados.sql 4-logins.sql
Imprime "tabela quantidade" por linha. Só nomes de tabela e números.
"""
import collections
import re
import sys

contagem = collections.Counter()
for arquivo in sys.argv[1:]:
    tabela = None
    with open(arquivo, encoding="utf-8", errors="replace") as f:
        for linha in f:
            if tabela is not None:
                if linha.rstrip("\n") == "\\.":
                    tabela = None
                else:
                    contagem[tabela] += 1
                continue
            m = re.match(r"COPY\s+(\S+)", linha)
            if m:
                tabela = m.group(1)
                contagem.setdefault(tabela, 0)
                continue
            m = re.match(r"INSERT INTO\s+(\S+)", linha)
            if m:
                contagem[m.group(1)] += 1
for nome in sorted(contagem):
    print(nome.replace('"', ""), contagem[nome])
