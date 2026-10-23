# Progresso — Plataforma de Gestão de Frota

Atualizado em 23/10/2026 pelo Claude Code. "Testado" quer dizer que o comando
abaixo rodou e passou; o resto está marcado como não testado.

## Resumo

| Fase | Situação |
|---|---|
| 0 — preparação | feita |
| 1 — banco e segurança | feita e testada; aplicada no Supabase novo |
| 2 — núcleo de regras | feita e testada |
| 3 — app do motorista offline | feita e testada; APK de teste na esteira |
| 4 — acesso e sincronização | feita e testada; falta SMTP próprio (ver PASSAGEM) |
| 5 — app e painel do gestor | feita e testada; APK e painel web na esteira |
| 6 — relatórios e ajustes | feita e testada |
| 7 — acabamento e piloto | não começada |

## Fase 1 — banco e segurança

- **feito e testado** — 3 migrations em `supabase/migrations/` (esquema com RLS, funções seguras e
  apoio ao painel). Os nomes dos arquivos usam a mesma versão gravada no Supabase da nuvem.
- **feito e testado** — 148 verificações pgTAP em `supabase/tests/` (isolamento entre empresas e
  motoristas, entrada na empresa, sincronização sem duplicar, ajustes, auditoria, limite do plano,
  login por CPF, pedidos de entrada para o gestor).
  Comando local: `PGTAP_SQL=... supabase/tests/local/rodar.sh` → `total de verificações que passaram: 148`.
  Na esteira: job "Banco" com `supabase start` (Postgres 17) + o mesmo script.
- **feito e testado** — Edge Functions `entrar_com_cpf` e `redefinir_acesso` com 15 verificações de ponta a
  ponta (`supabase/tests/funcoes/testar.sh`, job "Banco").
- **feito** — Aplicado no projeto `uinvhwhqhudniipobslu` (conta gestaodefrota2027): as 3 migrations
  (conferidas por hash com os arquivos) e as 2 Edge Functions (verify_jwt desligado, a função confere
  o acesso sozinha). Conselheiro de segurança do Supabase: só avisos esperados (ver PASSAGEM).
- **feito** — Empresa piloto criada com `criar_empresa`: "Empresa Teste (piloto)", dono
  gestaodefrota2027@gmail.com (o código de entrada foi trocado em 22/10/2026 e não fica nos documentos).

## Fase 2 — núcleo de regras (`packages/nucleo`)

- **feito e testado** — Regras do Meu Frete portadas (centavos), média de diesel por caminhão,
  períodos, ajustes, PDF e CSV. `dart test` → 38 testes passaram.

## Fase 3 e 4 — app do motorista (`apps/motorista`)

- **feito e testado** — Banco local (drift), fila de envio, sincronização em lote, cadastro com código,
  login por CPF, esqueci a senha, entrada na empresa, troca de caminhão, resumo e PDF.
  `flutter analyze` sem problemas; `flutter test --exclude-tags capturas` → 21 testes passaram;
  11 imagens de tela conferidas.
- **feito** — APK de teste no Release `motorista-teste` (assinado com a chave de teste).
- **não feito** — SMTP próprio para os códigos por e-mail (depende de decisão do usuário).

## Fases 5 e 6 — app e painel do gestor (`apps/gestor`)

- **feito e testado** — Um código para celular e web: entrar/criar conta/esqueci a senha; painel com
  números do período e alertas; motoristas (código da empresa, aprovar/recusar, caminhão atual,
  desligar, redefinir acesso, "como ele vê"); caminhões (cadastro, confirmar, custo por km, média,
  resultado, quem dirigiu); lançamentos com filtros; correções com motivo e histórico; relatórios PDF
  e CSV (frota, motorista, caminhão, embarcador); configurações (empresa, regras de acerto, categorias,
  gestores, celulares, senha).
  `flutter analyze` sem problemas; `flutter test --exclude-tags capturas` → 20 testes passaram;
  12 imagens de tela (computador, celular e tema escuro) conferidas.
