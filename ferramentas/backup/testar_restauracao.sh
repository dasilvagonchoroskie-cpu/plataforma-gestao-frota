#!/usr/bin/env bash
# Prova que o backup volta: sobe um Supabase local VAZIO (sem as migrations),
# restaura o backup nele e confere as linhas de cada tabela.
#
# Uso: BACKUP_SENHA=... ferramentas/backup/testar_restauracao.sh ARQUIVO.gpg [PASTA_.temp_DO_PROJETO_LIGADO]
# Com a pasta .temp de um projeto ligado (supabase link), o Supabase local usa
# as mesmas versões do banco, do login e do armazenamento da nuvem.
set -euo pipefail
ARQ=$(realpath "${1:?informe o arquivo .gpg}")
VERSOES="${2:-}"
RAIZ=$(cd "$(dirname "$0")/../.." && pwd)
: "${BACKUP_SENHA:?falta a senha do backup (BACKUP_SENHA)}"
DIR=$(mktemp -d)
trap '(cd "$DIR" && supabase stop --no-backup >/dev/null 2>&1) || true; rm -rf "$DIR"' EXIT
mkdir -p "$DIR/supabase"
ARMAZENAMENTO=false
if [ -n "$VERSOES" ] && [ -d "$VERSOES" ]; then
  mkdir -p "$DIR/supabase/.temp"
  for f in "$VERSOES"/*-version; do [ -f "$f" ] && cp "$f" "$DIR/supabase/.temp/"; done
  ARMAZENAMENTO=true
fi
cat > "$DIR/supabase/config.toml" <<CONFIG
project_id = "frota-restauracao"
[api]
enabled = true
port = 54321
schemas = ["public"]
extra_search_path = ["public", "extensions"]
[db]
port = 54322
shadow_port = 54320
major_version = 17
[db.seed]
enabled = false
[studio]
enabled = false
[inbucket]
enabled = false
[storage]
enabled = $ARMAZENAMENTO
[realtime]
enabled = false
[analytics]
enabled = false
[edge_runtime]
enabled = false
CONFIG
cd "$DIR"
echo "subindo um Supabase local vazio para a restauração..."
if ! supabase start -x studio,imgproxy,logflare,vector,edge-runtime,realtime > inicio.log 2>&1; then
  tail -20 inicio.log; exit 1
fi
URL=$(supabase status -o env | grep '^DB_URL=' | cut -d= -f2- | tr -d '"')
bash "$RAIZ/ferramentas/backup/restaurar.sh" "$ARQ" "$URL"
