-- Estrutura inicial da Plataforma de frota.
-- Somente arquivo de migration: NÃO aplicar sem revisão e ambiente de desenvolvimento.
-- Ver docs/PASSAGEM.md para pressupostos e questões ainda abertas.

create extension if not exists pgcrypto;

create or replace function public.definir_atualizado_em()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.atualizado_em := pg_catalog.now();
  return new;
end;
$$;

create table public.empresas (
  id uuid primary key default gen_random_uuid(),
  empresa_id uuid not null unique,
  nome text not null,
  documento text,
  codigo_entrada text not null unique,
  plano text not null,
  limite_caminhoes integer not null,
  status text not null check (status in ('teste', 'ativa', 'suspensa')),
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  apagado_em timestamptz,
  constraint empresas_id_empresa_id_iguais check (empresa_id = id),
  constraint empresas_empresa_fk foreign key (empresa_id) references public.empresas(id) deferrable initially deferred
);

create table public.perfis (
  id uuid primary key references auth.users(id),
  empresa_id uuid references public.empresas(empresa_id),
  papel text not null check (papel in ('dono', 'gestor', 'motorista')),
  nome text not null,
  cpf text unique,
  email text not null,
  ativo boolean not null default true,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  apagado_em timestamptz
);

create table public.motoristas (
  id uuid primary key default gen_random_uuid(),
  empresa_id uuid not null references public.empresas(empresa_id),
  perfil_id uuid not null unique references public.perfis(id),
  nome text not null,
  cpf text not null,
  email text not null,
  telefone text,
  ativo boolean not null default true,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  apagado_em timestamptz,
  constraint motoristas_cpf_empresa_unique unique (empresa_id, cpf)
);

create table public.acessos_autorizados (
  id uuid primary key default gen_random_uuid(),
  empresa_id uuid not null references public.empresas(empresa_id),
  email text not null,
  papel text not null check (papel in ('dono', 'gestor')),
  ativo boolean not null default true,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  apagado_em timestamptz
);

create table public.dispositivos (
  id uuid primary key default gen_random_uuid(),
  empresa_id uuid not null references public.empresas(empresa_id),
  perfil_id uuid not null references public.perfis(id),
  apelido text not null,
  ultimo_sync_em timestamptz,
  revogado_em timestamptz,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  apagado_em timestamptz
);

create table public.caminhoes (
  id uuid primary key default gen_random_uuid(),
  empresa_id uuid not null references public.empresas(empresa_id),
  placa text not null,
  numero_frota text,
  modelo text not null,
  ano integer,
  ativo boolean not null default true,
  confirmado boolean not null default false,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  apagado_em timestamptz,
  constraint caminhoes_placa_empresa_unique unique (empresa_id, placa)
);

create table public.fretes (
  id uuid primary key default gen_random_uuid(),
  empresa_id uuid not null references public.empresas(empresa_id),
  motorista_id uuid not null references public.motoristas(id),
  caminhao_id uuid not null references public.caminhoes(id),
  origem text not null,
  destino text not null,
  embarcador text not null,
  data_carga timestamptz not null,
  peso_carga_kg numeric(12, 2) not null,
  valor_tonelada_centavos bigint not null,
  adiantamento_centavos bigint not null,
  saldo_centavos bigint not null,
  percentual_comissao numeric(7, 4) not null,
  comissao_sobre_bruto boolean not null,
  pedagio_centavos bigint not null,
  peso_descarga_kg numeric(12, 2) not null,
  desconto_quebra_centavos bigint not null,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  apagado_em timestamptz
);

create table public.abastecimentos (
  id uuid primary key default gen_random_uuid(),
  empresa_id uuid not null references public.empresas(empresa_id),
  motorista_id uuid not null references public.motoristas(id),
  caminhao_id uuid not null references public.caminhoes(id),
  frete_id uuid references public.fretes(id),
  data timestamptz not null,
  cidade text not null,
  posto text not null,
  litros numeric(12, 2) not null,
  valor_centavos bigint not null,
  km_odometro numeric(14, 2) not null,
  tanque_cheio boolean not null,
  ponto_de_partida boolean not null,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  apagado_em timestamptz
);

