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
15. **Empresa piloto:** "Empresa Teste (piloto)", dono gestaodefrota2027@gmail.com (código de entrada trocado em 22/10/2026; não fica nos documentos),
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
- **Recuperar a senha por link no e-mail (desde 22/10/2026, pedido do dono):** "Esqueci a senha" manda um
  link (Edge Function `pedir_link_senha`); o link abre o painel web, onde a pessoa cria a senha nova, e
  todas as sessões antigas são encerradas. Dono e gestor digitam o e-mail; o motorista digita o CPF e o
  link vai para o e-mail que ele cadastrou (no cadastro ou em Configurações) e confirmou pelo link. Sem
  e-mail: o patrão redefine o motorista, o dono redefine o gestor, a plataforma redefine o dono
  (`criar_login_dono`). O código de recuperação saiu dos apps; `recuperar_acesso` fica só para os APKs
  0.2.0 e pode ser retirada depois. Dono e gestor não trocam o próprio e-mail pelo app (o banco recusa).
  Para chegar a qualquer e-mail é preciso o SMTP próprio (Brevo, `docs/EMAIL.md`); sem ele, só a equipe do
  projeto recebe.
- **Área Plataforma (super administrador), decisão do dono em 22/10/2026:** o dono da plataforma
  cadastra e cuida das empresas pelo Frota Gestor (botão Plataforma), sem abrir o Supabase. Super
  administrador = tabela `admins_plataforma` (hoje gestaodefrota2027@gmail.com); cada ação confere no
  banco; nenhuma apaga dados (exclusão continua só pelo SQL). Senha provisória do dono forçada no banco.
  **Melhoria futura (pedida pelo dono):** verificação em duas etapas (TOTP do Google Authenticator, grátis
  no Supabase Auth) para abrir a área Plataforma: exigir `aal2` em `eh_admin_plataforma()` e a tela de
  cadastrar o código no app. Também futuro: estender a senha provisória forçada no banco aos gestores e
  motoristas (hoje o app cobra a troca deles).
- **Código privado, painel público à parte (decisão do dono, 22/10/2026, opção A):** repositório público
  `painel-frota` só com o painel compilado; a Esteira publica lá com o segredo `PAINEL_TOKEN` e o fluxo do
  banco troca o Site URL do Supabase para o painel novo. Passo a passo em `docs/REPOSITORIO-PRIVADO.md`.
  O 404 dos links de 22/10 era o GitHub Pages nunca ligado no repositório (os arquivos já estavam no
  `gh-pages`); a Esteira agora confere se o painel está no ar.
- **E-mail obrigatório para o motorista (decisão do dono, 22/10/2026):** para o motorista recuperar a
  senha sozinho, sem depender do patrão. Cadastro exige o e-mail; contas antigas cadastram no próximo login
  (adiável só sem internet); lembrete no Resumo até confirmar. A senha provisória do patrão continua como
  último recurso (quem perdeu o acesso ao próprio e-mail).
- **Termos na primeira abertura (pedido do dono, 22/10/2026):** os apps e o painel mostram os termos antes
  de qualquer tela; sem aceitar não dá para usar ("Não aceito" fecha o app). O aceite fica guardado no
  aparelho (sobrevive a "Sair da conta") e vai para a conta no cadastro ou no próximo login. Versão nova
  dos termos: aparece de novo.
- **Termos de Uso e Política de Privacidade** (LGPD, Marco Civil, CDC; leis federais, valem em todos os
  estados): textos em `docs/legal/`, mostrados nos apps e publicados no painel web (`termos.html` e
  `privacidade.html`). Aceite obrigatório, guardado com versão, data e IP. Mudou o texto: trocar a data em
  `public.versao_termos()` (migration nova) e em `ferramentas/legal/gerar.py`, rodar o gerador; todos
  aceitam de novo. Papéis: a empresa é controladora dos dados dos motoristas; o operador (Evandro,
  pessoa física, marca Fortaleza Digital Security) trata em nome dela (e controla os dados de conta e acesso). Dados no Supabase em São Paulo (sa-east-1).
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

