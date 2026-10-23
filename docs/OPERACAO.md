# Operação

Guia de operação do piloto. Segredos (senhas, chave service_role, CHAVE_MESTRA) nunca entram aqui nem no
repositório. Em caso de incidente de segurança: `docs/INCIDENTES.md`.

## Onde fica cada coisa

- Banco, login e Edge Functions: Supabase, projeto `uinvhwhqhudniipobslu` (conta gestaodefrota2027).
- Código e esteira: GitHub `dasilvagonchoroskie-cpu/plataforma-gestao-frota`, ramo `main`.
- APK do motorista: Release `motorista-teste`. APK do gestor: Release `gestor-teste`.
- Painel web (GitHub Pages): com o segredo `PAINEL_TOKEN`, no repositório público `painel-frota`,
  https://dasilvagonchoroskie-cpu.github.io/painel-frota/ ; sem ele, no ramo `gh-pages` deste repositório,
  https://dasilvagonchoroskie-cpu.github.io/plataforma-gestao-frota/ (docs/REPOSITORIO-PRIVADO.md). O Pages
  precisa estar ligado em Settings > Pages do repositório onde o painel é publicado.
- Registros da esteira: Release `registros` (banco.log, nucleo.log, motorista.log, gestor.log).

## Criar uma empresa cliente

**Pelo app (recomendado):** entre no Frota Gestor (ou no painel) com a conta da plataforma
(gestaodefrota2027@gmail.com) > botão **Plataforma** (escudo, no alto) > **Cadastrar empresa**: nome da
empresa, nome e e-mail do dono, prazo de teste e limite de caminhões. O app mostra a senha provisória uma
vez e um recado pronto para mandar ao dono pelo WhatsApp. Na mesma área: dar 30 dias de teste, liberar
sem prazo, bloquear (com motivo) e gerar senha provisória para o dono que perdeu o acesso ao e-mail. O
banco confere em cada ação se quem chama é o super administrador (tabela `admins_plataforma`) e registra
tudo na auditoria (origem `plataforma_app`). Enquanto o dono não troca a senha provisória, o banco não
mostra nada da empresa para ele.

Para incluir outro super administrador (só pelo SQL Editor):

    insert into public.admins_plataforma (usuario_id)
    select id from auth.users where lower(email) = 'email-da-pessoa@exemplo.com';

**Pelo Supabase (SQL Editor, como dono da plataforma)**, se precisar:

    select public.criar_empresa('Nome da Transportadora', 'email-do-dono@exemplo.com', null, 'piloto', 5, 'teste');

A resposta traz o id da empresa (`empresa_id`). Depois crie o login do dono com uma senha provisória (passe
para ele; no primeiro login ele cria a senha dele):

    select public.criar_login_dono('email-do-dono@exemplo.com', 'Nome do Dono', 'SENHA123');

O mesmo comando, rodado de novo, gera outra senha para um dono que esqueceu a senha e não recebe o link
no e-mail. O dono cria os gestores em Configurações > Donos e gestores (senha provisória). Para cada
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

## Modalidades e campos (Plataforma)

No app do gestor ou no painel, com a conta do super administrador: Configurações > Área da Plataforma >
botão "Modalidades e campos" (ícone de caminho). Ali dá para:

- **Criar uma modalidade:** "Nova modalidade", nome e como funciona (por frete, como o Graneleiro, ou por
  viagem, como o Baú). Depois o dono de cada empresa liga em Configurações > Modalidades de operação.
- **Criar um campo novo:** abra a modalidade e toque em "Novo campo": nome, tipo, se é obrigatório e (por
  viagem) quando o motorista preenche. Aparece no app do motorista na próxima conexão, sem APK novo.
- **Desativar um campo novo:** toque nele e ligue "Desativado". O que já foi anotado fica guardado.

O dono de cada empresa renomeia, esconde e torna obrigatório em Configurações > Modalidades de operação.

## Registro de paradas

O dono liga em Configurações > Registro de paradas e define o limite sem descanso (horas e minutos). Os apps
dos motoristas mostram a aba Paradas na próxima conexão. Os motivos ficam na tabela `motivos_parada` (mudar
nome, ordem ou o que conta como descanso só por migration). O relatório sai em Paradas > motorista > PDF ou
Planilha, sempre com o aviso de que não substitui o tacógrafo.

## Mudar plano, limite ou suspender

Só pelo SQL Editor (o dono da empresa não muda isso):

    update public.empresas set limite_caminhoes = 10, status = 'ativa' where id = '...';
    update public.empresas set status = 'suspensa' where id = '...';   -- motoristas não enviam; dados ficam

## Segredos do GitHub (uma vez só)

