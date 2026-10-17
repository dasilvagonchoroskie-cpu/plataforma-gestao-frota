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

A resposta traz o código da empresa. Depois crie o login do dono com uma senha provisória (passe para ele;
no primeiro login ele cria a senha dele):

    select public.criar_login_dono('email-do-dono@exemplo.com', 'Nome do Dono', 'SENHA123');

O mesmo comando, rodado de novo, gera outra senha para um dono que esqueceu. O dono cria os gestores em
Configurações > Donos e gestores (senha provisória) e passa o código da empresa para os motoristas, que
criam a conta no app só com nome, CPF e senha.

## Mudar plano, limite ou suspender

Só pelo SQL Editor (o dono da empresa não muda isso):

    update public.empresas set limite_caminhoes = 10, status = 'ativa' where id = '...';
    update public.empresas set status = 'suspensa' where id = '...';   -- motoristas não enviam; dados ficam

## Mudança no banco

Sempre por migration nova em `supabase/migrations/`, testada na esteira (job Banco) antes de aplicar.

## Backup

No plano grátis do Supabase não há backup diário. Antes do piloto real: assinar o Pro (backup diário)
e combinar uma exportação semanal (`supabase db dump`) guardada fora do Supabase.

## Problemas comuns

- Motorista perdeu a senha e o e-mail: painel > Motoristas > o motorista > Redefinir o acesso.
- Motorista diz que lançou mas não aparece: o celular dele precisa de internet; o painel mostra o
  último envio de cada um. O que ele lançou fica guardado no celular até enviar.
