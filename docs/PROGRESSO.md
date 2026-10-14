# Progresso — Plataforma de Gestão de Frota

Estado do adiantamento do Zapia, sem avançar às fases posteriores. Os rótulos seguem a seção 17 da arquitetura; “testado” significa somente o que foi executado e descrito abaixo.

## Fase 0 — preparação

- **feito mas não testado** — Estrutura separada em `plataforma-frota/`, documentos iniciais, instruções e placeholders para as etapas futuras.
- **feito mas não testado** — Cópia Markdown da arquitetura em `docs/ARQUITETURA.md`; tratada como fonte de verdade nesta etapa.
- **feito mas não testado** — `docs/PROGRESSO.md` e `docs/PASSAGEM.md` para continuidade.
- **feito e testado** — Verificação textual com Python confirmou as 17 seções da arquitetura e a presença dos arquivos-base; não verifica conteúdo funcional.

## Fase 1 — arquivos do banco

- **feito mas não testado** — Revisada em lugar a migration existente `supabase/migrations/20261014110000_esquema_inicial.sql`; sem nova migration e sem aplicação em banco. Alterações e motivos estão em `docs/PASSAGEM.md`.
- **feito mas não testado** — Escrito `supabase/tests/isolamento_rls.sql` com quatro verificações de isolamento e privilégios; depende de pgTAP, variáveis `psql` e fixtures de teste. **Não foi executado.**
- **não feito** — Validação sintática ou execução da migration em banco local/de desenvolvimento.
- **não feito** — Execução dos testes RLS/pgTAP e verificação de comportamento de triggers, FKs e views.
- **não feito** — Acesso ou alteração a qualquer banco; nenhum banco foi acessado ou alterado neste trabalho.

## Esqueletos permitidos

- **feito mas não testado** — Esqueletos de código Flutter em `apps/motorista` e `apps/gestor` (`pubspec.yaml` e navegação em `lib/main.dart`) com dados demonstrativos fixos; sem login, nuvem, sincronização ou cálculos. Bootstrap Android/Web ainda não gerado.
- **feito mas não testado** — `packages/nucleo` contém estrutura e 16 classes simples correspondentes às entidades; sem regras de cálculo.
- **feito e testado** — Verificação textual Python confirmou as duas cascas de navegação e a contagem de 16 classes simples. Não é análise nem compilação Flutter/Dart.

## Ambiente e verificações

- **feito e testado** — Comandos de disponibilidade executados: `flutter`, `dart`, `supabase`, `psql` e `git` não estão disponíveis neste ambiente.
- **feito e testado** — Verificações textuais anteriores confirmaram contagens de tabelas, políticas, funções e views; isso não valida sintaxe, execução, isolamento ou segurança das políticas.
- **não feito** — `flutter analyze`, testes Flutter/Dart, validação da migration com Supabase CLI/PostgreSQL e testes de RLS, pois as ferramentas necessárias não estão disponíveis.
- **feito e testado** — Repositório privado existente: [plataforma-gestao-frota](https://github.com/dasilvagonchoroskie-cpu/plataforma-gestao-frota), branch `main`.

## Próxima etapa

- **não feito** — Claude Code deve rever as dúvidas registradas em `docs/PASSAGEM.md`, executar validação e testes em Supabase local/de desenvolvimento isolado e só então decidir novas alterações. O banco de produção não deve ser tocado.