create table public.categorias_gasto (
  id uuid primary key default gen_random_uuid(),
  empresa_id uuid not null references public.empresas(empresa_id),
  nome text not null,
  ativa boolean not null default true,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  apagado_em timestamptz
);

create table public.gastos_viagem (
  id uuid primary key default gen_random_uuid(),
  empresa_id uuid not null references public.empresas(empresa_id),
  motorista_id uuid not null references public.motoristas(id),
  caminhao_id uuid not null references public.caminhoes(id),
  frete_id uuid references public.fretes(id),
  data timestamptz not null,
  categoria_id uuid not null references public.categorias_gasto(id),
  valor_centavos bigint not null,
  observacao text,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  apagado_em timestamptz
);

create table public.vales (
  id uuid primary key default gen_random_uuid(),
  empresa_id uuid not null references public.empresas(empresa_id),
  motorista_id uuid not null references public.motoristas(id),
  data timestamptz not null,
  valor_centavos bigint not null,
  observacao text,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  apagado_em timestamptz
);

create table public.ajustes_km (
  id uuid primary key default gen_random_uuid(),
  empresa_id uuid not null references public.empresas(empresa_id),
  caminhao_id uuid not null references public.caminhoes(id),
  motorista_id uuid not null references public.motoristas(id),
  quando timestamptz not null,
  km_anterior numeric(14, 2) not null,
  km_novo numeric(14, 2) not null,
  motivo text not null,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  apagado_em timestamptz
);

create table public.ajustes_gestor (
  id uuid primary key default gen_random_uuid(),
  empresa_id uuid not null references public.empresas(empresa_id),
  tabela_alvo text not null,
  registro_id uuid not null,
  campo text not null,
  valor_antigo jsonb,
  valor_novo jsonb,
  motivo text not null,
  autor_id uuid not null references auth.users(id),
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  apagado_em timestamptz
);

create table public.auditoria (
  id uuid primary key default gen_random_uuid(),
  empresa_id uuid not null references public.empresas(empresa_id),
  autor_id uuid references auth.users(id),
  acao text not null,
  tabela text not null,
  registro_id uuid not null,
  antes jsonb,
  depois jsonb,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  apagado_em timestamptz
);

create table public.pedidos_entrada (
  id uuid primary key default gen_random_uuid(),
  empresa_id uuid not null references public.empresas(empresa_id),
  perfil_id uuid not null references public.perfis(id),
  status text not null check (status in ('pendente', 'aprovado', 'recusado')),
  pedido_em timestamptz not null default now(),
  decidido_por uuid references auth.users(id),
  decidido_em timestamptz,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  apagado_em timestamptz
);

create table public.uso_caminhao (
  id uuid primary key default gen_random_uuid(),
  empresa_id uuid not null references public.empresas(empresa_id),
  motorista_id uuid not null references public.motoristas(id),
  caminhao_id uuid not null references public.caminhoes(id),
  inicio_em timestamptz not null,
  fim_em timestamptz,
  registrado_por uuid not null references auth.users(id),
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  apagado_em timestamptz
);

