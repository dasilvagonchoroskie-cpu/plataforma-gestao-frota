-- Contas, termos e controle da plataforma (parte 1 de 3): colunas e tabelas novas.
-- Pedido do usuário em 17/10/2026; explicação completa na parte 2 (funções).

-- ------------------------------------------------------------- colunas novas

alter table public.empresas
  add column if not exists acesso_ate timestamptz,
  add column if not exists bloqueada_em timestamptz,
  add column if not exists motivo_bloqueio text
    check (motivo_bloqueio is null or length(motivo_bloqueio) <= 200),
  add column if not exists excluir_em timestamptz,
  add column if not exists excluida_em timestamptz;

alter table public.perfis
  add column if not exists exclusao_pedida_em timestamptz;

-- ------------------------------------------------------------- tabelas novas

-- Código individual que o gestor gera ao cadastrar um motorista.
create table if not exists public.convites_motorista (
  id uuid primary key default pg_catalog.gen_random_uuid(),
  empresa_id uuid not null references public.empresas(empresa_id),
  codigo text not null unique check (codigo ~ '^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{6}$'),
  nome text not null check (length(btrim(nome)) between 2 and 120),
  cpf text not null check (cpf ~ '^[0-9]{11}$'),
  criado_por uuid,
  expira_em timestamptz not null,
  usado_por uuid,
  usado_em timestamptz,
  cancelado_em timestamptz,
  criado_em timestamptz not null default pg_catalog.now(),
  atualizado_em timestamptz not null default pg_catalog.now(),
  apagado_em timestamptz,
  constraint convites_motorista_empresa_id_id_uk unique (empresa_id, id)
);
create index if not exists convites_motorista_empresa_idx on public.convites_motorista (empresa_id, criado_em);
create index if not exists convites_motorista_cpf_idx on public.convites_motorista (empresa_id, cpf);
create index if not exists convites_motorista_usado_por_idx on public.convites_motorista (usado_por);

-- Código de recuperação (só o resumo cifrado; o código aparece uma vez).
create table if not exists public.codigos_recuperacao (
  perfil_id uuid primary key references public.perfis(id) on delete cascade,
  hash text not null,
  criado_em timestamptz not null default pg_catalog.now()
);

-- Aceite dos Termos de Uso e da Política de Privacidade.
create table if not exists public.aceites_termos (
  id uuid primary key default pg_catalog.gen_random_uuid(),
  perfil_id uuid not null references public.perfis(id) on delete cascade,
  versao text not null check (versao ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'),
  ip text,
  aceito_em timestamptz not null default pg_catalog.now(),
  constraint aceites_termos_perfil_versao_uk unique (perfil_id, versao)
);

-- Registros de acesso (Marco Civil, art. 15). Sem chave estrangeira de
-- propósito: ficam guardados 6 meses mesmo depois de a conta ser excluída.
create table if not exists public.registros_acesso (
  id bigint generated always as identity primary key,
  perfil_id uuid not null,
  empresa_id uuid,
  app text not null check (app in ('motorista', 'gestor', 'web')),
  ip text,
  quando timestamptz not null default pg_catalog.now()
);
create index if not exists registros_acesso_perfil_idx on public.registros_acesso (perfil_id, quando);
create index if not exists registros_acesso_quando_idx on public.registros_acesso (quando);

create trigger convites_motorista_atualizado_em before insert or update on public.convites_motorista
  for each row execute function public.definir_atualizado_em();

alter table public.convites_motorista enable row level security;
alter table public.codigos_recuperacao enable row level security;
alter table public.aceites_termos enable row level security;
alter table public.registros_acesso enable row level security;

-- Convites: só a gestão da própria empresa lê. Criar e cancelar só pelas funções.
create policy convites_motorista_ler_gestao on public.convites_motorista for select to authenticated
  using (empresa_id = (select public.empresa_do_usuario()) and (select public.eh_gestor_ou_dono()));
-- Aceites: cada um lê os próprios. Códigos e registros: só o servidor.
create policy aceites_termos_ler_proprios on public.aceites_termos for select to authenticated
  using (perfil_id = (select auth.uid()));

revoke all on table public.convites_motorista, public.codigos_recuperacao, public.aceites_termos,
  public.registros_acesso from public, anon, authenticated;
grant select on table public.convites_motorista, public.aceites_termos to authenticated;
