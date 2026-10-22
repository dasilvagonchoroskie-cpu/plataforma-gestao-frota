# Progresso — Plataforma de Gestão de Frota

Atualizado em 17/10/2026 pelo Claude Code. "Testado" quer dizer que o comando
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
- **depende do usuário** — SMTP próprio (Brevo) no painel do Supabase, para o link chegar a qualquer
  e-mail (`docs/EMAIL.md`).

## Fase 7 — acabamento e piloto

- **em andamento** — SMTP próprio (Brevo, configuração no painel do Supabase pelo dono).
- **não feito** — Sentry, teste fechado no Google Play, hospedagem do painel quando o
  repositório voltar a ser privado, piloto com uma empresa real.