-- Índices de relacionamento/consulta; restrições únicas declaradas nas tabelas.
create index perfis_empresa_idx on public.perfis (empresa_id);
create index motoristas_empresa_idx on public.motoristas (empresa_id);
create index acessos_autorizados_empresa_email_idx on public.acessos_autorizados (empresa_id, email);
create index dispositivos_empresa_perfil_idx on public.dispositivos (empresa_id, perfil_id);
create index caminhoes_empresa_idx on public.caminhoes (empresa_id);
create index fretes_empresa_motorista_data_idx on public.fretes (empresa_id, motorista_id, data_carga);
create index fretes_empresa_caminhao_data_idx on public.fretes (empresa_id, caminhao_id, data_carga);
create index abastecimentos_empresa_motorista_data_idx on public.abastecimentos (empresa_id, motorista_id, data);
create index abastecimentos_empresa_caminhao_data_idx on public.abastecimentos (empresa_id, caminhao_id, data);
create index abastecimentos_frete_idx on public.abastecimentos (frete_id);
create index categorias_gasto_empresa_idx on public.categorias_gasto (empresa_id);
create index gastos_viagem_empresa_motorista_data_idx on public.gastos_viagem (empresa_id, motorista_id, data);
create index gastos_viagem_empresa_caminhao_data_idx on public.gastos_viagem (empresa_id, caminhao_id, data);
create index gastos_viagem_frete_idx on public.gastos_viagem (frete_id);
create index gastos_viagem_categoria_idx on public.gastos_viagem (categoria_id);
create index vales_empresa_motorista_data_idx on public.vales (empresa_id, motorista_id, data);
create index ajustes_km_empresa_caminhao_quando_idx on public.ajustes_km (empresa_id, caminhao_id, quando);
create index ajustes_gestor_empresa_alvo_registro_idx on public.ajustes_gestor (empresa_id, tabela_alvo, registro_id);
create index auditoria_empresa_registro_idx on public.auditoria (empresa_id, tabela, registro_id);
create index pedidos_entrada_empresa_status_idx on public.pedidos_entrada (empresa_id, status);
create index uso_caminhao_empresa_motorista_idx on public.uso_caminhao (empresa_id, motorista_id);
create unique index uso_caminhao_um_aberto_por_motorista_idx
  on public.uso_caminhao (empresa_id, motorista_id) where fim_em is null and apagado_em is null;

-- Funções auxiliares de identidade/empresa usadas pelas políticas RLS.
create or replace function public.empresa_do_usuario()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select p.empresa_id
  from public.perfis as p
  where p.id = (select auth.uid()) and p.ativo and p.apagado_em is null
  limit 1
$$;

create or replace function public.eh_dono()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.perfis as p
    where p.id = (select auth.uid()) and p.papel = 'dono'
      and p.ativo and p.apagado_em is null and p.empresa_id is not null
  )
$$;

create or replace function public.eh_gestor_ou_dono()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.perfis as p
    where p.id = (select auth.uid()) and p.papel in ('gestor', 'dono')
      and p.ativo and p.apagado_em is null and p.empresa_id is not null
  )
$$;

create or replace function public.motorista_do_usuario()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select m.id
  from public.motoristas as m
  join public.perfis as p on p.id = m.perfil_id
  where p.id = (select auth.uid()) and p.papel = 'motorista'
    and p.ativo and p.apagado_em is null and m.ativo and m.apagado_em is null
  limit 1
$$;

revoke all on function public.definir_atualizado_em() from public, anon, authenticated;
revoke all on function public.empresa_do_usuario() from public, anon;
revoke all on function public.eh_dono() from public, anon;
revoke all on function public.eh_gestor_ou_dono() from public, anon;
revoke all on function public.motorista_do_usuario() from public, anon;
grant execute on function public.empresa_do_usuario() to authenticated;
grant execute on function public.eh_dono() to authenticated;
grant execute on function public.eh_gestor_ou_dono() to authenticated;
grant execute on function public.motorista_do_usuario() to authenticated;

-- Preenchimento server-side de atualizado_em em toda alteração.
do $$
declare
  tabela text;
begin
  foreach tabela in array array[
    'empresas', 'perfis', 'motoristas', 'acessos_autorizados', 'dispositivos', 'caminhoes',
    'fretes', 'abastecimentos', 'categorias_gasto', 'gastos_viagem', 'vales', 'ajustes_km',
    'ajustes_gestor', 'auditoria', 'pedidos_entrada', 'uso_caminhao'
  ] loop
    execute format('create trigger definir_atualizado_em before update on public.%I for each row execute function public.definir_atualizado_em()', tabela);
  end loop;
end;
$$;

-- RLS habilitado em todas as tabelas. Nenhuma política permite DELETE físico.
do $$
declare
  tabela text;
begin
  foreach tabela in array array[
    'empresas', 'perfis', 'motoristas', 'acessos_autorizados', 'dispositivos', 'caminhoes',
    'fretes', 'abastecimentos', 'categorias_gasto', 'gastos_viagem', 'vales', 'ajustes_km',
    'ajustes_gestor', 'auditoria', 'pedidos_entrada', 'uso_caminhao'
  ] loop
    execute format('alter table public.%I enable row level security', tabela);
  end loop;
