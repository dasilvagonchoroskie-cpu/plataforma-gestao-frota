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

# E-mails do Supabase local (Mailpit ou Inbucket, conforme a versão).
CAIXA="${MAILPIT_URL:-${INBUCKET_URL:-http://127.0.0.1:54324}}"
limpar_emails() {
  curl -s -X DELETE "$CAIXA/api/v1/messages" >/dev/null 2>&1 || true
  for c in "$@"; do curl -s -X DELETE "$CAIXA/api/v1/mailbox/${c%@*}" >/dev/null 2>&1 || true; done
}
token_do_email() { # destinatário -> token_hash do link do e-mail mais novo (espera até 20 s)
  local para=$1 corpo id th i
  for i in $(seq 1 20); do
    corpo=""
    id=$(curl -s "$CAIXA/api/v1/search?query=to:$para" | jq -r '.messages[0].ID // empty' 2>/dev/null)
    [ -n "$id" ] && corpo=$(curl -s "$CAIXA/api/v1/message/$id" | jq -r '(.HTML // "") + (.Text // "")' 2>/dev/null)
    if [ -z "$corpo" ]; then
      id=$(curl -s "$CAIXA/api/v1/mailbox/${para%@*}" | jq -r 'last.id // empty' 2>/dev/null)
      [ -n "$id" ] && corpo=$(curl -s "$CAIXA/api/v1/mailbox/${para%@*}/$id" | jq -r '(.body.html // "") + (.body.text // "")' 2>/dev/null)
    fi
    th=$(echo "$corpo" | grep -o 'token_hash=[A-Za-z0-9_-]*' | head -1 | cut -d= -f2)
    [ -n "$th" ] && { echo "$th"; return; }
    sleep 1
  done
}
verificar_link() { # tipo token_hash -> access_token (como a página do painel faz)
  curl -s -X POST "$A/auth/v1/verify" -H "apikey: $K" -H "Content-Type: application/json" \
    -d "{\"type\":\"$1\",\"token_hash\":\"$2\"}" | jq -r '.access_token // empty'
}