0. **Parte 4 da atualização do banco** (`20261017213600_contas_termos_exclusao.sql`): aprovada pelo
   Evandro em 22/10/2026 com três condições (backup antes, limpeza em simulação, registro mínimo). É
   aplicada sozinha pelo fluxo "Banco - backup diário e atualização na nuvem" assim que os dois segredos
   do GitHub existirem (ver "Segurança", abaixo).

1. **Revisão dos textos legais por um advogado** antes de vender a plataforma. Foram escritos com cuidado,
   mas não substituem a revisão profissional.
2. **Operador nos textos legais:** desde 22/10/2026 é o Evandro como pessoa física (marca Fortaleza
   Digital Security), em `docs/legal/operador.json`. Falta o **nome completo** (hoje só "Evandro"). Quando
   houver CNPJ: trocar `tipo` para `pessoa_juridica`, `nome` para a razão social e `documento` para o CNPJ,
   mudar a versão e rodar `ferramentas/legal/gerar.py`; todos aceitam de novo.
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

## Segurança "nível empresa" (22/10/2026, pedido do usuário)

Relatório completo em `docs/SEGURANCA.md`. Decisões tomadas sem perguntar (o usuário pediu para fazer
tudo), anotadas aqui:

- **Um segredo só (`CHAVE_MESTRA`)**, porque o dono ainda não tem cofre de senhas. A senha do backup e a
  chave de assinatura dos APKs saem dela, sempre iguais (`ferramentas/chaves/derivar.py`: scrypt + HMAC;
  RSA 3072 determinístico com certificado de datas fixas). Nada disso fica gravado. Cópia da frase em papel
  com o dono. O segundo segredo é o `SUPABASE_ACCESS_TOKEN`; a senha do banco não é mais necessária
  (o CLI usa um login temporário pelo token).
- **Chave de teste aposentada:** `chave-teste.jks` (senha "android") estava no repositório público.
  Apagada e tirada do histórico. Os APKs só são publicados com a chave oficial e depois de abrir no
  emulador. Quem tem os APKs antigos reinstala uma vez.
- **Histórico do repositório reescrito** (git filter-repo) para tirar as chaves de teste, as senhas delas e
  o código antigo da empresa piloto. Cópias antigas podem ficar em cache do GitHub até a limpeza deles;
  como a chave e o código foram trocados, o que vazou não vale mais.
- **Atualização automática do banco da nuvem** depois de cada Esteira verde (com backup antes e a regra
  de aprovação para migrations que apagam dados). O dono não precisa mais apertar botão.
- **Backup** diário às 02:30, guardado 90 dias nos artefatos do GitHub (fora do Supabase), com teste de
  restauração diário. Enquanto o repositório for público, o arquivo cifrado pode ser baixado por quem tem
  conta no GitHub; a criptografia (AES-256, senha derivada) protege o conteúdo. Plano para privado em
  `docs/REPOSITORIO-PRIVADO.md`.
- **Login interno do motorista sorteado** (antes era `m<CPF>@...`, o que permitia tentar senhas direto no
  Supabase Auth sem o bloqueio). Contas antigas trocam no próximo login certo.
- **Regra de senha**: 8 a 72 caracteres, com letras e números, igual em todo lugar. Senhas antigas mais
  fracas continuam valendo até a pessoa trocar (o Supabase só confere ao criar ou trocar).
- **R8 religado** (com regras para as classes chamadas por JNI) e código Dart ofuscado. Os símbolos da
  ofuscação não são guardados enquanto o repositório for público.
- **Registro das ações da plataforma** (`auditoria_plataforma`) por gatilho no banco: pega também o que o
  dono da plataforma fizer direto no SQL Editor. Só inclusão; sem dado pessoal.

- **Transição dos termos:** a nuvem continua na versão 2026-10-17 até os segredos existirem (a migration
  `termos_operador_pessoa_fisica` vai junto com as outras). O painel web já publicado traz o texto novo;
  como o dono e o motorista de teste já aceitaram a versão 17/10, nada muda para eles até lá. Quando a
  versão 22/10 entrar, todos aceitam de novo — com os APKs novos (os antigos não conseguem aceitar a versão
  nova, então reinstalar é obrigatório nessa hora).
- **Etiquetas antigas dos Releases:** esta sessão não pode mexer em etiquetas do GitHub; a Esteira move as
  quatro etiquetas para a versão publicada assim que publicar o primeiro APK oficial.
