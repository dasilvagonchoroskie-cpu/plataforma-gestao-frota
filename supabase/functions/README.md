# Edge Functions

- `entrar_com_cpf`: login do motorista com CPF e senha (erro sempre igual, bloqueio de 15 minutos depois de 5 erros).
- `redefinir_acesso`: o gestor cria uma senha provisória para um motorista da empresa dele.
- `_compartilhado/apoio.ts`: respostas, CORS e chaves (vindas do ambiente do Supabase).

As duas são publicadas com `verify_jwt = false` (ver `supabase/config.toml`) porque o
login acontece antes de existir sessão e a outra confere o token do gestor por conta própria.
Nenhuma chave secreta fica no repositório.
