#!/usr/bin/env bash
# Roda um comando (o build do APK) com a chave de assinatura oficial, derivada
# da CHAVE_MESTRA. A chave existe só numa pasta temporária enquanto o comando
# roda e é apagada no fim; a senha é mascarada nos registros do GitHub.
# Sem CHAVE_MESTRA, o APK sai com a chave de depuração e não é publicado.
# Escreve em GITHUB_OUTPUT: assinatura=oficial|depuracao e impressao=<SHA-256>.
# Uso: ferramentas/chaves/com_assinatura.sh flutter build apk --release
set -euo pipefail
AQUI=$(cd "$(dirname "$0")" && pwd)
SAIDA="${GITHUB_OUTPUT:-/dev/null}"
if [ -z "${CHAVE_MESTRA:-}" ]; then
  echo "::warning::Sem o segredo CHAVE_MESTRA: o APK sai com a chave de depuração e não é publicado."
  echo "assinatura=depuracao" >> "$SAIDA"
  exec "$@"
fi
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
SENHA=$(python3 "$AQUI/derivar.py" segredo frota-assinatura-v1)
[ -n "${GITHUB_ACTIONS:-}" ] && echo "::add-mask::$SENHA"
IMPRESSAO=$(python3 "$AQUI/derivar.py" chave-android "$TMP")
FROTA_CHAVE_SENHA="$SENHA" openssl pkcs12 -export -inkey "$TMP/chave.pem" -in "$TMP/certificado.pem" \
  -name frota -passout env:FROTA_CHAVE_SENHA -out "$TMP/frota.p12"
rm -f "$TMP/chave.pem"
echo "chave de assinatura oficial; impressão digital (SHA-256): $IMPRESSAO"
{ echo "assinatura=oficial"; echo "impressao=$IMPRESSAO"; } >> "$SAIDA"
env -u CHAVE_MESTRA FROTA_CHAVE_ARQUIVO="$TMP/frota.p12" FROTA_CHAVE_SENHA="$SENHA" "$@"