- **Proteções do GitHub** (varredura de segredos do GitHub, bloqueio no envio, alertas do Dependabot e relato
  privado de vulnerabilidade): esta sessão não pode mudar configurações do repositório; ficam para o dono
  ligar em Settings > Code security (passo a passo no PROJETO).

- **Tamanho mínimo da `CHAVE_MESTRA`:** a recomendação era 24 caracteres ou mais. O Evandro já tinha
  criado a dele, menor, guardada em papel, e pediu para aceitar; o mínimo ficou em 12. Quanto mais curta,
  mais fácil de adivinhar fora do ar (o certificado dos APKs e o backup cifrado são públicos enquanto o
  repositório for público). Se um dia trocar por uma frase maior: APKs reinstalados uma vez e backups
  antigos só abrem com a frase antiga.

### Pendências de segurança (dependem do usuário)

1. **Criar os dois segredos no GitHub** (`SUPABASE_ACCESS_TOKEN` e `CHAVE_MESTRA`) — passo a passo em
   `docs/OPERACAO.md`, "Segredos do GitHub". Sem eles: não há backup automático, a parte 4 não é aplicada
   e os APKs novos não são publicados.
2. **Depois do primeiro backup e da parte 4 na nuvem:** olhar `limpeza_execucoes` por alguns dias e, se
   estiver certo, ligar a limpeza de verdade (`definir_modo_limpeza('valendo')`).
3. **Reinstalar os apps** quando sair o primeiro APK com a chave oficial (assinatura nova).
4. **Plano Pro do Supabase** (quando houver cliente pagando): liga a proteção contra senha vazada, o
   limite de sessão e o backup do próprio Supabase (com restauração a qualquer ponto).
5. **Repositório privado + Cloudflare Pages** (`docs/REPOSITORIO-PRIVADO.md`).
6. **SMTP próprio** (`docs/EMAIL.md`), e então tirar dos apps a tela antiga de "código por e-mail" e
   desligar o cadastro aberto do Supabase Auth (hoje ligado só por causa dessa tela).
7. **Nome completo do Evandro** para os textos legais.

## Modalidades de operação (22/10/2026, pedido do usuário)

Respostas do Evandro antes de começar:

- **Sider = Baú; Caçamba = Graneleiro** (Grade baixa também começa igual ao Graneleiro).
- **Baú sem dinheiro do frete na viagem:** nessas empresas o frete cai na conta da empresa e o motorista não
  pega valor em mãos. Vales, diesel e gastos continuam como hoje (o motorista lança as notas).
- **Acerto:** o gestor lança a comissão em reais e os descontos (motivo e valor); para receber = comissão −
  descontos − vales (diesel e gastos só se a regra da empresa mandar). O motorista vê o acerto fechado no app.
- **Campos:** o dono mostra, esconde, torna obrigatório e renomeia no painel; campos totalmente novos são
  criados pela Plataforma (sem APK novo).

Decisões tomadas na construção (confirmar no piloto):

- **Cavalo fixo no Baú:** se o motorista ainda não tem caminhão, ele escolhe na primeira vez; depois o app
  esconde o "Trocar" e só o gestor troca (no painel). O banco não bloqueia a troca enviada por um app antigo.
- **Uma carreta por vez:** o app pede para desengatar antes de engatar outra. O banco não impede duas viagens
  abertas (para não recusar o que foi feito sem internet).
- **Viagem não tem correção do gestor** (como o frete tem): para corrigir, o motorista muda no app. Fica como
  melhoria futura.
- **Obrigatório** é conferido no app; o banco confere o formato (placa, datas, tamanhos).
- **Acerto:** períodos do mesmo motorista não podem se sobrepor; corrigir muda o mesmo acerto (a auditoria
  guarda o antes); não há botão para apagar acerto. Os dias do período são os de Brasília.
- **Motorista sem modalidade** (empresa com mais de uma): o app pede a escolha antes de abrir (precisa de
  internet). O gestor também pode definir pelo painel.
- **Empresa nova** começa só com Graneleiro; o dono liga as outras.
- **Exclusão de dados:** aprovada pelo Evandro em 23/10/2026, com o PDF de todos os dados antes (ver
  "Exclusão completa com o PDF antes").