end;
$$;

create policy empresas_ler_propria on public.empresas for select to authenticated
  using (empresa_id = (select public.empresa_do_usuario()) and apagado_em is null);
-- Escrita de empresa fica reservada à futura função segura criar_empresa.

create policy perfis_ler_propria_empresa on public.perfis for select to authenticated
  using (id = (select auth.uid()) or (empresa_id = (select public.empresa_do_usuario()) and (select public.eh_gestor_ou_dono())));

create policy motoristas_ler_proprios_ou_empresa on public.motoristas for select to authenticated
  using (empresa_id = (select public.empresa_do_usuario()) and
    (perfil_id = (select auth.uid()) or (select public.eh_gestor_ou_dono())));
-- Criação/vínculo do motorista fica reservado à futura função decidir_entrada.

create policy acessos_autorizados_dono_ler on public.acessos_autorizados for select to authenticated
  using (empresa_id = (select public.empresa_do_usuario()) and (select public.eh_dono()));
create policy acessos_autorizados_dono_inserir on public.acessos_autorizados for insert to authenticated
  with check (empresa_id = (select public.empresa_do_usuario()) and (select public.eh_dono()));
create policy acessos_autorizados_dono_atualizar on public.acessos_autorizados for update to authenticated
  using (empresa_id = (select public.empresa_do_usuario()) and (select public.eh_dono()))
  with check (empresa_id = (select public.empresa_do_usuario()) and (select public.eh_dono()));

create policy dispositivos_ler_proprios_ou_empresa on public.dispositivos for select to authenticated
  using (empresa_id = (select public.empresa_do_usuario()) and
    (perfil_id = (select auth.uid()) or (select public.eh_gestor_ou_dono())));
create policy dispositivos_proprio_inserir on public.dispositivos for insert to authenticated
  with check (empresa_id = (select public.empresa_do_usuario()) and perfil_id = (select auth.uid()));
create policy dispositivos_proprio_atualizar on public.dispositivos for update to authenticated
  using (empresa_id = (select public.empresa_do_usuario()) and perfil_id = (select auth.uid()))
  with check (empresa_id = (select public.empresa_do_usuario()) and perfil_id = (select auth.uid()));

create policy caminhoes_ler_empresa on public.caminhoes for select to authenticated
  using (empresa_id = (select public.empresa_do_usuario()) and
    ((select public.eh_gestor_ou_dono()) or ativo));
create policy caminhoes_gestor_inserir on public.caminhoes for insert to authenticated
  with check (empresa_id = (select public.empresa_do_usuario()) and (select public.eh_gestor_ou_dono()));
-- Caminhão informado pelo motorista deve chegar pela futura função sincronizar_lote,
-- que validará placa, empresa e motorista antes de gravar.
create policy caminhoes_gestor_atualizar on public.caminhoes for update to authenticated
  using (empresa_id = (select public.empresa_do_usuario()) and (select public.eh_gestor_ou_dono()))
  with check (empresa_id = (select public.empresa_do_usuario()) and (select public.eh_gestor_ou_dono()));

-- Lançamentos originais: motorista lê/cria os próprios; gestores/dono apenas leem.
create policy fretes_ler on public.fretes for select to authenticated
  using (empresa_id = (select public.empresa_do_usuario()) and
    (motorista_id = (select public.motorista_do_usuario()) or (select public.eh_gestor_ou_dono())));
-- Escrita de lançamentos pelo motorista deve passar pela futura função sincronizar_lote,
-- que valida perfil, empresa e relações entre os ids antes de gravar.

create policy abastecimentos_ler on public.abastecimentos for select to authenticated
  using (empresa_id = (select public.empresa_do_usuario()) and
    (motorista_id = (select public.motorista_do_usuario()) or (select public.eh_gestor_ou_dono())));

create policy categorias_gasto_ler on public.categorias_gasto for select to authenticated
  using (empresa_id = (select public.empresa_do_usuario()) and (ativa or (select public.eh_gestor_ou_dono())));
