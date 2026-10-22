# Operação

Guia de operação do piloto. Segredos (senhas, chave service_role) nunca entram aqui nem no repositório.

## Onde fica cada coisa

- Banco, login e Edge Functions: Supabase, projeto `uinvhwhqhudniipobslu` (conta gestaodefrota2027).
- Código e esteira: GitHub `dasilvagonchoroskie-cpu/plataforma-gestao-frota`, ramo `main`.
- APK do motorista: Release `motorista-teste`. APK do gestor: Release `gestor-teste`.
- Painel web: ramo `gh-pages` (GitHub Pages), https://dasilvagonchoroskie-cpu.github.io/plataforma-gestao-frota/
- Registros da esteira: Release `registros` (banco.log, nucleo.log, motorista.log, gestor.log).

## Criar uma empresa cliente

No Supabase (SQL Editor, como dono da plataforma):

    select public.criar_empresa('Nome da Transportadora', 'email-do-dono@exemplo.com', null, 'piloto', 5, 'teste');

A resposta traz o id da empresa (`empresa_id`). Depois crie o login do dono com uma senha provisória (passe
para ele; no primeiro login ele aceita os termos, cria a senha dele e anota o código de recuperação):

    select public.criar_login_dono('email-do-dono@exemplo.com', 'Nome do Dono', 'SENHA123');

O mesmo comando, rodado de novo, gera outra senha para um dono que esqueceu a senha e o código de
recuperação. O dono cria os gestores em Configurações > Donos e gestores (senha provisória). Para cada
motorista, o gestor toca em Motoristas > Cadastrar motorista (nome e CPF) e manda o código gerado (só
daquele motorista, vale 7 dias, uma vez só). O motorista cria a conta no app (nome, CPF e senha) e digita
o código: entra na empresa na hora.

Para dar um prazo de teste (por exemplo 30 dias), logo depois de criar:

    select public.liberar_empresa('ID-DA-EMPRESA', now() + interval '30 days');

## Controle das empresas (só a plataforma)

Só pelo SQL Editor do Supabase (conta gestaodefrota2027). Nenhum dono ou gestor consegue mudar isto pelo
app, e nenhum deles tira o seu acesso (você entra pelo Supabase, não pelo app).

    -- Visão geral: situação, prazo, quando os dados serão apagados, motoristas, caminhões, último envio.
    select * from public.empresas_da_plataforma();

    -- Encerrar o acesso agora (os apps fecham; os dados são apagados sozinhos 30 dias depois).
    select public.bloquear_empresa('ID-DA-EMPRESA', 'O período de teste terminou.', 30);

    -- Encerrar sem apagar sozinho (por exemplo, pagamento atrasado).
    select public.bloquear_empresa('ID-DA-EMPRESA', 'Pagamento em atraso.', null);

    -- Liberar de novo (sem prazo) ou com novo prazo.
    select public.liberar_empresa('ID-DA-EMPRESA');
    select public.liberar_empresa('ID-DA-EMPRESA', now() + interval '30 days');

    -- Apagar agora tudo de uma empresa (não tem volta).
    select public.excluir_empresa_plataforma('ID-DA-EMPRESA');

Quando o prazo de teste (`acesso_ate`) passa, o acesso fecha sozinho e os dados são apagados 30 dias
depois, se ninguém liberar. A limpeza roda todo dia às 03:20 (horário de Brasília) pelo pg_cron
(`frota-limpeza-diaria`); para rodar na hora: `select public.limpeza_diaria();`.

O dono também pode excluir a conta da empresa e todos os dados pelo app (Configurações > Excluir a conta
da empresa), mesmo com o acesso encerrado. O motorista exclui a própria conta em Configurações.

## Mudar plano, limite ou suspender

Só pelo SQL Editor (o dono da empresa não muda isso):

    update public.empresas set limite_caminhoes = 10, status = 'ativa' where id = '...';
    update public.empresas set status = 'suspensa' where id = '...';   -- motoristas não enviam; dados ficam

## Aplicar mudança no banco da nuvem (sem computador)

Pelo site do GitHub (no celular, use "Versão para computador" do navegador se não aparecer Settings):

1. Uma vez só, criar 3 segredos em Settings ("Configurações") > Secrets and variables ("Segredos e
   variáveis") > Actions > New repository secret ("Novo segredo do repositório"):
   - `SUPABASE_ACCESS_TOKEN`: no Supabase, Account ("Conta") > Access Tokens ("Tokens de acesso") >
     Generate new token ("Gerar novo token").
   - `SUPABASE_DB_PASSWORD`: no projeto, Project Settings ("Configurações do projeto") > Database ("Banco
     de dados") > Reset database password ("Redefinir senha do banco"). Os apps não usam esta senha.
   - `BACKUP_SENHA`: uma frase longa (16 caracteres ou mais) inventada pelo dono e guardada em papel.
     Sem ela nenhum backup abre. Nunca mandar no chat.
2. Actions ("Ações") > "Banco - backup e atualização na nuvem" > Run workflow ("Executar fluxo de
   trabalho"). `so-backup` só faz o backup; `backup-e-aplicar` (digitando APLICAR) faz o backup e, só se
   ele der certo, aplica as migrations pendentes (`supabase db push`).
3. O backup criptografado fica na página da execução, em Artifacts ("Artefatos"), por 90 dias.

## Limpeza diária (pg_cron)

Roda às 03:20 de Brasília (`frota-limpeza-diaria`). Começa em modo simulação: só anota o que apagaria.

    -- o que a limpeza apagaria (últimas execuções):
    select quando, modo, resultado from public.limpeza_execucoes order by quando desc limit 10;
    -- registro de exclusões (empresa, tipo, quem pediu, data; sem dado pessoal):
    select * from public.registro_exclusoes order by quando desc limit 50;
    -- depois de conferir, ligar de verdade (ou voltar para simulação):
    select public.definir_modo_limpeza('valendo');
    select public.definir_modo_limpeza('simulacao');

## Mudança no banco

Sempre por migration nova em `supabase/migrations/`, testada na esteira (job Banco) antes de aplicar.

## Backup

No plano grátis do Supabase não há backup diário. Antes do piloto real: assinar o Pro (backup diário)
e combinar uma exportação semanal (`supabase db dump`) guardada fora do Supabase.

## Problemas comuns

- Esqueceu a senha: no app, "Esqueci a senha" > código de recuperação (CPF ou e-mail + código + senha
  nova). Sem o código: motorista pede ao gestor (Motoristas > o motorista > Redefinir o acesso); gestor
  pede ao dono (Configurações > Donos e gestores); dono pede à plataforma (`criar_login_dono`).
- Código do motorista venceu ou foi perdido: Motoristas > Cadastrar motorista de novo (o anterior para de
  valer).
- Pedido de titular de dados (LGPD) pelo e-mail gestaodefrota2027@gmail.com: responder em até 15 dias. Se
  for sobre dados que a empresa controla, encaminhar ao dono da empresa.
- Motorista diz que lançou mas não aparece: o celular dele precisa de internet; o painel mostra o
  último envio de cada um. O que ele lançou fica guardado no celular até enviar.