- **feito e testado** — `flutter build web` compilou localmente.
- **feito** — Esteira: job "gestor" gera o APK no Release `gestor-teste` e publica o painel web no ramo
  `gh-pages` (endereço: https://dasilvagonchoroskie-cpu.github.io/plataforma-gestao-frota/).
- **feito e testado** — O resumo "como ele vê" usa o mesmo componente (`CorpoResumo`, pacote `visual`)
  do app do motorista; o teste `equipe_test.dart` confere que a conta do painel é a mesma do app.

## Correção de 17/10/2026 — apps não abriam

- **feito e testado** — Os APKs paravam no logo ao abrir (R8 quebrava o plugin shared_preferences).
  Achado abrindo os APKs num emulador Android 14 na esteira. R8 desligado, tela de erro no lugar de
  travar e job "aparelho" na esteira que instala e abre os dois APKs e falha se algum não abrir.

## Piloto pronto sem e-mail e ícones (17/10/2026)

- **feito e testado** — Cadastro do motorista sem e-mail, acesso de gestor com senha provisória criado
  pelo dono, login do dono criado pela plataforma, troca obrigatória da senha provisória. pgTAP: 156
  verificações; Edge Functions na esteira: 33 verificações de ponta a ponta (incluindo login de verdade
  no Supabase Auth). Motorista: 22 testes; gestor: 22 testes.
- **feito** — Aplicado na nuvem: migration `login_do_dono` (hash conferido) e Edge Functions
  `cadastrar_motorista` e `criar_acesso_gestor`. Login do dono da empresa piloto criado.
- **feito** — Ícones próprios (fontes em `ferramentas/icones/`, gerados por `gerar.py`).

## Contas, termos e controle da plataforma (17/10/2026)

- **feito e testado** — Código individual por motorista (gerado no painel, único, 7 dias, uso único, preso
  ao CPF); código de recuperação (Edge Function `recuperar_acesso`); Termos de Uso e Política de
  Privacidade com aceite registrado; exclusão de dados (empresa, motorista, própria conta); bloqueio,
  prazo de teste e exclusão automática pela plataforma; registros de acesso (6 meses).
  Local: `PGTAP_SQL=... supabase/tests/local/rodar.sh` → `total de verificações que passaram: 222`.
  Esteira (Supabase local, Postgres 17): 222 pgTAP e `verificações: 53, falhas: 0` nas Edge Functions.
  Motorista: `flutter analyze` sem problemas, `flutter test --exclude-tags capturas` → 27 testes passaram.
  Gestor: `flutter analyze` sem problemas, `flutter test --exclude-tags capturas` → 27 testes passaram;
  `flutter build web` compilou (com termos.html e privacidade.html).
- **feito** — Na nuvem: partes 1 a 3 da atualização (estrutura, funções, controle da plataforma), hash
  conferido com os arquivos; Edge Functions `recuperar_acesso` (nova) e `cadastrar_motorista` (grava o aceite).
- **aprovado, falta o segredo** — Parte 4 na nuvem (`20261017213600_contas_termos_exclusao.sql`): aprovada
  pelo Evandro em 22/10/2026 com condições; aplicada sozinha pelo fluxo do banco quando os segredos do
  GitHub existirem (ver "Segurança", abaixo).

## Segurança "nível empresa" (22/10/2026)

Relatório completo (achado, gravidade, correção): `docs/SEGURANCA.md`.

- **feito e testado** — Banco: permissões padrão fechadas para `anon`/PUBLIC, IP verdadeiro, regra de
  senha (8–72, letras e números), registro das ações da plataforma (`auditoria_plataforma`, só inclusão),
  teste 07 de auditoria geral (RLS em tudo, nada para `anon`, nenhuma função para PUBLIC, isolamento entre
  empresas e motoristas em todas as tabelas, empresa bloqueada sem ver nem gravar nada).
  Local: `PGTAP_SQL=... supabase/tests/local/rodar.sh` → `total de verificações que passaram: 274`.
  Esteira (Supabase local, Postgres 17): pgTAP e Edge Functions ponta a ponta (inclui o bloqueio por IP).
- **feito e testado** — Backup criptografado + restauração num Supabase vazio na Esteira:
  `tabelas conferidas: 52, diferenças: 0`. Fluxo diário na nuvem pronto (`banco-nuvem.yml`).
- **feito e publicado na nuvem** — Edge Functions novas (login interno sorteado, IP verdadeiro, bloqueio
  de 30 erros por IP em 15 minutos, senha forte, CORS só do painel, limite de 16 KB, erro técnico escondido). Códigos de entrada de todas as
  empresas trocados (migration `rotacionar_codigos_empresa`).
- **feito e testado** — Apps: regra de senha nova, CPF e e-mail fora do celular, sem backup do Android,
  tráfego só HTTPS, R8 ligado e Dart ofuscado, assinatura derivada da `CHAVE_MESTRA`.
  Motorista: `flutter analyze` sem problemas, `flutter test --exclude-tags capturas` → 28 testes.
  Gestor: `flutter analyze` sem problemas, 27 testes. Núcleo: `dart test` → 39 testes.
  APKs: `conferir_apk.py` → `segredos achados: 0`.
- **feito** — Esteira com ações fixadas por SHA, permissão mínima por job, gitleaks em todo envio (histórico
  limpo: `no leaks found`), conferência de aprovação de migrations, Dependabot; histórico reescrito sem a
  chave de teste e sem o código antigo; textos legais com o operador pessoa física (versão 22/10/2026);
  `docs/INCIDENTES.md`, `docs/EMAIL.md`, `docs/REPOSITORIO-PRIVADO.md`, `SECURITY.md`.
- **depende do usuário** — Criar os segredos `SUPABASE_ACCESS_TOKEN` e `CHAVE_MESTRA` e ligar as proteções
  do GitHub (Settings > Code security). Até lá: sem backup automático, parte 4 e migrations novas não vão
  para a nuvem, APKs novos não são publicados.

## Senha por link no e-mail e termos na primeira abertura (22/10/2026)

Pedido do Evandro: recuperar a senha sem código (link no e-mail) e aceitar os termos logo ao abrir o app.

- **feito e testado** — Edge Function `pedir_link_senha` (publicada na nuvem, versão 1), modelos de e-mail
  com link, gatilho que leva o e-mail confirmado para o perfil, banco recusa troca de e-mail de dono e
  gestor. Local: `supabase/tests/local/rodar.sh` → `total de verificações que passaram: 279`. Esteira
  (Supabase local de verdade, com caixa de e-mail): `verificações: 78, falhas: 0` (o link chega, abre a
  sessão, cria a senha, só vale uma vez; o motorista confirma o e-mail e recupera pelo CPF).
- **feito e testado** — Apps 0.3.0: "Esqueci a senha" pede o link; painel web abre o link do e-mail (senha
  nova ou e-mail confirmado) e encerra as outras sessões; motorista cadastra o e-mail no cadastro ou em
  Configurações; código de recuperação retirado; termos antes de qualquer tela (guardados no aparelho).
  Motorista: `flutter analyze` sem problemas, `flutter test --exclude-tags capturas` → 31 testes. Gestor:
  sem problemas, 32 testes; `flutter build web` compilou. Núcleo: `dart analyze` sem problemas.
- **feito** — Banco da nuvem: partes 4, segurança e termos aplicadas pelo fluxo (histórico conferido no
  registro `banco-nuvem.log`). Backup sem sessões e tokens; restauração mostra a tabela que falhou.
- **feito** — SMTP próprio (Brevo) ligado pelo dono e conferido pelo fluxo do banco ("e-mail próprio
  (SMTP): ligado"). Backup na nuvem com teste de restauração passando: `tabelas conferidas: 45,
  diferenças: 0`.
- **em andamento** — Link do e-mail abria 404: o GitHub Pages nunca tinha sido ligado. Opção A do dono:
  código privado e painel no repositório público `painel-frota` (Esteira pronta; faltam os passos do dono
  em `docs/REPOSITORIO-PRIVADO.md`). Varredura de segredos (histórico atual, commits antigos, registros
  públicos): nenhum segredo válido.

## Área Plataforma (super administrador) — 22/10/2026

Pedido do Evandro: cadastrar e cuidar das empresas pelo app, sem abrir o Supabase.

- **feito e testado** — Banco (migration `area_plataforma`): `admins_plataforma`, ações `plataforma_*`
  (lista, cadastrar empresa com o dono e senha provisória gerada pelo banco, prazo, liberar, bloquear,
  senha nova do dono), conferência do super administrador em cada ação, auditoria `plataforma_app`, senha
  provisória do dono forçada no banco. Local: `supabase/tests/local/rodar.sh` → `total de verificações
  que passaram: 306` (teste 08: 27).
- **feito e testado** — Frota Gestor 0.4.0: botão Plataforma (só para o super administrador), lista das
  empresas, cadastrar empresa, ações por empresa e recado pronto para o dono (WhatsApp). `flutter analyze`
  sem problemas; `flutter test --exclude-tags capturas` → 40 testes.
- **anotado** — Verificação em duas etapas para a área Plataforma (melhoria futura, `docs/PASSAGEM.md`).

## E-mail obrigatório para o motorista — 22/10/2026

- **feito e testado** — Frota Motorista 0.4.0: e-mail obrigatório no cadastro, tela para cadastrar o e-mail
  nas contas antigas (antes de continuar; adiável sem internet), lembrete no Resumo até confirmar ("Mandar
  de novo" e "Já confirmei"). `flutter analyze` sem problemas; `flutter test --exclude-tags capturas` → 34.

## Modalidades de operação — 22 e 23/10/2026 (primeira entrega da esteira)

Pedido do Evandro: Graneleiro, Grade baixa, Caçamba, Baú e Sider; tudo o que existe vira Graneleiro; Baú por
viagem (uma por carreta), acerto com comissão e descontos lançados pelo gestor; campos ajustáveis sem APK novo.

- **feito e testado** — Banco (migration `modalidades`): catálogo, modalidades da empresa (Graneleiro em todas
  as que existem), modalidade do motorista e do código individual, `viagens`, `acertos`, sincronização das
  viagens, campos efetivos na situação da conta, ações do dono, do gestor e da Plataforma, exclusão estendida às
  tabelas novas (a extensão da exclusão espera aprovação, abaixo). Comando: `PGHOST=/tmp PGPORT=54329 PGUSER=postgres PGTAP_SQL=… supabase/tests/local/rodar.sh`
  → `total de verificações que passaram: 369` (teste 09: 63).
- **aprovado e feito em 23/10** — Exclusão de motorista e de empresa apagar também viagens, acertos e
  modalidades (ver "Exclusão completa com o PDF antes").
- **feito e testado** — Núcleo: modelos de modalidade, viagem e acerto, PDF do acerto e das viagens, planilha
  de viagens. `dart analyze` sem problemas; `dart test` → 49 testes.
- **feito e testado** — Frota Motorista 0.5.0: escolha da modalidade, aba Viagens (engatar, anotar entregas,
  desengatar, sem internet), cavalo fixo no Baú, acertos no Resumo e em Configurações, campos do frete conforme
  o dono e campos novos. `flutter analyze` sem problemas; `flutter test --exclude-tags capturas` → 40 testes.
- **feito e testado** — Frota Gestor 0.5.0: Configurações > Modalidades (ligar, campos), cadastro do motorista
  com modalidade, troca de modalidade, abas Viagens e Acertos, fazer e corrigir acerto, lançamentos e planilha de
  viagens, painel com viagens, Plataforma > Modalidades e campos. `flutter analyze` sem problemas;
  `flutter test --exclude-tags capturas` → 45 testes.
- **feito e testado** — Esteira do commit 135bede: todos os trabalhos passaram (núcleo, banco, motorista e
  gestor com APKs oficiais). Banco da nuvem atualizado pela esteira ("Banco - backup diário e atualização na
  nuvem": `resultado: success`, migration `20261022190000 modalidades` no Supabase). Conferido na nuvem: 5
  modalidades no catálogo, a empresa com Graneleiro ligado, o motorista em Graneleiro, nenhum frete fora do
  Graneleiro. APKs 0.5.0 com a assinatura oficial (certificado 9c6ec010…22d2) entregues ao Evandro.

## Registro de paradas — 23/10/2026 (segunda entrega da esteira)

Pedido do Evandro: opcional por empresa (desligado, ninguém vê), motivos, "Registrar parada" e "Retomar
viagem", horário informado depois fica marcado, sem internet, aba no painel por motorista e período com o maior
intervalo sem descanso e destaque acima do limite da empresa (padrão 5h30), só refeição, descanso e pernoite
contam como descanso, relatório com o aviso do tacógrafo, nenhum número da lei no código.

- **feito e testado** — Banco (migration `paradas`): `empresas.paradas_ativas` e
  `limite_sem_descanso_minutos` (só o dono muda), catálogo `motivos_parada`, tabela `paradas` com RLS,
  auditoria e sincronização; motivos e limite na situação da conta. Comando: `PGHOST=/tmp PGPORT=54329
  PGUSER=postgres PGTAP_SQL=… supabase/tests/local/rodar.sh` → `total de verificações que passaram: 393`
  (teste 10: 24). Teste de ponta a ponta (`supabase/tests/funcoes/testar.sh`) ganhou 4 conferências de paradas
  (roda na esteira, com o Supabase local completo).
- **feito e testado** — Núcleo: parada, motivos, configuração, intervalo sem descanso, PDF e planilha com o
  aviso. `dart analyze` sem problemas; `dart test` → 63 testes.
- **feito e testado** — Frota Motorista 0.6.0: aba Paradas só com a empresa ligada, registrar (com "parei
  antes e esqueci"), retomar (com "esqueci de retomar"), corrigir e apagar, cartão no Resumo, sem internet.
  `flutter analyze` sem problemas; `flutter test --exclude-tags capturas` → 48 testes.
- **feito e testado** — Frota Gestor 0.6.0: Configurações > Registro de paradas (dono liga e define o
  limite), seção Paradas no computador e cartão no Painel, aba Paradas na tela do motorista, PDF e planilha.
  Corrigida também uma linha do Painel no celular que passava da tela (placa do caminhão menor no celular).
  `flutter analyze` sem problemas; `flutter test --exclude-tags capturas` → 53 testes.
- **corrigido** — A primeira esteira das paradas (44d01b0) reprovou no teste de ponta a ponta: com a parada
  nova, a exclusão antiga do motorista dava erro (faltava a exclusão completa, que ainda esperava aprovação).
  Os APKs e o painel web 0.6.0 foram publicados mesmo assim, antes do banco da nuvem; o painel ficou sem abrir
  até a correção chegar. Corrigido: a esteira só publica o painel depois de o banco passar, e o painel abre
  mesmo se a nuvem ainda não tiver as tabelas novas (paradas e motivos ficam vazios).

## Exclusão completa com o PDF antes — 23/10/2026

Aprovação do Evandro (23/10, no chat): a exclusão de motorista e de empresa apaga também viagens, acertos,
paradas e as modalidades da empresa, **sempre com o PDF de todos os dados gerado antes**; na exclusão
automática, o painel avisa antes do prazo com o botão do PDF.

- **feito e testado** — Banco (migration `exclusao_completa`, com a linha `aprovado-por`): exclusão estendida e
  `exportar_dados_empresa()` (o dono baixa tudo mesmo com o acesso encerrado). `rodar.sh` →
  `total de verificações que passaram: 412` (teste 11: 19). `conferir_aprovacao.py` → `sem aprovação para
  apagar dados: 0`.
- **feito e testado** — Núcleo: PDF com todos os dados (capa, caminhões, cada motorista com cadastro, relatório
  de todo o histórico, acertos e paradas). `dart test` → 65 testes.
- **feito e testado** — Frota Gestor 0.6.1: excluir motorista e excluir empresa passam antes pelo PDF (sem o
  PDF, não exclui); "Baixar tudo dele (PDF)" no motorista; "Baixar todos os dados da empresa (PDF)" em
  Configurações; avisos no Painel (motorista que pediu para sair e acesso da empresa acabando) com o botão
  "Baixar PDF"; com o acesso encerrado, o dono baixa o PDF na própria tela. `flutter test --exclude-tags
  capturas` → 58 testes.
- **feito e testado** — Esteiras 841ed68 e 5afb26f aprovadas; banco da nuvem atualizado (`resultado: success`,
  migrations `20261023120000 paradas` e `20261023140000 exclusao_completa` no Supabase). Conferido na nuvem:
  10 motivos (descanso = refeição, descanso, pernoite), empresa com paradas desligadas e limite 330, função
  `exportar_dados_empresa` criada e exclusão com paradas. APKs oficiais (certificado 9c6ec010…22d2): Frota
  Motorista 0.6.0 e Frota Gestor 0.6.1, entregues ao Evandro.

## Visual do cartaz — 23/10/2026

Pedido do Evandro (cartaz de propaganda): interface igual ao cartaz. Escolhas dele: cores do cartaz, tela
inicial do motorista com botões grandes e ícones dos apps iguais aos do cartaz.

- **feito e testado** — Tema azul-marinho e verde (escuro por padrão, claro ou igual ao aparelho em
  Configurações > Aparência), ícones coloridos por parte, cartões do painel com ícone e últimos lançamentos.
- **feito e testado** — Frota Motorista 0.7.0: abas Início (botões grandes com a linha do mês), Lançamentos
  (tudo numa lista, com filtro) e Resumo; o caminhão, os avisos, a parada e a carreta em andamento ficam no
  Início. `flutter analyze` sem problemas; `flutter test --exclude-tags capturas` → 48 testes; 15 imagens das
  telas.
- **feito e testado** — Frota Gestor 0.7.0: menu do lado com a marca do app, mesmo tema. `flutter test
  --exclude-tags capturas` → 58 testes; 14 imagens.
- **feito** — Ícones novos dos dois apps e do painel web (`ferramentas/icones/gerar.py`).
- **feito e testado** — Esteira do commit a7952f2 aprovada; APKs oficiais 0.7.0 (certificado 9c6ec010…22d2)
  entregues ao Evandro; painel web publicado com o visual novo.

## Excluir a conta libera o CPF na hora — 23/10/2026

Problema relatado pelo Evandro: depois de excluir a conta de motorista, o CPF continuava "já cadastrado".
Escolha dele: "Liberar o CPF na hora" (vale como aprovação; linha `aprovado-por` na migration).

- **feito e testado** — Banco (migration `20261023180000_excluir_conta_libera_cpf`): o login e o CPF saem na
  hora; o cadastro sem login e os lançamentos ficam 15 dias com a empresa e a limpeza diária apaga depois;
  cadastro sem login não é religado; avisos claros no código, na aprovação e no redefinir acesso; o uso do
  caminhão fica sem o login de quem registrou. `rodar.sh` → `total de verificações que passaram: 422` (teste
  06: 92). `conferir_aprovacao.py` → `sem aprovação para apagar dados: 0`. Teste à parte: quem já tinha pedido
  a exclusão (com caminhão registrado por ele) teve o login apagado na atualização.
- **feito e testado** — Função `cadastrar_motorista`: mensagem nova para CPF que já tem conta (sem citar o
  código de recuperação, que saiu dos apps). Publicada na nuvem (versão 4).
- **feito e testado** — Frota Motorista 0.7.1 (texto da exclusão e recado com a data) → `flutter test
  --exclude-tags capturas` 50 testes; Frota Gestor 0.7.1 (aviso "excluiu a conta", sem religar nem redefinir)
  → 59 testes; `flutter analyze` sem problemas nos dois.
- **feito e testado** — Primeira subida à nuvem (bd58bae) parou sem gravar nada: o motorista tinha registrado
  o próprio caminhão. Corrigido em 4507fb5. Esteira e banco da nuvem aprovados (`success`); conferido na
  nuvem: migration `20261023180000` aplicada, nenhum login preso, CPF do Evandro livre, cadastro antigo sem
  login até 07/11/2026. APKs oficiais 0.7.1 (certificado 9c6ec010…22d2) entregues.

## Fase 7 — acabamento e piloto

- **em andamento** — SMTP próprio (Brevo, configuração no painel do Supabase pelo dono).
- **não feito** — Sentry, teste fechado no Google Play, hospedagem do painel quando o
  repositório voltar a ser privado, piloto com uma empresa real.