CODIGO=$(psql "$DB" -tA -c "select public.criar_empresa('Transportes Teste', 'dono@teste.com') ->> 'codigo_entrada'")
[ ${#CODIGO} -eq 6 ] && ok "empresa criada pela função da plataforma" || falha "criar_empresa" "$CODIGO"

criar_usuario dono@teste.com donosenha1 >/dev/null
TD=$(token dono@teste.com donosenha1)
igual "$(rpc "$TD" completar_cadastro '{"p_nome":"Dono Teste"}' | jq -r .perfil.papel)" "dono" "dono entra pelo e-mail autorizado"

criar_usuario moto@teste.com senha1234 >/dev/null
TM=$(token moto@teste.com senha1234)
rpc "$TM" completar_cadastro '{"p_nome":"Motorista Teste","p_cpf":"529.982.247-25"}' >/dev/null
igual "$(rpc "$TM" pedir_entrada "{\"p_codigo\":\"$CODIGO\"}" | jq -r .status)" "pendente" "motorista pede entrada com o código"
PEDIDO=$(curl -s "$A/rest/v1/pedidos_entrada?select=id&status=eq.pendente" -H "apikey: $K" -H "Authorization: Bearer $TD" | jq -r '.[0].id')
MOT=$(rpc "$TD" decidir_entrada "{\"p_pedido_id\":\"$PEDIDO\",\"p_aprovar\":true}" | jq -r .motorista_id)
[ -n "$MOT" ] && [ "$MOT" != "null" ] && ok "dono aprova o motorista" || falha "decidir_entrada" "$MOT"

# Login por CPF
R=$(funcao entrar_com_cpf "" '{"cpf":"529.982.247-25","senha":"senha1234","aparelho":"teste-1"}')
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
[[ ${#NOVA} -eq 10 && "$NOVA" =~ [A-Z] && "$NOVA" =~ [0-9] ]] && ok "senha provisória de 10 caracteres, com letras e números" || falha "senha provisória" "$NOVA"
R=$(funcao entrar_com_cpf "" "{\"cpf\":\"52998224725\",\"senha\":\"$NOVA\",\"aparelho\":\"teste-3\"}")
igual "${R%% *} $(echo "${R#* }" | jq -r .trocar_senha)" "200 true" "entra com a senha provisória e o app pede para trocar"
R=$(funcao entrar_com_cpf "" '{"cpf":"52998224725","senha":"senha1234","aparelho":"teste-3"}')
igual "${R%% *}" "401" "a senha antiga deixou de valer"

# Bloqueio depois de 5 erros seguidos
for i in 1 2 3 4; do funcao entrar_com_cpf "" '{"cpf":"52998224725","senha":"errada","aparelho":"teste-4"}' >/dev/null; done
R=$(funcao entrar_com_cpf "" "{\"cpf\":\"52998224725\",\"senha\":\"$NOVA\",\"aparelho\":\"teste-4\"}")
igual "${R%% *}" "429" "depois de 5 erros seguidos o CPF fica bloqueado, mesmo com a senha certa"

# Cadastro do motorista sem e-mail (nome, CPF e senha)
R=$(funcao cadastrar_motorista "" '{"nome":"Motorista Sem Email","cpf":"111.444.777-35","senha":"senha4567","aparelho":"cad-1"}')
igual "${R%% *}" "200" "motorista cria a conta só com nome, CPF e senha"
R=$(funcao entrar_com_cpf "" '{"cpf":"11144477735","senha":"senha4567","aparelho":"cad-1"}')
igual "${R%% *}" "200" "e já entra com CPF e senha"
TN=$(echo "${R#* }" | jq -r .access_token)
igual "$(rpc "$TN" pedir_entrada "{\"p_codigo\":\"$CODIGO\"}" | jq -r .status)" "pendente" "e pede entrada na empresa com o código"
R=$(funcao cadastrar_motorista "" '{"nome":"Fulano","cpf":"123.456.789-00","senha":"senha7890","aparelho":"cad-2"}')
igual "${R%% *} $(echo "${R#* }" | jq -r .codigo)" "400 cpf_invalido" "CPF com dígito errado é recusado"
R=$(funcao cadastrar_motorista "" '{"nome":"Fulano","cpf":"39053344705","senha":"123","aparelho":"cad-2"}')
igual "${R%% *} $(echo "${R#* }" | jq -r .codigo)" "400 senha_fraca" "senha curta é recusada"
R=$(funcao cadastrar_motorista "" '{"nome":"Fulano","cpf":"39053344705","senha":"senhasemnumero","aparelho":"cad-3"}')
igual "${R%% *} $(echo "${R#* }" | jq -r .codigo)" "400 senha_fraca" "senha sem número é recusada"
for i in 1 2 3 4 5; do
  R=$(funcao cadastrar_motorista "" '{"nome":"Outro","cpf":"11144477735","senha":"senha7890","aparelho":"cad-4"}')
done
igual "${R%% *} $(echo "${R#* }" | jq -r .codigo)" "409 cpf_em_uso" "CPF que já tem conta não cria outra"
R=$(funcao cadastrar_motorista "" '{"nome":"Outro","cpf":"39053344705","senha":"senha7890","aparelho":"cad-4"}')
igual "${R%% *}" "429" "mais de 5 cadastros por hora no mesmo aparelho são bloqueados"

# Acesso do gestor criado pelo dono (senha provisória, sem e-mail)
R=$(funcao criar_acesso_gestor "$TN" '{"email":"gestor.novo@teste.com","nome":"Gestor Novo"}')
igual "${R%% *}" "403" "motorista não cria acesso de gestor"
R=$(funcao criar_acesso_gestor "$TD" '{"email":"Gestor.Novo@teste.com","nome":"Gestor Novo"}')
igual "${R%% *}" "200" "dono cria o acesso do gestor"
SG=$(echo "${R#* }" | jq -r .senha_provisoria)
TG=$(token gestor.novo@teste.com "$SG")
igual "$(rpc "$TG" situacao_acesso '{}' | jq -r '.perfil.papel + ":" + .empresa.nome')" "gestor:Transportes Teste" "gestor entra com a senha provisória e já está na empresa"
igual "$(curl -s "$A/auth/v1/user" -H "apikey: $K" -H "Authorization: Bearer $TG" | jq -r .user_metadata.trocar_senha)" "true" "o app pede para o gestor trocar a senha"
R=$(funcao criar_acesso_gestor "$TG" '{"email":"outro.gestor@teste.com","nome":"Outro"}')
igual "${R%% *}" "403" "gestor não cria outro gestor"
R=$(funcao criar_acesso_gestor "$TD" '{"email":"gestor.novo@teste.com"}')
igual "${R%% *}" "200" "dono gera senha nova para o gestor que esqueceu"
SG2=$(echo "${R#* }" | jq -r .senha_provisoria)
igual "$(token gestor.novo@teste.com "$SG")" "null" "a senha provisória anterior deixa de valer"
[ "$(token gestor.novo@teste.com "$SG2")" != "null" ] && ok "a senha nova funciona" || falha "senha nova do gestor"
R=$(funcao criar_acesso_gestor "$TD" '{"email":"moto@teste.com","nome":"Motorista"}')
igual "${R%% *}" "409" "e-mail de motorista não vira gestor"

# Login do dono criado pela plataforma (função criar_login_dono)
psql "$DB" -tA -c "select public.criar_empresa('Transportes W', 'dono.w@teste.com')" >/dev/null
psql "$DB" -tA -c "select public.criar_login_dono('dono.w@teste.com', 'Dono W', 'provisoria9')" >/dev/null
TW=$(token dono.w@teste.com provisoria9)
igual "$(rpc "$TW" situacao_acesso '{}' | jq -r '.perfil.papel + ":" + .empresa.nome')" "dono:Transportes W" "login do dono criado pela plataforma entra no Supabase"
curl -s -X PUT "$A/auth/v1/user" -H "apikey: $K" -H "Authorization: Bearer $TW" -H "Content-Type: application/json" \
  -d '{"password":"novasenha1","data":{"trocar_senha":false}}' >/dev/null
[ "$(token dono.w@teste.com novasenha1)" != "null" ] && ok "o dono troca a senha provisória pela dele" || falha "troca de senha do dono"

# Código individual do motorista (gerado pelo gestor) e termos no cadastro
CONV=$(rpc "$TD" gerar_convite_motorista '{"p_nome":"Motorista Convite","p_cpf":"246.813.579-28"}' | jq -r .codigo)
[ ${#CONV} -eq 6 ] && ok "o painel gera o código individual do motorista" || falha "gerar_convite_motorista" "$CONV"
VT=$(psql "$DB" -tA -c "select public.versao_termos()")
R=$(funcao cadastrar_motorista "" "{\"nome\":\"Motorista Convite\",\"cpf\":\"24681357928\",\"senha\":\"senha3210\",\"aparelho\":\"conv-1\",\"termos\":\"$VT\"}")
igual "${R%% *}" "200" "motorista cria a conta aceitando os termos"
R=$(funcao entrar_com_cpf "" '{"cpf":"24681357928","senha":"senha3210","aparelho":"conv-1"}')
TC=$(echo "${R#* }" | jq -r .access_token)
igual "$(rpc "$TC" situacao_acesso '{}' | jq -r .termos.aceito)" "true" "o aceite dos termos do cadastro fica guardado"
igual "$(rpc "$TC" pedir_entrada "{\"p_codigo\":\"$CONV\"}" | jq -r .status)" "aprovado" "com o código individual entra na empresa na hora"

# Recuperar o acesso com o código de recuperação
REC=$(rpc "$TC" gerar_codigo_recuperacao '{}' | jq -r .)
[ ${#REC} -eq 14 ] && ok "o motorista gera o código de recuperação" || falha "gerar_codigo_recuperacao" "$REC"
R=$(funcao recuperar_acesso "" "{\"identificador\":\"246.813.579-28\",\"codigo\":\"AAAA-BBBB-CCCC\",\"senha_nova\":\"nova12345\",\"aparelho\":\"rec-1\"}")
igual "${R%% *}" "401" "código de recuperação errado é recusado"
R=$(funcao recuperar_acesso "" "{\"identificador\":\"246.813.579-28\",\"codigo\":\"$REC\",\"senha_nova\":\"nova12345\",\"aparelho\":\"rec-1\"}")
igual "${R%% *}" "200" "CPF e código certos: senha nova criada"
REC2=$(echo "${R#* }" | jq -r .codigo_novo)
[ ${#REC2} -eq 14 ] && [ "$REC2" != "$REC" ] && ok "recebe um código de recuperação novo" || falha "codigo_novo" "$REC2"
R=$(funcao entrar_com_cpf "" '{"cpf":"24681357928","senha":"nova12345","aparelho":"rec-1"}')
igual "${R%% *}" "200" "entra com a senha nova"
R=$(funcao recuperar_acesso "" "{\"identificador\":\"24681357928\",\"codigo\":\"$REC\",\"senha_nova\":\"outra1234\",\"aparelho\":\"rec-2\"}")
igual "${R%% *}" "401" "o código antigo deixa de valer"
TGR=$(token gestor.novo@teste.com "$SG2")
RECG=$(rpc "$TGR" gerar_codigo_recuperacao '{}' | jq -r .)
R=$(funcao recuperar_acesso "" "{\"identificador\":\"Gestor.Novo@teste.com\",\"codigo\":\"$RECG\",\"senha_nova\":\"gestor7890\",\"aparelho\":\"rec-3\"}")
igual "${R%% *}" "200" "gestor recupera com o e-mail e o código"
[ "$(token gestor.novo@teste.com gestor7890)" != "null" ] && ok "e entra com a senha nova" || falha "login do gestor depois de recuperar"

# Exclusões com o Supabase Auth de verdade
MOTC=$(curl -s "$A/rest/v1/motoristas?select=id&cpf=eq.24681357928" -H "apikey: $K" -H "Authorization: Bearer $TD" | jq -r '.[0].id')
igual "$(rpc "$TD" excluir_motorista "{\"p_motorista_id\":\"$MOTC\"}" | jq -r .ok)" "true" "o dono exclui o motorista e os dados dele"
EMC=$(psql "$DB" -tA -c "select email from public.perfis where cpf = '24681357928'")
TC=$(token "$EMC" nova12345)
igual "$(rpc "$TC" excluir_minha_conta '{}' | jq -r .apagada)" "true" "o motorista, sem empresa, exclui a própria conta"
R=$(funcao entrar_com_cpf "" '{"cpf":"24681357928","senha":"nova12345","aparelho":"rec-4"}')
igual "${R%% *}" "401" "a conta excluída não entra mais"
R=$(funcao cadastrar_motorista "" '{"nome":"Motorista Volta","cpf":"24681357928","senha":"senha6543","aparelho":"conv-2"}')
igual "${R%% *}" "200" "o CPF fica livre para um cadastro novo"
psql "$DB" -tA -c "select public.bloquear_empresa(e.id, 'Teste encerrado.', 30) from public.empresas e where e.nome = 'Transportes W'" >/dev/null
igual "$(rpc "$TW" situacao_acesso '{}' | jq -r .empresa.bloqueada)" "true" "a plataforma encerra o acesso de uma empresa"
igual "$(curl -s "$A/rest/v1/caminhoes?select=id" -H "apikey: $K" -H "Authorization: Bearer $TW" | jq -r length)" "0" "e ela não vê mais nada"
igual "$(rpc "$TW" excluir_minha_empresa '{"p_confirmacao":"Transportes W"}' | jq -r .ok)" "true" "mesmo bloqueado, o dono exclui a empresa e os dados"
igual "$(token dono.w@teste.com novasenha1)" "null" "o login do dono some junto"

# Login interno sorteado e troca automática das contas antigas
igual "$(psql "$DB" -tA -c "select email ~ '^m[0-9a-f]{32}@motorista\.' from public.perfis where cpf = '11144477735'")" "t" "o login interno do motorista é sorteado (não sai do CPF)"
igual "$(token m11144477735@motorista.fortalezadigitalsecurity.com.br senha4567)" "null" "ninguém tenta senha direto no Supabase Auth com o CPF"
ANT=$(criar_usuario m70482156317@motorista.fortalezadigitalsecurity.com.br senhaantiga1)
psql "$DB" -tA -c "insert into public.perfis (id, papel, nome, cpf, email) values ('$ANT', 'motorista', 'Conta Antiga', '70482156317', 'm70482156317@motorista.fortalezadigitalsecurity.com.br')" >/dev/null
R=$(funcao entrar_com_cpf "" '{"cpf":"70482156317","senha":"senhaantiga1","aparelho":"ant-1"}')
igual "${R%% *}" "200" "conta antiga (login tirado do CPF) entra com CPF e senha"
igual "$(psql "$DB" -tA -c "select (p.email ~ '^m[0-9a-f]{32}@') and p.email = u.email from public.perfis p join auth.users u on u.id = p.id where p.cpf = '70482156317'")" "t" "e o login interno dela troca para o sorteado"
igual "$(token m70482156317@motorista.fortalezadigitalsecurity.com.br senhaantiga1)" "null" "o login antigo, tirado do CPF, deixa de funcionar"
R=$(funcao entrar_com_cpf "" '{"cpf":"70482156317","senha":"senhaantiga1","aparelho":"ant-1"}')
igual "${R%% *}" "200" "e ela continua entrando com CPF e senha"

# Proteções gerais das funções
# (CORS: o gateway local do Supabase responde "*" sozinho; a esteira confere o CORS na nuvem.)
GRANDE=$(python3 -c "print('{\"cpf\":\"' + 'x' * 20000 + '\"}')")
R=$(funcao entrar_com_cpf "" "$GRANDE")
igual "${R%% *}" "413" "pedido grande demais é recusado"
R=$(funcao redefinir_acesso "$TD" '{"motorista_id":"nao-e-uuid"}')
igual "${R%% *} $(echo "${R#* }" | jq -r .mensagem)" "403 Motorista não encontrado." "erro técnico não aparece para quem chamou"

# Recuperar a senha por link no e-mail (dono e gestor: pelo e-mail)
limpar_emails dono@teste.com
R=$(funcao pedir_link_senha "" '{"identificador":"Dono@teste.com"}')
igual "${R%% *}" "200" "o dono pede o link para criar uma senha nova"
R2=$(funcao pedir_link_senha "" '{"identificador":"ninguem@teste.com"}')
igual "$(echo "${R2#* }" | jq -r .mensagem | cut -c1-20)" "$(echo "${R#* }" | jq -r .mensagem | cut -c1-20)" "e-mail sem conta: a mesma resposta"
TH=$(token_do_email dono@teste.com)
[ -n "$TH" ] && ok "o e-mail chega com o link (token_hash)" || falha "e-mail de recuperação do dono"
TR=$(verificar_link recovery "$TH")
[ -n "$TR" ] && ok "o link do e-mail abre a sessão para criar a senha" || falha "verificar o link de recuperação"
curl -s -X PUT "$A/auth/v1/user" -H "apikey: $K" -H "Authorization: Bearer $TR" -H "Content-Type: application/json" \
  -d '{"password":"donoNova2026"}' >/dev/null
[ "$(token dono@teste.com donoNova2026)" != "null" ] && ok "o dono entra com a senha nova criada pelo link" || falha "senha nova do dono"
igual "$(token dono@teste.com donosenha1)" "null" "a senha antiga do dono deixa de valer"
igual "$(verificar_link recovery "$TH")" "" "o link só funciona uma vez"
TDN=$(token dono@teste.com donoNova2026)
R=$(curl -s -o /dev/null -w '%{http_code}' -X PUT "$A/auth/v1/user" -H "apikey: $K" -H "Authorization: Bearer $TDN" \
  -H "Content-Type: application/json" -d '{"email":"invasor@teste.com"}')
[ "$R" != "200" ] && ok "o dono não troca o próprio e-mail pelo app (só pela plataforma)" || falha "troca de e-mail do dono" "$R"

# Motorista: cadastra um e-mail dele, confirma pelo link e recupera a senha pelo CPF
R=$(funcao entrar_com_cpf "" '{"cpf":"11144477735","senha":"senha4567","aparelho":"email-1"}')
TME=$(echo "${R#* }" | jq -r .access_token)
limpar_emails moto.real@teste.com
curl -s -X PUT "$A/auth/v1/user" -H "apikey: $K" -H "Authorization: Bearer $TME" -H "Content-Type: application/json" \
  -d '{"email":"moto.real@teste.com"}' >/dev/null
THE=$(token_do_email moto.real@teste.com)
[ -n "$THE" ] && ok "o motorista recebe o link para confirmar o e-mail" || falha "e-mail de confirmação do motorista"
[ -n "$(verificar_link email_change "$THE")" ] && ok "o link confirma o e-mail" || falha "confirmar o e-mail do motorista"
igual "$(psql "$DB" -tA -c "select email from public.perfis where cpf = '11144477735'")" "moto.real@teste.com" "o e-mail confirmado vai para o perfil"
R=$(funcao entrar_com_cpf "" '{"cpf":"11144477735","senha":"senha4567","aparelho":"email-1"}')
igual "${R%% *}" "200" "o motorista continua entrando com CPF e senha"
limpar_emails moto.real@teste.com
R=$(funcao pedir_link_senha "" '{"identificador":"111.444.777-35"}')
igual "${R%% *}" "200" "o motorista pede o link pelo CPF"
THR=$(token_do_email moto.real@teste.com)
TMR=$(verificar_link recovery "$THR")
[ -n "$TMR" ] && ok "o link chega no e-mail confirmado do motorista" || falha "recuperação do motorista pelo CPF"
curl -s -X PUT "$A/auth/v1/user" -H "apikey: $K" -H "Authorization: Bearer $TMR" -H "Content-Type: application/json" \
  -d '{"password":"motoNova2026"}' >/dev/null
R=$(funcao entrar_com_cpf "" '{"cpf":"11144477735","senha":"motoNova2026","aparelho":"email-2"}')
igual "${R%% *}" "200" "e ele entra com CPF e a senha nova"
for i in 1 2 3; do funcao pedir_link_senha "" '{"identificador":"11144477735"}' >/dev/null; done
R=$(funcao pedir_link_senha "" '{"identificador":"11144477735"}')
igual "${R%% *}" "429" "mais de 3 pedidos de link por hora para o mesmo CPF são bloqueados"

# Área da Plataforma (super administrador) e senha provisória forçada no banco
ADM=$(criar_usuario admin@plataforma.teste admin12345)
psql "$DB" -tA -c "insert into public.admins_plataforma (usuario_id) values ('$ADM')" >/dev/null
TA=$(token admin@plataforma.teste admin12345)
igual "$(rpc "$TD" plataforma_empresas '{}' | jq -r .code)" "42501" "dono de empresa não usa a área da Plataforma"
R=$(rpc "$TA" plataforma_criar_empresa '{"p_nome":"Transportes Plataforma","p_dono_nome":"Dona Nova","p_dono_email":"dona.nova@teste.com","p_dias_teste":30,"p_limite_caminhoes":5}')
SP=$(echo "$R" | jq -r .senha_provisoria)
[[ "$SP" =~ ^[A-HJ-NP-Z2-9]{10}$ ]] && ok "o super administrador cadastra a empresa e recebe a senha provisória" || falha "plataforma_criar_empresa" "$R"
TN2=$(token dona.nova@teste.com "$SP")
[ "$TN2" != "null" ] && ok "a dona entra com a senha provisória" || falha "login com a senha provisória"
igual "$(rpc "$TN2" situacao_acesso '{}' | jq -r '.senha_provisoria')" "true" "o app pede a senha nova"
igual "$(curl -s "$A/rest/v1/categorias_gasto?select=id" -H "apikey: $K" -H "Authorization: Bearer $TN2" | jq -r length)" "0" \
  "com a senha provisória o banco não mostra nada da empresa"
curl -s -X PUT "$A/auth/v1/user" -H "apikey: $K" -H "Authorization: Bearer $TN2" -H "Content-Type: application/json" \
  -d '{"password":"donaNova2026","data":{"trocar_senha":false}}' >/dev/null
TN3=$(token dona.nova@teste.com donaNova2026)
igual "$(rpc "$TN3" situacao_acesso '{}' | jq -r '.senha_provisoria')" "false" "trocou a senha: o app libera"
igual "$(curl -s "$A/rest/v1/categorias_gasto?select=id" -H "apikey: $K" -H "Authorization: Bearer $TN3" | jq -r length)" "11" \
  "e o banco mostra os dados da empresa"
igual "$(rpc "$TA" plataforma_empresas '{}' | jq -r '[.[] | select(.nome == "Transportes Plataforma")][0].situacao')" "teste" \
  "a empresa nova aparece na lista da Plataforma, em teste"

# Bloqueio por endereço IP (por último: o IP da esteira fica bloqueado 15 minutos)
for i in $(seq 1 30); do
  R=$(funcao entrar_com_cpf "" "{\"cpf\":\"$(printf '9%010d' "$i")\",\"senha\":\"errada1\",\"aparelho\":\"ip-$i\"}")
  [ "${R%% *}" = "429" ] && break
done
R=$(funcao entrar_com_cpf "" '{"cpf":"98765432100","senha":"errada1","aparelho":"ip-novo"}')
igual "${R%% *}" "429" "30 erros do mesmo IP, mesmo com CPFs e aparelhos diferentes, bloqueiam o IP"

echo "1..$N"
echo "verificações: $N, falhas: $FALHAS"
[ "$FALHAS" -eq 0 ]
