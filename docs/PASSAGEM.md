# Passagem — decisões tomadas e pendências

Atualizado em 17/10/2026 (noite) pelo Claude Code. O usuário pediu para corrigir o que estava pronto e
terminar o resto. Onde a arquitetura deixava ponto em aberto, foi seguida a **proposta** escrita
nela (seção 14) e anotada aqui. Qualquer item pode ser mudado.

## Decisões provisórias (seguindo as propostas da arquitetura)

1. **Dono e gestor entram com e-mail e senha.** Motorista entra com CPF e senha (Edge Function).
2. **Motorista sem e-mail ou que perdeu o acesso:** o gestor redefine pelo painel (Edge Function
   `redefinir_acesso`); a senha provisória aparece só para o gestor e o motorista troca no primeiro login.
3. **Motorista pode editar ou apagar o próprio lançamento até o gestor corrigir.** Depois de corrigido,
   o servidor recusa mudanças do motorista (motivo `ajustado`) e o app mostra o aviso.
4. **Um gestor em uma empresa só** na versão 1.
5. **Código da empresa:** a função `situacao_acesso` só devolve o código para dono e gestor. A linha
   da empresa (com o código) continua legível por motorista já vinculado pelo RLS; risco baixo, porque
   quem usar o código ainda precisa da aprovação do gestor.
6. **Placa:** formatos brasileiros ABC1234 e ABC1D23, guardados sem hífen e em maiúsculas.
7. **Regras de acerto** (comissão padrão, base da comissão, gastos e vale) ficam na tabela `empresas` e
   só o dono muda. O motorista pode mudar a comissão em cada frete.
8. **Painel carrega todos os dados da empresa de uma vez** (piloto com até 5 caminhões). Se ficar
   lento, carregar por período (arquitetura, seção 5).
9. **Relatório por embarcador:** diesel e gastos entram só quando o motorista ligou ao frete; vale não
   entra em relatório de caminhão nem de embarcador (vale é do motorista).
10. **Km rodados do caminhão** = pelo odômetro das abastecidas (do último registro antes do período até
    o maior km do período). Média de diesel continua de tanque cheio a tanque cheio, por caminhão.
11. **Painel web no GitHub Pages** (ramo `gh-pages`) enquanto o repositório estiver público. A arquitetura
    previa Cloudflare Pages; ele precisa de conta e token que não dá para configurar daqui. Quando o
    repositório voltar a ser privado, o GitHub Pages gratuito para de servir: aí migrar para Cloudflare
    Pages (o build é o mesmo, `apps/gestor/build/web`).
12. **APKs assinados com chave de teste** guardada no repositório (`android/app/chave-teste.jks`), para
    atualizar sem desinstalar durante o piloto. Trocar pela chave definitiva antes do Google Play.
13. **R8 desligado na versão de entrega dos APKs.** O encolhedor R8 renomeava métodos que os plugins
    `shared_preferences` e `path_provider` chamam por JNI; os dois apps ficavam parados no logo
    (NoSuchMethodError, achado abrindo os APKs num emulador). Sem R8 o APK fica um pouco maior.
    A esteira agora abre os dois APKs num emulador Android a cada envio (job "aparelho").
14. **Sentry ainda não ligado** (precisa de conta; fica para a Fase 7).
15. **Empresa piloto:** "Empresa Teste (piloto)", dono gestaodefrota2027@gmail.com, código CODIGO-TROCADO,
    plano piloto com 5 caminhões, status teste. Para a empresa real do piloto, rodar `criar_empresa` com
    o nome e o e-mail do dono.
16. **Versões das migrations:** os arquivos foram renomeados para a versão que o Supabase gravou ao
    aplicar (20261017112902, 20261017113308, 20261017113838), para `supabase db push` não estranhar.
    A atualização de contas e termos foi dividida em 4 arquivos (213135, 213313, 213421 e 213600) porque
    só a parte das exclusões exige a confirmação do dono da conta.

## Piloto sem depender de e-mail (17/10/2026, pedido do usuário)

