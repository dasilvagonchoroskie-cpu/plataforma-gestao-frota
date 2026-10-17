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
  gestaodefrota2027@gmail.com, código CODIGO-TROCADO.

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

## Fase 7 — acabamento e piloto

- **não feito** — SMTP próprio, Sentry, chave de assinatura definitiva, teste fechado no Google Play,
  hospedagem do painel quando o repositório voltar a ser privado, piloto com uma empresa real.