create policy categorias_gasto_gestor_inserir on public.categorias_gasto for insert to authenticated
  with check (empresa_id = (select public.empresa_do_usuario()) and (select public.eh_gestor_ou_dono()));
create policy categorias_gasto_gestor_atualizar on public.categorias_gasto for update to authenticated
  using (empresa_id = (select public.empresa_do_usuario()) and (select public.eh_gestor_ou_dono()))
  with check (empresa_id = (select public.empresa_do_usuario()) and (select public.eh_gestor_ou_dono()));

create policy gastos_viagem_ler on public.gastos_viagem for select to authenticated
  using (empresa_id = (select public.empresa_do_usuario()) and
    (motorista_id = (select public.motorista_do_usuario()) or (select public.eh_gestor_ou_dono())));

create policy vales_ler on public.vales for select to authenticated
  using (empresa_id = (select public.empresa_do_usuario()) and
    (motorista_id = (select public.motorista_do_usuario()) or (select public.eh_gestor_ou_dono())));

create policy ajustes_km_gestor_ler on public.ajustes_km for select to authenticated
  using (empresa_id = (select public.empresa_do_usuario()) and (select public.eh_gestor_ou_dono()));
create policy ajustes_km_gestor_inserir on public.ajustes_km for insert to authenticated
  with check (empresa_id = (select public.empresa_do_usuario()) and (select public.eh_gestor_ou_dono()));

create policy ajustes_gestor_ler on public.ajustes_gestor for select to authenticated
  using (empresa_id = (select public.empresa_do_usuario()) and (select public.eh_gestor_ou_dono()));
create policy ajustes_gestor_inserir on public.ajustes_gestor for insert to authenticated
  with check (empresa_id = (select public.empresa_do_usuario()) and autor_id = (select auth.uid()) and (select public.eh_gestor_ou_dono()));
create policy ajustes_gestor_motorista_ler_proprios on public.ajustes_gestor for select to authenticated
  using (empresa_id = (select public.empresa_do_usuario()) and (
    (tabela_alvo = 'fretes' and exists (select 1 from public.fretes f where f.id = ajustes_gestor.registro_id and f.motorista_id = (select public.motorista_do_usuario()))) or
    (tabela_alvo = 'abastecimentos' and exists (select 1 from public.abastecimentos a where a.id = ajustes_gestor.registro_id and a.motorista_id = (select public.motorista_do_usuario()))) or
    (tabela_alvo = 'gastos_viagem' and exists (select 1 from public.gastos_viagem g where g.id = ajustes_gestor.registro_id and g.motorista_id = (select public.motorista_do_usuario()))) or
    (tabela_alvo = 'vales' and exists (select 1 from public.vales v where v.id = ajustes_gestor.registro_id and v.motorista_id = (select public.motorista_do_usuario())))
  ));

create policy auditoria_gestor_ler on public.auditoria for select to authenticated
  using (empresa_id = (select public.empresa_do_usuario()) and (select public.eh_gestor_ou_dono()));

create policy pedidos_entrada_ler on public.pedidos_entrada for select to authenticated
  using (empresa_id = (select public.empresa_do_usuario()) and
    (perfil_id = (select auth.uid()) or (select public.eh_gestor_ou_dono())));
-- Entrada e decisão ficam reservadas às futuras funções seguras pedir_entrada e decidir_entrada.
-- Não permitir escrita direta evita pedido sem validação ou aprovação sem vínculo do perfil.

create policy uso_caminhao_ler on public.uso_caminhao for select to authenticated
  using (empresa_id = (select public.empresa_do_usuario()) and
    (motorista_id = (select public.motorista_do_usuario()) or (select public.eh_gestor_ou_dono())));
create policy uso_caminhao_gestor_inserir on public.uso_caminhao for insert to authenticated
  with check (empresa_id = (select public.empresa_do_usuario()) and
    (select public.eh_gestor_ou_dono()) and registrado_por = (select auth.uid()));
