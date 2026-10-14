# Progresso — Plataforma de Gestão de Frota

Estado do adiantamento do Zapia, sem avançar às fases posteriores. Os rótulos seguem a seção 17 da arquitetura; “testado” significa somente o que foi executado e descrito abaixo.

## Fase 0 — preparação

- **feito mas não testado** — Estrutura separada em `plataforma-frota/`, documentos iniciais, instruções e placeholders para as etapas futuras.
- **feito mas não testado** — Cópia Markdown da arquitetura em `docs/ARQUITETURA.md`; tratada como fonte de verdade nesta etapa.
- **feito mas não testado** — `docs/PROGRESSO.md` e `docs/PASSAGEM.md` criados para continuidade.
- **feito e testado** — Verificação textual com Python confirmou as 17 seções da arquitetura e a presença dos arquivos-base; não verifica conteúdo funcional.

## Fase 1 — arquivos do banco

- **feito mas não testado** — Criado `supabase/migrations/20261014110000_esquema_inicial.sql`, com as 16 tabelas da seção 7, índices, políticas RLS, quatro funções auxiliares da seção 6, gatilhos de `atualizado_em`, quatro views de valores efetivos e privilégios de tabela sem `DELETE`. É apenas um arquivo; não foi aplicado a banco algum.
- **feito e testado** — Verificação textual Python confirmou 16 tabelas, 29 políticas RLS, quatro funções, quatro views e bloqueio de escrita direta nos registros operacionais do motorista e pedidos de entrada. Isso não valida sintaxe, execução, isolamento nem segurança das políticas.
- **não feito** — Aplicação da migration em banco local/de desenvolvimento e testes automatizados de RLS.

## Esqueletos permitidos

- **feito mas não testado** — Esqueletos de código Flutter em `apps/motorista` e `apps/gestor` (`pubspec.yaml` e navegação em `lib/main.dart`) com dados demonstrativos fixos; sem login, nuvem, sincronização ou cálculos. Bootstrap Android/Web ainda não gerado.
- **feito mas não testado** — `packages/nucleo` contém estrutura e 16 classes simples correspondentes às entidades; sem regras de cálculo.
- **feito e testado** — Verificação textual Python confirmou as duas cascas de navegação e a contagem de 16 classes simples. Não é análise nem compilação Flutter/Dart.

## Ambiente e verificações

- **feito e testado** — Comandos de disponibilidade executados: `flutter`, `dart`, `supabase`, `psql` e `git` não estão disponíveis neste ambiente.
- **feito e testado** — Executada verificação textual Python indicada em `docs/PASSAGEM.md`; resultado OK, com as limitações registradas.
- **não feito** — `flutter analyze`, testes Flutter/Dart, validação da migration com Supabase CLI/PostgreSQL e testes de RLS, pois as ferramentas necessárias não estão disponíveis.
- **não feito** — Criação ou envio de repositório GitHub; destino e nome não foram definidos.

## Próxima etapa

- **não feito** — Claude Code deve revisar a migration e os esqueletos, esclarecer as perguntas em `docs/PASSAGEM.md`, executar testes em Supabase de desenvolvimento e só então decidir alterações. O banco de produção não deve ser tocado.