O usuário pediu para deixar tudo pronto sem passos manuais. O envio de e-mail (códigos) depende de
configurar SMTP e modelos no painel do Supabase, então o acesso do piloto passou a funcionar sem e-mail:

- **Motorista** cria a conta no app só com nome, CPF e senha (Edge Function `cadastrar_motorista`). A
  conta usa um e-mail interno derivado do CPF (`m<cpf>@motorista.fortalezadigitalsecurity.com.br`, nunca
  recebe mensagens), para um e-mail digitado por alguém não poder virar acesso de gestor. Esqueceu a
  senha: o gestor redefine pelo painel. Limite de 5 cadastros por hora por instalação do app e 20 por
  endereço de internet.
- **Gestor**: o dono cria o acesso no painel (Configurações > Donos e gestores) e recebe uma senha
  provisória para passar (Edge Function `criar_acesso_gestor`). Esqueceu: o dono gera outra.
- **Dono**: criado pela plataforma com `criar_login_dono` (senha provisória). O dono da empresa piloto é
  gestaodefrota2027@gmail.com.
- Quem entra com senha provisória cria a senha dele no primeiro login.
- O limite de tentativas de login por aparelho usava um id fixo para todos os celulares (um erro de 5
  senhas erradas de qualquer motorista podia bloquear todos por 15 minutos). Agora cada instalação tem o
  seu id.
- O cadastro por e-mail com código continua no código do servidor; volta a ser útil quando houver SMTP.

## Contas, termos e controle da plataforma (17/10/2026, pedido do usuário)

- **Separação entre empresas e entre motoristas:** continua garantida pelo banco (RLS + funções de
  permissão). Agora as funções de permissão também negam tudo quando a empresa está bloqueada, com o
  teste vencido ou excluída.
- **Código individual por motorista:** o gestor cadastra o motorista (nome e CPF) e o painel gera um código
  de 6 caracteres, único na plataforma (não repete entre motoristas nem com código de empresa), de uso
  único, válido por 7 dias e que só funciona com aquele CPF. Com ele o motorista entra na empresa na hora
  (sem aprovação). Gerar de novo para o mesmo CPF cancela o anterior. O código da empresa (pedido com
  aprovação) continua no servidor, mas saiu da tela do painel.
- **Recuperar o acesso sem e-mail:** cada pessoa gera um código de recuperação (12 caracteres) no primeiro
  acesso; com CPF (motorista) ou e-mail (dono e gestor) + código cria a senha nova (Edge Function
  `recuperar_acesso`, 5 erros em 15 minutos bloqueiam). O código fica guardado só cifrado e é trocado a
  cada uso. Sem o código: o patrão redefine o motorista, o dono redefine o gestor, a plataforma redefine o
  dono (`criar_login_dono`).
- **Termos de Uso e Política de Privacidade** (LGPD, Marco Civil, CDC; leis federais, valem em todos os
  estados): textos em `docs/legal/`, mostrados nos apps e publicados no painel web (`termos.html` e
  `privacidade.html`). Aceite obrigatório, guardado com versão, data e IP. Mudou o texto: trocar a data em
  `public.versao_termos()` (migration nova) e em `ferramentas/legal/gerar.py`, rodar o gerador; todos
  aceitam de novo. Papéis: a empresa é controladora dos dados dos motoristas; a Fortaleza Digital Security
  é operadora (e controladora dos dados de conta e de acesso). Dados no Supabase em São Paulo (sa-east-1).
- **Exclusão:** o dono exclui a empresa e todos os dados (digitando o nome da empresa), mesmo com o
  acesso encerrado; a gestão exclui um motorista e os lançamentos dele (digitando EXCLUIR) — a conta dele
  fica sem empresa; o motorista exclui a própria conta (sem empresa: na hora; com empresa: o acesso fecha
  na hora e tudo é apagado em 15 dias, prazo para a empresa guardar o que a lei exige). A auditoria não
  guarda cópia do que foi excluído. Da empresa excluída fica só uma linha "Empresa excluída", sem dados.
