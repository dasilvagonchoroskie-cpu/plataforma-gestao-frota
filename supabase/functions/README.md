# Edge Functions

- `entrar_com_cpf`: login do motorista com CPF e senha (erro sempre igual, bloqueio de 15 minutos depois de 5 erros).
- `redefinir_acesso`: o gestor cria uma senha provisória para um motorista da empresa dele.
- `cadastrar_motorista`: cadastro do motorista sem e-mail (nome, CPF e senha); limite de 5 por hora por aparelho.
- `criar_acesso_gestor`: o dono cria ou renova o acesso de um gestor com senha provisória (sem e-mail).
- `pedir_link_senha`: manda o link para criar a senha nova por e-mail (dono e gestor pelo e-mail; motorista pelo
  CPF, para o e-mail que ele confirmou). Mesma resposta exista ou não a conta; 3 pedidos por hora por CPF/e-mail
  e 10 por IP.
- `recuperar_acesso`: (antigo, só para os APKs 0.2.0) senha nova com o código de recuperação; os apps novos usam o link.
- `_compartilhado/apoio.ts`: respostas, CORS e chaves (vindas do ambiente do Supabase).

Todas são publicadas com `verify_jwt = false` (ver `supabase/config.toml`) porque o
login acontece antes de existir sessão e a outra confere o token do gestor por conta própria.
Nenhuma chave secreta fica no repositório.
