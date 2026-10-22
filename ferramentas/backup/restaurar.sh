#!/usr/bin/env bash
# Restaura um backup criptografado num banco Supabase VAZIO e confere as linhas.
#
# Uso:
#   BACKUP_SENHA=... ferramentas/backup/restaurar.sh backup-frota-....tar.gz.gpg URL_DO_BANCO
#
# URL_DO_BANCO é a ligação ("connection string") de um projeto Supabase NOVO
# (ou do Supabase local de teste). Nunca use o banco de produção que está
# funcionando: a restauração cria as tabelas e falha se elas já existirem.
#
# Passos (o mesmo roteiro da documentação do Supabase):
#   1. abre o arquivo com a senha e confere o resumo (sha256) de cada parte;
#   2. aplica os papéis (o que der) e depois estrutura e dados numa transação
#      só (ou tudo ou nada), com os gatilhos desligados enquanto os dados entram;
#   3. conta as linhas de cada tabela e compara com as do backup.
# Em caso de erro mostra só o código do erro e a linha do arquivo, nunca o
# conteúdo (o conteúdo pode ter dados pessoais).
set -euo pipefail
ARQ="${1:?informe o arquivo .gpg do backup}"
DESTINO="${2:?informe a URL do banco vazio}"
: "${BACKUP_SENHA:?falta a senha do backup (BACKUP_SENHA)}"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

gpg --batch --quiet --pinentry-mode loopback --passphrase-fd 3 -d "$ARQ" 3<<<"$BACKUP_SENHA" | tar -C "$TMP" -xz
D=$(ls -d "$TMP"/backup-*)
(cd "$D" && sha256sum --quiet -c conferencia.sha256) || { echo "ERRO: o backup está corrompido (resumo não confere)"; exit 1; }
echo "backup aberto e conferido: $(basename "$D")"

# Papéis: o banco novo do Supabase já cria os dele, e alguns papéis da nuvem
# (ou permissões entre eles) podem não existir ali. Erro aqui não é dado
# perdido: aplica o que der e só conta os avisos.
psql "$DESTINO" -X -q -v VERBOSITY=sqlstate -f "$D/1-papeis.sql" > /dev/null 2> "$TMP/papeis.txt" || true
echo "papéis aplicados ($(grep -c 'ERROR' "$TMP/papeis.txt" || true) avisos de papéis que já existem ou não existem aqui)"

# Estrutura e dados: numa transação só (ou entra tudo, ou nada).
if ! psql "$DESTINO" -X -q --single-transaction -v ON_ERROR_STOP=1 -v VERBOSITY=sqlstate \
     -f "$D/2-estrutura.sql" -f "$D/3-dados.sql" > "$TMP/saida.txt" 2> "$TMP/erros.txt"; then
  echo "ERRO na restauração (nada foi gravado):"
  grep -E "ERROR" "$TMP/erros.txt" | sed -E 's#^psql:[^:]*/([^/:]+):#\1:#' | head -5
  exit 1
fi
echo "restauração aplicada (estrutura e dados)"

# Confere as linhas de cada tabela.
TOTAL=0; DIFERENTES=0
while read -r TABELA ESPERADO; do
  ESQUEMA="${TABELA%%.*}"; NOME="${TABELA#*.}"
  VEIO=$(psql "$DESTINO" -X -tA -v VERBOSITY=sqlstate -c "select count(*) from \"$ESQUEMA\".\"$NOME\"" 2>/dev/null || echo "?")
  TOTAL=$((TOTAL + 1))
  if [ "$VEIO" != "$ESPERADO" ]; then
    DIFERENTES=$((DIFERENTES + 1))
    echo "diferente: $TABELA backup=$ESPERADO restaurado=$VEIO"
  fi
done < "$D/contagens.txt"
echo "tabelas conferidas: $TOTAL, diferenças: $DIFERENTES"
[ "$DIFERENTES" -eq 0 ]
