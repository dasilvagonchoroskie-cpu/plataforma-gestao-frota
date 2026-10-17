#!/usr/bin/env bash
# Testes de ponta a ponta no Supabase local (esteira): cadastro, entrada na
# empresa, login por CPF (Edge Function), bloqueio e redefinição de acesso.
# Usa só usuários de teste criados aqui. Nunca rodar em produção.
set -uo pipefail
cd "$(dirname "$0")/../../.."
eval "$(supabase status -o env | grep -E '^[A-Z_]+=' | sed 's/^/export /')"
A="${API_URL}"
K="${PUBLISHABLE_KEY:-$ANON_KEY}"
S="${SECRET_KEY:-$SERVICE_ROLE_KEY}"
DB="${DB_URL}"
FALHAS=0
N=0

ok() { N=$((N+1)); echo "ok $N - $1"; }
falha() { N=$((N+1)); FALHAS=$((FALHAS+1)); echo "not ok $N - $1"; [ -n "${2:-}" ] && echo "#   $2"; }
igual() { if [ "$1" == "$2" ]; then ok "$3"; else falha "$3" "esperado [$2], veio [$1]"; fi; }

criar_usuario() {
  curl -s -X POST "$A/auth/v1/admin/users" -H "apikey: $S" -H "Authorization: Bearer $S" \
    -H "Content-Type: application/json" -d "{\"email\":\"$1\",\"password\":\"$2\",\"email_confirm\":true}" | jq -r .id
}
token() {
  curl -s -X POST "$A/auth/v1/token?grant_type=password" -H "apikey: $K" -H "Content-Type: application/json" \
    -d "{\"email\":\"$1\",\"password\":\"$2\"}" | jq -r .access_token
}
rpc() { # token funcao json
  curl -s -X POST "$A/rest/v1/rpc/$2" -H "apikey: $K" -H "Authorization: Bearer $1" \
    -H "Content-Type: application/json" -d "$3"
}
funcao() { # nome token json -> imprime "status corpo"
  local cab=()
  [ -n "$2" ] && cab=(-H "Authorization: Bearer $2")
  curl -s -o /tmp/resp.json -w "%{http_code}" -X POST "$A/functions/v1/$1" -H "apikey: $K" "${cab[@]}" \
    -H "Content-Type: application/json" -d "$3"
  echo -n " "; cat /tmp/resp.json
}

CODIGO=$(psql "$DB" -tA -c "select public.criar_empresa('Transportes Teste', 'dono@teste.com') ->> 'codigo_entrada'")
[ ${#CODIGO} -eq 6 ] && ok "empresa criada pela função da plataforma" || falha "criar_empresa" "$CODIGO"

criar_usuario dono@teste.com donosenha >/dev/null
TD=$(token dono@teste.com donosenha)
igual "$(rpc "$TD" completar_cadastro '{"p_nome":"Dono Teste"}' | jq -r .perfil.papel)" "dono" "dono entra pelo e-mail autorizado"

criar_usuario moto@teste.com senha123 >/dev/null
TM=$(token moto@teste.com senha123)
rpc "$TM" completar_cadastro '{"p_nome":"Motorista Teste","p_cpf":"529.982.247-25"}' >/dev/null
igual "$(rpc "$TM" pedir_entrada "{\"p_codigo\":\"$CODIGO\"}" | jq -r .status)" "pendente" "motorista pede entrada com o código"
PEDIDO=$(curl -s "$A/rest/v1/pedidos_entrada?select=id&status=eq.pendente" -H "apikey: $K" -H "Authorization: Bearer $TD" | jq -r '.[0].id')
MOT=$(rpc "$TD" decidir_entrada "{\"p_pedido_id\":\"$PEDIDO\",\"p_aprovar\":true}" | jq -r .motorista_id)
[ -n "$MOT" ] && [ "$MOT" != "null" ] && ok "dono aprova o motorista" || falha "decidir_entrada" "$MOT"

# Login por CPF
R=$(funcao entrar_com_cpf "" '{"cpf":"529.982.247-25","senha":"senha123","aparelho":"teste-1"}')
igual "${R%% *}" "200" "login com CPF e senha certos"
TOK=$(echo "${R#* }" | jq -r .access_token)
igual "$(rpc "$TOK" situacao_acesso '{}' | jq -r .empresa.nome)" "Transportes Teste" "a sessão do login por CPF funciona no banco"
R=$(funcao entrar_com_cpf "" '{"cpf":"52998224725","senha":"errada","aparelho":"teste-1"}')
igual "${R%% *} $(echo "${R#* }" | jq -r .mensagem)" "401 CPF ou senha incorretos." "senha errada: mensagem padrão"
R=$(funcao entrar_com_cpf "" '{"cpf":"11144477735","senha":"qualquer","aparelho":"teste-2"}')
igual "${R%% *} $(echo "${R#* }" | jq -r .mensagem)" "401 CPF ou senha incorretos." "CPF sem cadastro: a mesma mensagem"

# Redefinir acesso pelo gestor
R=$(funcao redefinir_acesso "$TM" "{\"motorista_id\":\"$MOT\"}")
igual "${R%% *}" "403" "motorista não redefine acesso"
R=$(funcao redefinir_acesso "" "{\"motorista_id\":\"$MOT\"}")
igual "${R%% *}" "401" "sem login não redefine acesso"
R=$(funcao redefinir_acesso "$TD" "{\"motorista_id\":\"$MOT\"}")
igual "${R%% *}" "200" "dono redefine o acesso do motorista"
NOVA=$(echo "${R#* }" | jq -r .senha_provisoria)
[ ${#NOVA} -eq 8 ] && ok "senha provisória de 8 caracteres" || falha "senha provisória" "$NOVA"
R=$(funcao entrar_com_cpf "" "{\"cpf\":\"52998224725\",\"senha\":\"$NOVA\",\"aparelho\":\"teste-3\"}")
igual "${R%% *} $(echo "${R#* }" | jq -r .trocar_senha)" "200 true" "entra com a senha provisória e o app pede para trocar"
R=$(funcao entrar_com_cpf "" '{"cpf":"52998224725","senha":"senha123","aparelho":"teste-3"}')
igual "${R%% *}" "401" "a senha antiga deixou de valer"

# Bloqueio depois de 5 erros seguidos
for i in 1 2 3 4; do funcao entrar_com_cpf "" '{"cpf":"52998224725","senha":"errada","aparelho":"teste-4"}' >/dev/null; done
R=$(funcao entrar_com_cpf "" "{\"cpf\":\"52998224725\",\"senha\":\"$NOVA\",\"aparelho\":\"teste-4\"}")
igual "${R%% *}" "429" "depois de 5 erros seguidos o CPF fica bloqueado, mesmo com a senha certa"

echo "1..$N"
echo "verificações: $N, falhas: $FALHAS"
[ "$FALHAS" -eq 0 ]