- **Campos novos da Plataforma:** até 20 por modalidade, tipos texto, número, número inteiro, dinheiro, data,
  data e hora, sim ou não e cidade; o tipo não muda depois; campo desativado some dos formulários e o que já
  foi anotado fica guardado. Os campos de fábrica não mudam pela Plataforma.

## Registro de paradas (22/10/2026, pedido do usuário)

Decisões tomadas na construção (confirmar no piloto):

- **Limite:** o padrão de 5h30 fica só no banco (valor padrão da coluna). O dono escolhe entre 0h30 e 24h00
  (faixa de segurança do banco, não é número de lei).
- **Intervalo sem descanso:** do fim de um descanso (refeição, descanso ou pernoite, conforme o catálogo) até o
  começo do próximo. No período que chega até hoje, conta também desde o último descanso até agora. Café,
  abastecimento, fiscalização etc. não interrompem o intervalo.
- **Mais de um dia sem descanso registrado** não entra na conta nem no destaque: quase sempre é folga em casa
  ou registro esquecido. Aparece como aviso para o patrão conferir. Confirmar com o Evandro se prefere outro
  jeito (por exemplo, um motivo "folga").
- **Parada nova com outra aberta:** a aberta termina na hora em que a nova começa.
- **Horário informado depois:** "Parei antes e esqueci de registrar", "Esqueci de retomar" ou mudar o horário
  na parada marcam a parada como ajustada (o patrão vê a etiqueta). Mudar só o motivo não marca.
- **Parada aberta há mais de um dia** ganha a etiqueta "esqueceu de retomar?".
- **Desligar as paradas** esconde a aba; o que já foi registrado fica guardado e volta a aparecer se ligar.
- **No celular do gestor** a seção Paradas não ocupa aba embaixo (já são cinco); abre pelo cartão "Paradas" do
  Painel e pela aba Paradas da tela do motorista.
- **Exclusão:** aprovada em 23/10/2026 (ver "Exclusão completa com o PDF antes"); as paradas vão junto.

## Exclusão completa com o PDF antes (23/10/2026, aprovado pelo usuário)

- **Aprovado no chat:** exclusão de motorista e de empresa apaga também viagens, acertos, paradas e as
  modalidades da empresa, sempre com o PDF de todos os dados gerado antes. Exclusão automática: aviso no painel
  com o botão "Baixar PDF" (nada fica guardado no servidor).
- **O PDF é gerado no app do gestor** (o servidor não tem como saber se a pessoa guardou o arquivo). Pelo
  painel, a exclusão só segue depois de o PDF ser gerado e entregue ao "compartilhar" ou ao download.
- **Exclusões automáticas** (motorista que pediu para sair, 15 dias; empresa com o acesso encerrado): o
  Painel avisa (motorista) e, nos últimos 7 dias de acesso, avisa a empresa; com o acesso encerrado, o dono
  baixa o PDF na tela "Acesso encerrado" até a data da exclusão (função `exportar_dados_empresa`).
- **Exclusão pela Plataforma** (super administrador): não tem como gerar o PDF da empresa (a Plataforma não lê
  os dados). Antes de excluir pela Plataforma, pedir ao dono para baixar o PDF (ele consegue mesmo bloqueado).
- **Ordem da esteira:** o painel web vai ao ar alguns minutos antes de o banco da nuvem ser atualizado. Por
  isso tabela nova entra no painel como opcional (abre sem ela) e a esteira só publica depois de o banco passar
  nos testes.

## Visual do cartaz (23/10/2026, pedido do usuário)

- **Escuro por padrão**, como o cartaz; o motorista e o gestor escolhem claro ou "igual ao celular" em
  Configurações > Aparência (guardado só naquele aparelho).
- **Motorista:** três abas (Início, Lançamentos, Resumo). Fretes, Diesel, Gastos, Vales, Paradas e Acertos
  abrem pelos botões do Início (cada um com o botão de novo lançamento) e pelo "Lançar".
- **Lançamentos** do motorista: tudo numa lista (fretes, viagens, diesel, gastos e vales), do mais novo para o
  mais velho; as paradas ficam só na tela delas.
