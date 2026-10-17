# Testes do banco

Testes pgTAP das migrations: isolamento entre empresas e perfis (RLS),
cadastro e entrada na empresa, sincronização offline, ajustes, auditoria,
limite do plano e bloqueio do login por CPF.

- `01_isolamento_e_acesso.sql`, `02_sincronizacao.sql`, `03_ajustes_auditoria_login.sql`
- `apoio/fixtures.psql`: duas empresas, donos, gestor, três motoristas e uma conta sem vínculo
- `local/rodar.sh`: roda tudo do zero num PostgreSQL comum (simulando o Supabase) ou num Supabase local

Cada arquivo roda numa transação que termina em ROLLBACK. Nunca rodar em produção.