A plataforma tem **um** segredo de verdade, a `CHAVE_MESTRA`. Dela saem, sempre iguais, a senha que
cifra os backups e a chave que assina os APKs (`ferramentas/chaves/derivar.py`); nada disso fica gravado
em lugar nenhum. O GitHub guarda os segredos e não mostra de volta para ninguém, nem para o dono.

Pelo site do GitHub (no celular, use "Versão para computador" do navegador se não aparecer Settings):
Settings ("Configurações") > Secrets and variables ("Segredos e variáveis") > Actions >
New repository secret ("Novo segredo do repositório"). Criar dois:

1. `SUPABASE_ACCESS_TOKEN` — no Supabase (conta gestaodefrota2027): foto da conta > Account preferences
   ("Preferências da conta") > Access Tokens ("Tokens de acesso") > Generate new token ("Gerar novo
   token"), nome `github-frota`, validade de 1 ano. Copie e cole direto no GitHub (não mande em chat).
   Com ele o fluxo entra no banco com um login temporário; a senha do banco não é usada.
   Na tela "Gerar token": Acesso a recursos = Projeto (só o `plataforma-gestao-frota`); Permissões =
   acesso total (fica limitado a este projeto). O token vence (ex.: 90 dias); quando vencer, o fluxo do
   banco falha e o GitHub manda e-mail: gere outro igual e troque o segredo (Update ("Atualizar")).
2. `CHAVE_MESTRA` — uma frase longa inventada na hora: **8 palavras ou mais, sem sentido entre si, com um
   número no meio** (mínimo 12 caracteres; recomendado 24 ou mais: quanto mais longa, melhor). Escreva **à mão em papel** e
   guarde em casa, longe do celular. Sem ela nenhum backup abre e os APKs mudam de assinatura.
   Não troque depois: trocar muda a assinatura dos apps (todos reinstalam) e os backups antigos só abrem
   com a frase antiga.

Quando o cofre de senhas existir (projeto futuro), a frase vai para lá também.

Depois, ainda em Settings ("Configurações") > Code security ("Segurança do código"), ligar (botão
Enable ("Ativar")): Dependabot alerts ("Alertas do Dependabot"), Dependabot security updates
("Atualizações de segurança do Dependabot"), Secret Protection ("Proteção de segredos") com Push
protection ("Bloqueio no envio") e Private vulnerability reporting ("Relato privado de vulnerabilidade").

## Atualizações do banco da nuvem (automático)

Depois de cada Esteira verde no ramo `main`, o fluxo "Banco - backup diário e atualização na nuvem"
faz o backup criptografado e, com ele pronto, aplica as migrations pendentes (`supabase db push`) e as
regras de login de `supabase/auth-nuvem.json`. Antes de aplicar ele confere a regra do dono: migration que
apaga dados precisa da linha `-- aprovado-por: Evandro em DD/MM/AAAA` (`ferramentas/seguranca/
conferir_aprovacao.py`); sem ela, para.

Para rodar à mão: Actions ("Ações") > "Banco - backup diário e atualização na nuvem" > Run workflow
("Executar fluxo de trabalho"). `so-backup` só faz o backup; `backup-e-aplicar` (digitando APLICAR) faz
o backup e aplica.

## Backup diário e restauração

- **Quando:** todo dia às 02:30 (Brasília), antes da limpeza das 03:20, e antes de cada atualização.
- **O quê:** papéis, estrutura e dados (inclusive os logins do Supabase Auth e o agendamento do
  pg_cron), num arquivo `backup-frota-AAAAMMDD-HHMMSS.tar.gz.gpg` cifrado com AES-256.
- **Onde:** na página da execução do fluxo, em Artifacts ("Artefatos"), por 90 dias (fora do Supabase).
- **Prova de que volta:** logo depois de cada backup, o job "Teste de restauração" sobe um Supabase vazio
  com as mesmas versões da nuvem, restaura o backup e confere as linhas de cada tabela. A Esteira faz o
  mesmo teste com o banco local a cada envio. Se o teste falhar, o GitHub manda e-mail.

### Restaurar de verdade (desastre: projeto apagado ou dados perdidos)

1. Não mexa no projeto quebrado. No Supabase, crie um projeto **novo** (mesma região, São Paulo).
2. No GitHub: Actions > "Banco - backup diário..." > a execução do dia que você quer > Artifacts >
   baixe `backup-frota-...` (vem um .zip com o .gpg dentro).
3. Num computador com o Supabase CLI e o `psql` (ou peça para o Claude fazer numa sessão nova):
   - a senha do backup sai da frase do papel:
     `CHAVE_MESTRA='a frase' python3 ferramentas/chaves/derivar.py segredo frota-backup-v1`
   - restaure no projeto novo e confira as linhas (a ligação, "Connection string", fica em Connect
     ("Conectar") > Session pooler no projeto novo):
     `BACKUP_SENHA=... bash ferramentas/backup/restaurar.sh backup-frota-....tar.gz.gpg 'postgresql://...'`
   O script aplica tudo numa transação (ou entra tudo, ou nada) e mostra "diferenças: 0" quando bate.
4. Troque nos apps e na esteira o endereço do projeto (`uinvhwhqhudniipobslu`) e a chave pública pelos do
   projeto novo, publique as Edge Functions nele e rode a Esteira.
5. Siga `docs/INCIDENTES.md` (avisar empresas e, se for o caso, a ANPD).

## Assinatura dos APKs

A Esteira deriva a chave de assinatura da `CHAVE_MESTRA` só durante a compilação (`ferramentas/chaves/
com_assinatura.sh`) e apaga no fim. Sem o segredo, os APKs saem com a chave de depuração e **não são
publicados**. A impressão digital do certificado (SHA-256) aparece no job "Publicar" e serve para
conferir o APK (`apksigner verify --print-certs`). A chave de teste antiga (`chave-teste.jks`) foi
aposentada em 22/10/2026: quem tinha os APKs antigos reinstala uma vez.

## Limpeza diária (pg_cron)

Roda às 03:20 de Brasília (`frota-limpeza-diaria`). Começa em modo simulação: só anota o que apagaria.

    -- o que a limpeza apagaria (últimas execuções):
    select quando, modo, resultado from public.limpeza_execucoes order by quando desc limit 10;
    -- registro de exclusões (empresa, tipo, quem pediu, data; sem dado pessoal):
    select * from public.registro_exclusoes order by quando desc limit 50;
    -- depois de conferir, ligar de verdade (ou voltar para simulação):
    select public.definir_modo_limpeza('valendo');
    select public.definir_modo_limpeza('simulacao');

## Registro das ações da plataforma

Toda ação sobre empresas (criar, bloquear, liberar, alterar, excluir, trocar código, criar login do dono)
e toda mudança de configuração (ex.: modo da limpeza) fica em `auditoria_plataforma`, com data, o que
mudou e quem fez (plataforma, dono, gestor, servidor ou agendamento). Sem nome, e-mail ou CPF. Ninguém
altera nem apaga esse registro, nem o dono do banco.

    select quando, acao, empresa_id, origem, campos from public.auditoria_plataforma order by id desc limit 50;

## Regras de login

Senha de 8 a 72 caracteres, com letras e números (apps, Edge Functions, banco e Supabase Auth). Login do
motorista bloqueia por 15 minutos depois de 5 erros seguidos (por CPF e por aparelho) e o endereço IP
fica bloqueado depois de 30 erros em 15 minutos. Link de senha nova: 3 pedidos por hora por CPF ou
e-mail e 10 por hora por IP; o link vale 1 hora e uma vez só.
O login interno do motorista é sorteado (não sai do CPF), então ninguém tenta senha direto no Supabase.
Sessão: token de 1 hora renovado com rotação. A proteção contra senha vazada (HaveIBeenPwned) e o limite
de tempo de sessão só existem no plano Pro: o fluxo tenta ligar e só avisa se o plano não deixar.

## Mudança no banco

Sempre por migration nova em `supabase/migrations/`, testada na Esteira (job Banco) antes de aplicar.
Se a migration apagar dados, precisa da aprovação escrita do dono no começo do arquivo.

## Problemas comuns

- Esqueceu a senha: no app, "Esqueci a senha" > e-mail (dono e gestor) ou CPF (motorista) > chega um link
  no e-mail > a senha nova é criada no painel web. O link não chega: conferir o spam e o SMTP próprio
  (`docs/EMAIL.md`). "Este link não vale mais": cada pedido novo cancela o link anterior e o e-mail pode
  levar 1 ou 2 minutos; usar só o e-mail mais novo (o registro do Supabase Auth mostra "One-time token
  not found" quando o link usado era de um pedido antigo). Sem acesso ao e-mail: motorista pede ao gestor (Motoristas > o motorista > Redefinir
  o acesso); gestor pede ao dono (Configurações > Donos e gestores); dono pede à plataforma
  (`criar_login_dono`).
- Código do motorista venceu ou foi perdido: Motoristas > Cadastrar motorista de novo (o anterior para de
  valer).
- Pedido de titular de dados (LGPD) pelo e-mail gestaodefrota2027@gmail.com: responder em até 15 dias. Se
  for sobre dados que a empresa controla, encaminhar ao dono da empresa.
- Motorista diz que lançou mas não aparece: o celular dele precisa de internet; o painel mostra o
  último envio de cada um. O que ele lançou fica guardado no celular até enviar.