- **Controle da plataforma:** `bloquear_empresa`, `liberar_empresa` (com prazo de teste),
  `excluir_empresa_plataforma`, `empresas_da_plataforma` e `limpeza_diaria` — só pelo SQL Editor
  (service_role). Teste vencido ou bloqueio: os apps mostram "Acesso encerrado"; os dados são apagados 30
  dias depois (o prazo é configurável no bloqueio). A limpeza diária roda pelo pg_cron às 03:20.
- **Registros de acesso** (data, hora, IP, app): guardados 6 meses, mesmo depois da exclusão da conta
  (Marco Civil, art. 15). Tentativas de login: 30 dias. Códigos usados ou vencidos: 90 dias.

### Pendências (dependem do usuário)

0. **Parte 4 da atualização do banco** (`supabase/migrations/20261017213600_contas_termos_exclusao.sql`):
   a ferramenta do Supabase usada pelo Claude pede a confirmação do dono da conta para criar funções que
   apagam dados, e esse pedido não aparece no app do Evandro. Formas de aplicar: (a) abrir o Chrome com a
   extensão do Claude conectada, para o Claude rodar no SQL Editor; ou (b) o Evandro cola o arquivo no
   SQL Editor do Supabase e roda. Depois, o Claude registra a migration no histórico
   (`supabase_migrations.schema_migrations`) com o mesmo conteúdo do arquivo e confere o agendamento
   `frota-limpeza-diaria` do pg_cron.

1. **Revisão dos textos legais por um advogado** antes de vender a plataforma. Foram escritos com cuidado,
   mas não substituem a revisão profissional.
2. **CNPJ e endereço completo** da Fortaleza Digital Security para colocar nos Termos e na Política (hoje
   só "Goiatuba (GO)"). Ao incluir, mudar a versão e todos aceitam de novo.
3. **E-mail de contato:** os textos usam gestaodefrota2027@gmail.com como canal do titular. Trocar se houver
   outro e-mail oficial.

## Avisos do conselheiro do Supabase (conferidos, esperados)

- "Signed-in users can execute SECURITY DEFINER function": de propósito. Cada função confere quem
  chama (`auth.uid()`) e devolve erro claro; as de servidor (`criar_empresa`, login por CPF) não têm
  execução para `authenticated`.
- "RLS enabled no policy" em `tentativas_acesso`: de propósito, só o servidor lê e grava.
- "Multiple permissive policies" em `ajustes_gestor` (leitura): duas políticas (gestão e motorista).
  Juntar exige apagar e recriar política, o que a ferramenta da nuvem pede para confirmar; impacto
  pequeno no piloto. Fazer numa migration futura.
- "Unused index": banco novo, ainda sem uso.

## Pendências que dependem do usuário

1. **E-mail dos códigos (SMTP)** — não é mais necessário para o piloto (ver acima). Só para voltar o
   cadastro por e-mail no futuro. O envio padrão do Supabase só entrega para e-mails da equipe da conta
   (gestaodefrota2027@gmail.com) e tem limite muito baixo (poucos e-mails por hora). Para motoristas criarem conta, configurar um SMTP
   próprio em Authentication > Emails > SMTP Settings. Opções: Gmail da conta do projeto com senha de
   app (grátis, até ~500 e-mails por dia) ou um serviço como Brevo ou Resend (plano grátis). Decidir.
2. **Modelos de e-mail com o código** (só junto com o item 1). Em Authentication > Emails > Templates, trocar o texto de
   "Confirm signup", "Magic Link" e "Reset Password" pelos modelos de `supabase/templates/` (eles têm
   `{{ .Token }}`, o código de 6 números que o app pede).
3. **GitHub Pages (opcional, painel no navegador):** se o endereço do painel não abrir, em Settings > Pages escolher a fonte
   "Deploy from a branch", ramo `gh-pages`, pasta `/ (root)`.
4. Nome definitivo do produto.
