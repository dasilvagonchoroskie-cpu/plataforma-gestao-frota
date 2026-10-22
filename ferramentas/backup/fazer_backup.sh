#!/usr/bin/env bash
# Backup do banco do Supabase, criptografado com a senha BACKUP_SENHA.
#
# Uso (depois de "supabase link" ou com ALVO=--local):
#   BACKUP_SENHA=... ferramentas/backup/fazer_backup.sh pasta-de-saida
# Na esteira, BACKUP_SENHA vem da CHAVE_MESTRA (ferramentas/chaves/derivar.py
# segredo frota-backup-v1); ninguém precisa decorar outra senha.
#
# Gera backup-frota-AAAAMMDD-HHMMSS.tar.gz.gpg com:
#   1-papeis.sql (papéis), 2-estrutura.sql (tabelas, funções, regras),
#   3-dados.sql (dados do app, logins do Supabase Auth sem as sessões, e
#   agendamentos),
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
# O dump de dados do Supabase já traz os logins (schema auth) e os
# agendamentos (cron), sem as tabelas de controle de versão. Ficam de fora as
# sessões e os códigos temporários do login (tokens de sessão, links e códigos
# em andamento, registro de entradas): não devem ficar guardados num backup e,
# depois de uma restauração, cada pessoa só entra de novo com a senha.
TEMPORARIOS=(auth.sessions auth.refresh_tokens auth.mfa_amr_claims auth.flow_state
  auth.one_time_tokens auth.audit_log_entries)
supabase db dump $ALVO --data-only --use-copy "${TEMPORARIOS[@]/#/--exclude=}" -f "$D/3-dados.sql"

# Linhas de cada tabela no backup (para conferir na restauração).
python3 "$(dirname "$0")/contar_linhas.py" "$D/3-dados.sql" > "$D/contagens.txt"
for f in "$D"/*.sql; do
  echo "$(basename "$f"): $(wc -l < "$f") linhas, $(grep -c '^COPY ' "$f" || true) COPY, $(grep -c '^INSERT ' "$f" || true) INSERT"
done
(cd "$D" && sha256sum ./*.sql contagens.txt > conferencia.sha256)

tar -C "$TMP" -czf "$TMP/backup-$DATA.tar.gz" "backup-$DATA"
mkdir -p "$SAIDA"
ARQ="$SAIDA/backup-frota-$DATA.tar.gz.gpg"
# AES-256 com a senha esticada (S2K com SHA-512 e o máximo de rodadas).
gpg --batch --yes --quiet --pinentry-mode loopback --passphrase-fd 3 --symmetric --cipher-algo AES256 \
  --s2k-mode 3 --s2k-digest-algo SHA512 --s2k-count 65011712 \
  -o "$ARQ" "$TMP/backup-$DATA.tar.gz" 3<<<"$BACKUP_SENHA"

# Confere se o arquivo criptografado abre com a senha e bate com o original.
gpg --batch --quiet --pinentry-mode loopback --passphrase-fd 3 -d "$ARQ" 3<<<"$BACKUP_SENHA" > "$TMP/conferir.tar.gz"
cmp -s "$TMP/conferir.tar.gz" "$TMP/backup-$DATA.tar.gz" || { echo "ERRO: o backup criptografado não confere"; exit 1; }

echo "backup criptografado: $(basename "$ARQ") ($(du -h "$ARQ" | cut -f1))"
echo "tabelas com linhas: $(awk '$2 > 0' "$D/contagens.txt" | wc -l) de $(wc -l < "$D/contagens.txt")"
echo "linhas por tabela:"
[ -s "$D/contagens.txt" ] && cat "$D/contagens.txt" || echo "(nenhuma linha encontrada)"