-- Troca iniciada pelo motorista chega pela futura função sincronizar_lote.
create policy uso_caminhao_gestor_atualizar on public.uso_caminhao for update to authenticated
  using (empresa_id = (select public.empresa_do_usuario()) and (select public.eh_gestor_ou_dono()))
  with check (empresa_id = (select public.empresa_do_usuario()) and (select public.eh_gestor_ou_dono()));

-- Views de leitura efetiva com o valor mais recente ajustado por campo.
create view public.fretes_efetivos with (security_invoker = true) as
select f.*, coalesce(e.valores, '{}'::jsonb) as valores_efetivos
from public.fretes f
left join lateral (
  select jsonb_object_agg(orig.key, coalesce(aj.valor_novo, orig.value)) as valores
  from jsonb_each(to_jsonb(f)) as orig(key, value)
  left join lateral (
    select ag.valor_novo from public.ajustes_gestor ag
    where ag.empresa_id = f.empresa_id and ag.tabela_alvo = 'fretes' and ag.registro_id = f.id
      and ag.campo = orig.key and ag.apagado_em is null
    order by ag.criado_em desc, ag.id desc limit 1
  ) aj on true
) e on true;

create view public.abastecimentos_efetivos with (security_invoker = true) as
select a.*, coalesce(e.valores, '{}'::jsonb) as valores_efetivos
from public.abastecimentos a
left join lateral (
  select jsonb_object_agg(orig.key, coalesce(aj.valor_novo, orig.value)) as valores
  from jsonb_each(to_jsonb(a)) as orig(key, value)
  left join lateral (
    select ag.valor_novo from public.ajustes_gestor ag
    where ag.empresa_id = a.empresa_id and ag.tabela_alvo = 'abastecimentos' and ag.registro_id = a.id
      and ag.campo = orig.key and ag.apagado_em is null
    order by ag.criado_em desc, ag.id desc limit 1
  ) aj on true
) e on true;

create view public.gastos_viagem_efetivos with (security_invoker = true) as
select g.*, coalesce(e.valores, '{}'::jsonb) as valores_efetivos
from public.gastos_viagem g
left join lateral (
  select jsonb_object_agg(orig.key, coalesce(aj.valor_novo, orig.value)) as valores
  from jsonb_each(to_jsonb(g)) as orig(key, value)
  left join lateral (
    select ag.valor_novo from public.ajustes_gestor ag
    where ag.empresa_id = g.empresa_id and ag.tabela_alvo = 'gastos_viagem' and ag.registro_id = g.id
      and ag.campo = orig.key and ag.apagado_em is null
    order by ag.criado_em desc, ag.id desc limit 1
  ) aj on true
) e on true;

create view public.vales_efetivos with (security_invoker = true) as
select v.*, coalesce(e.valores, '{}'::jsonb) as valores_efetivos
from public.vales v
left join lateral (
  select jsonb_object_agg(orig.key, coalesce(aj.valor_novo, orig.value)) as valores
  from jsonb_each(to_jsonb(v)) as orig(key, value)
  left join lateral (
    select ag.valor_novo from public.ajustes_gestor ag
    where ag.empresa_id = v.empresa_id and ag.tabela_alvo = 'vales' and ag.registro_id = v.id
      and ag.campo = orig.key and ag.apagado_em is null
    order by ag.criado_em desc, ag.id desc limit 1
  ) aj on true
) e on true;

grant select on public.fretes_efetivos, public.abastecimentos_efetivos,
  public.gastos_viagem_efetivos, public.vales_efetivos to authenticated;

-- Privilégios de tabela não substituem RLS. Sem DELETE físico; cada operação
-- continua limitada pelas políticas acima. Escritas protegidas por função não
-- têm política direta quando o fluxo ainda não está definido.
grant usage on schema public to authenticated;
grant select, insert, update on table
  public.empresas, public.perfis, public.motoristas, public.acessos_autorizados,
  public.dispositivos, public.caminhoes, public.fretes, public.abastecimentos,
  public.categorias_gasto, public.gastos_viagem, public.vales, public.ajustes_km,
  public.ajustes_gestor, public.auditoria, public.pedidos_entrada, public.uso_caminhao
  to authenticated;

