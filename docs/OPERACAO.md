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

A resposta traz o código da empresa. O dono abre o painel, toca em "Criar minha conta" com aquele e-mail
e já entra como dono. Ele libera os gestores em Configurações > Donos e gestores e passa o código para
os motoristas.

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

- Motorista não recebe o código: conferir o SMTP (PASSAGEM, pendência 1) e a caixa de spam.
- Motorista perdeu a senha e o e-mail: painel > Motoristas > o motorista > Redefinir o acesso.
- Motorista diz que lançou mas não aparece: o celular dele precisa de internet; o painel mostra o
  último envio de cada um. O que ele lançou fica guardado no celular até enviar.
