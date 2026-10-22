#!/usr/bin/env bash
# Backup do banco do Supabase, criptografado com a senha BACKUP_SENHA.
#
# Uso (depois de "supabase link" ou com ALVO=--local):
#   BACKUP_SENHA=... ferramentas/backup/fazer_backup.sh pasta-de-saida
#
# Gera backup-frota-AAAAMMDD-HHMMSS.tar.gz.gpg com:
#   1-papeis.sql (papéis), 2-estrutura.sql (tabelas, funções, regras),
#   3-dados.sql (dados do app), 4-logins.sql (logins do Supabase Auth),
#   contagens.txt (linhas por tabela, para conferir a restauração) e
#   conferencia.sha256. Nada fica aberto no disco: a pasta temporária é apagada.
# Nunca imprime senha nem dado pessoal: só nomes de tabela e quantidades.
set -euo pipefail
SAIDA="${1:?informe a pasta de saída}"
: "${BACKUP_SENHA:?falta a senha do backup (BACKUP_SENHA)}"
ALVO="${ALVO:---linked}"
DATA=$(date -u +%Y%m%d-%H%M%S)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
D="$TMP/backup-$DATA"
mkdir -p "$D"

supabase db dump $ALVO --role-only -f "$D/1-papeis.sql"
supabase db dump $ALVO -f "$D/2-estrutura.sql"
supabase db dump $ALVO --data-only --use-copy -f "$D/3-dados.sql"
supabase db dump $ALVO --data-only --use-copy --schema auth -x auth.schema_migrations -f "$D/4-logins.sql"

# Linhas de cada tabela no backup (para conferir na restauração).
python3 "$(dirname "$0")/contar_linhas.py" "$D/3-dados.sql" "$D/4-logins.sql" > "$D/contagens.txt"
for f in "$D"/*.sql; do
  echo "$(basename "$f"): $(wc -l < "$f") linhas, $(grep -c '^COPY ' "$f" || true) COPY, $(grep -c '^INSERT ' "$f" || true) INSERT"
done
(cd "$D" && sha256sum ./*.sql contagens.txt > conferencia.sha256)

tar -C "$TMP" -czf "$TMP/backup-$DATA.tar.gz" "backup-$DATA"
mkdir -p "$SAIDA"
ARQ="$SAIDA/backup-frota-$DATA.tar.gz.gpg"
gpg --batch --yes --quiet --pinentry-mode loopback --passphrase-fd 3 --symmetric --cipher-algo AES256 \
  -o "$ARQ" "$TMP/backup-$DATA.tar.gz" 3<<<"$BACKUP_SENHA"

# Confere se o arquivo criptografado abre com a senha e bate com o original.
gpg --batch --quiet --pinentry-mode loopback --passphrase-fd 3 -d "$ARQ" 3<<<"$BACKUP_SENHA" > "$TMP/conferir.tar.gz"
cmp -s "$TMP/conferir.tar.gz" "$TMP/backup-$DATA.tar.gz" || { echo "ERRO: o backup criptografado não confere"; exit 1; }

echo "backup criptografado: $(basename "$ARQ") ($(du -h "$ARQ" | cut -f1))"
echo "linhas por tabela:"
[ -s "$D/contagens.txt" ] && cat "$D/contagens.txt" || echo "(nenhuma linha encontrada)"
