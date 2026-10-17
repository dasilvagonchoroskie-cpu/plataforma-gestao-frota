# Plataforma de Gestão de Frota

Nome do produto provisório. Projeto separado do app Meu Frete e da plataforma de gás e água.

Empresas de transporte acompanham os fretes, abastecimentos, gastos e vales que os motoristas lançam no
celular (funciona sem internet). O dono e o gestor veem tudo no painel, aprovam motoristas, corrigem
lançamentos com motivo e tiram relatórios em PDF e planilha.

- `apps/motorista` — app do motorista (Android, Flutter, offline).
- `apps/gestor` — app de celular e painel web do dono e do gestor (Flutter).
- `packages/nucleo` — regras de cálculo, modelos, PDF e CSV (Dart puro).
- `packages/visual` — tema e componentes de tela comuns.
- `supabase/` — migrations, Edge Functions e testes do banco.
- `docs/` — arquitetura, progresso, passagem (decisões e pendências) e operação.

Situação atual em [`docs/PROGRESSO.md`](docs/PROGRESSO.md); decisões e pendências em
[`docs/PASSAGEM.md`](docs/PASSAGEM.md); arquitetura em [`docs/ARQUITETURA.md`](docs/ARQUITETURA.md).
