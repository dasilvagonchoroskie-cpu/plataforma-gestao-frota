#!/usr/bin/env bash
# Roda os testes pgTAP do banco.
#
# Modo local (sem Docker): cria um banco novo num PostgreSQL comum, aplica a
# simulação do Supabase, o pgTAP (PGTAP_SQL) e as migrations, e roda os testes.
#   PGHOST=/tmp PGPORT=54329 PGUSER=postgres PGTAP_SQL=/caminho/pgtap.sql supabase/tests/local/rodar.sh
#
# Modo Supabase (esteira): com BANCO_URL, usa um banco já migrado
# (supabase start / db reset) e só roda os testes.
#   BANCO_URL=postgresql://postgres:postgres@127.0.0.1:54322/postgres supabase/tests/local/rodar.sh
set -euo pipefail
RAIZ="$(cd "$(dirname "$0")/../../.." && pwd)"

if [ -n "${BANCO_URL:-}" ]; then
  ALVO="$BANCO_URL"
else
  : "${PGTAP_SQL:?informe PGTAP_SQL (arquivo pgtap.sql) ou BANCO_URL}"
  BANCO="frota_teste_$$"
  psql -q -X -v ON_ERROR_STOP=1 -d postgres -c "create database $BANCO" >/dev/null
  trap 'psql -q -X -d postgres -c "drop database if exists $BANCO" >/dev/null' EXIT
  ALVO="$BANCO"
  psql -q -X -v ON_ERROR_STOP=1 -d "$ALVO" -f "$RAIZ/supabase/tests/local/supabase_simulado.sql" >/dev/null
  # pgTAP no schema extensions, como no Supabase (o public fica só com o app).
  psql -q -X -d postgres -c "alter database $BANCO set search_path = \"\$user\", public, extensions" >/dev/null
  PGOPTIONS='-c search_path=extensions' psql -q -X -d "$ALVO" -f "$PGTAP_SQL" >/dev/null 2>&1
  for m in "$RAIZ"/supabase/migrations/*.sql; do
    echo "migration: $(basename "$m")"
    psql -q -X -v ON_ERROR_STOP=1 -d "$ALVO" -f "$m" >/dev/null
  done
fi

FALHOU=0
TOTAL=0
cd "$RAIZ/supabase/tests"
for t in [0-9]*.sql; do
  SAIDA=$(psql -X -tA -v ON_ERROR_STOP=1 -d "$ALVO" -f "$t" 2>&1) || true
  PLANO=$(echo "$SAIDA" | grep -E '^1\.\.[0-9]+$' | head -1 | cut -d. -f3)
  OK=$(echo "$SAIDA" | grep -c -E '^ok [0-9]+' || true)
  RUINS=$(echo "$SAIDA" | grep -E '^not ok|ERROR|psql:.*(error|ERRO)' || true)
  if [ -z "$PLANO" ] || [ "$OK" != "$PLANO" ] || [ -n "$RUINS" ]; then
    echo "FALHOU: $t ($OK de ${PLANO:-?} ok)"
    echo "$SAIDA" | grep -E '^(not ok|#)|ERROR|psql:' | head -40
    FALHOU=1
  else
    echo "ok: $t ($OK testes)"
  fi
  TOTAL=$((TOTAL + OK))
done
echo "total de verificações que passaram: $TOTAL"
exit $FALHOU
