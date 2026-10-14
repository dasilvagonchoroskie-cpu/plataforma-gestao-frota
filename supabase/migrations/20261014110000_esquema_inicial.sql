-- Esquema inicial da Plataforma de Gestão de Frota.
-- Arquivo revisado por leitura; não aplicado nem testado em banco.
-- IDs sem DEFAULT: o cliente de origem precisa fornecer o UUID.
-- Ver docs/PASSAGEM.md para a matriz RLS, exceções e dúvidas registradas.

-- Empresas é a raiz do tenant. O campo empresa_id repete id conforme a regra
-- geral da arquitetura; a FK autorreferente é diferida para permitir o INSERT.
create table public.empresas (
  id uuid primary key,
  empresa_id uuid not null unique,
  nome text not null,
  documento text,
  codigo_entrada text not null unique,
  plano text not null,
  limite_caminhoes integer not null,
  status text not null check (status in ('teste', 'ativa', 'suspensa')),
  criado_em timestamptz not null default pg_catalog.now(),
  atualizado_em timestamptz not null default pg_catalog.now(),
  apagado_em timestamptz,
  constraint empresas_id_empresa_id_iguais check (empresa_id = id),
  constraint empresas_empresa_fk foreign key (empresa_id)
    references public.empresas(id) deferrable initially deferred,
  constraint empresas_empresa_id_id_uk unique (empresa_id, id)
);

create table public.perfis (
  id uuid primary key references auth.users(id),
  empresa_id uuid references public.empresas(empresa_id),
  papel text not null check (papel in ('dono', 'gestor', 'motorista')),
  nome text not null,
  cpf text unique,
  email text not null,
  ativo boolean not null default true,
  criado_em timestamptz not null default pg_catalog.now(),
  atualizado_em timestamptz not null default pg_catalog.now(),
  apagado_em timestamptz,
  constraint perfis_cpf_11_digitos_ck check (cpf is null or cpf ~ '^[0-9]{11}$'),
  constraint perfis_empresa_id_id_uk unique (empresa_id, id)
);

create table public.motoristas (
  id uuid primary key,
  empresa_id uuid not null references public.empresas(empresa_id),
  perfil_id uuid not null unique,
  nome text not null,
  cpf text not null,
  email text not null,
  telefone text,
  ativo boolean not null default true,
  criado_em timestamptz not null default pg_catalog.now(),
  atualizado_em timestamptz not null default pg_catalog.now(),
  apagado_em timestamptz,
  constraint motoristas_cpf_11_digitos_ck check (cpf ~ '^[0-9]{11}$'),
  constraint motoristas_cpf_empresa_unique unique (empresa_id, cpf),
  constraint motoristas_empresa_id_id_uk unique (empresa_id, id),
  constraint motoristas_perfil_empresa_fk foreign key (empresa_id, perfil_id)
    references public.perfis(empresa_id, id)
);

create table public.acessos_autorizados (
  id uuid primary key,
  empresa_id uuid not null references public.empresas(empresa_id),
  email text not null,
  papel text not null check (papel in ('dono', 'gestor')),
  ativo boolean not null default true,
  criado_em timestamptz not null default pg_catalog.now(),
  atualizado_em timestamptz not null default pg_catalog.now(),
  apagado_em timestamptz,
  constraint acessos_autorizados_empresa_id_id_uk unique (empresa_id, id)
);

create table public.dispositivos (
  id uuid primary key,
  empresa_id uuid not null references public.empresas(empresa_id),
  perfil_id uuid not null,
  apelido text not null,
  ultimo_sync_em timestamptz,
  revogado_em timestamptz,
  criado_em timestamptz not null default pg_catalog.now(),
  atualizado_em timestamptz not null default pg_catalog.now(),
  apagado_em timestamptz,
  constraint dispositivos_empresa_id_id_uk unique (empresa_id, id),
  constraint dispositivos_perfil_empresa_fk foreign key (empresa_id, perfil_id)
    references public.perfis(empresa_id, id)
);

create table public.caminhoes (
  id uuid primary key,
  empresa_id uuid not null references public.empresas(empresa_id),
  placa text not null,
  numero_frota text,
  modelo text not null,
  ano integer,
  ativo boolean not null default true,
  confirmado boolean not null default false,
  criado_em timestamptz not null default pg_catalog.now(),
  atualizado_em timestamptz not null default pg_catalog.now(),
  apagado_em timestamptz,
  constraint caminhoes_placa_normalizada_ck check (placa ~ '^[A-Z0-9]{7}$'),
  constraint caminhoes_placa_empresa_unique unique (empresa_id, placa),
  constraint caminhoes_empresa_id_id_uk unique (empresa_id, id)
);

create table public.fretes (
  id uuid primary key,
  empresa_id uuid not null references public.empresas(empresa_id),
  motorista_id uuid not null,
  caminhao_id uuid not null,
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
  criado_em timestamptz not null default pg_catalog.now(),
  atualizado_em timestamptz not null default pg_catalog.now(),
  apagado_em timestamptz,
  constraint fretes_valor_tonelada_nao_negativo_ck check (valor_tonelada_centavos >= 0),
  constraint fretes_adiantamento_nao_negativo_ck check (adiantamento_centavos >= 0),
  constraint fretes_saldo_nao_negativo_ck check (saldo_centavos >= 0),
  constraint fretes_pedagio_nao_negativo_ck check (pedagio_centavos >= 0),
  constraint fretes_desconto_nao_negativo_ck check (desconto_quebra_centavos >= 0),
  constraint fretes_percentual_comissao_ck check (percentual_comissao between 0 and 100),
  constraint fretes_empresa_id_id_uk unique (empresa_id, id),
  constraint fretes_motorista_empresa_fk foreign key (empresa_id, motorista_id)
    references public.motoristas(empresa_id, id),
  constraint fretes_caminhao_empresa_fk foreign key (empresa_id, caminhao_id)
    references public.caminhoes(empresa_id, id)
);

create table public.abastecimentos (
  id uuid primary key,
  empresa_id uuid not null references public.empresas(empresa_id),
  motorista_id uuid not null,
  caminhao_id uuid not null,
  frete_id uuid,
  data timestamptz not null,
  cidade text not null,
  posto text not null,
  litros numeric(12, 2) not null,
  valor_centavos bigint not null,
  km_odometro numeric(14, 2) not null,
  tanque_cheio boolean not null,
  ponto_de_partida boolean not null,
  criado_em timestamptz not null default pg_catalog.now(),
  atualizado_em timestamptz not null default pg_catalog.now(),
  apagado_em timestamptz,
  constraint abastecimentos_valor_nao_negativo_ck check (valor_centavos >= 0),
  constraint abastecimentos_empresa_id_id_uk unique (empresa_id, id),
  constraint abastecimentos_motorista_empresa_fk foreign key (empresa_id, motorista_id)
    references public.motoristas(empresa_id, id),
  constraint abastecimentos_caminhao_empresa_fk foreign key (empresa_id, caminhao_id)
    references public.caminhoes(empresa_id, id),
  constraint abastecimentos_frete_empresa_fk foreign key (empresa_id, frete_id)
    references public.fretes(empresa_id, id)
);

create table public.categorias_gasto (
  id uuid primary key,
  empresa_id uuid not null references public.empresas(empresa_id),
  nome text not null,
  ativa boolean not null default true,
  criado_em timestamptz not null default pg_catalog.now(),
  atualizado_em timestamptz not null default pg_catalog.now(),
  apagado_em timestamptz,
  constraint categorias_gasto_empresa_id_id_uk unique (empresa_id, id)
);

create table public.gastos_viagem (
  id uuid primary key,
  empresa_id uuid not null references public.empresas(empresa_id),
  motorista_id uuid not null,
  caminhao_id uuid not null,
  frete_id uuid,
  data timestamptz not null,
  categoria_id uuid not null,
  valor_centavos bigint not null,
  observacao text,
  criado_em timestamptz not null default pg_catalog.now(),
  atualizado_em timestamptz not null default pg_catalog.now(),
  apagado_em timestamptz,
  constraint gastos_viagem_valor_nao_negativo_ck check (valor_centavos >= 0),
  constraint gastos_viagem_empresa_id_id_uk unique (empresa_id, id),
  constraint gastos_viagem_motorista_empresa_fk foreign key (empresa_id, motorista_id)
    references public.motoristas(empresa_id, id),
  constraint gastos_viagem_caminhao_empresa_fk foreign key (empresa_id, caminhao_id)
    references public.caminhoes(empresa_id, id),
  constraint gastos_viagem_frete_empresa_fk foreign key (empresa_id, frete_id)
    references public.fretes(empresa_id, id),
  constraint gastos_viagem_categoria_empresa_fk foreign key (empresa_id, categoria_id)
    references public.categorias_gasto(empresa_id, id)
);

create table public.vales (
  id uuid primary key,
  empresa_id uuid not null references public.empresas(empresa_id),
  motorista_id uuid not null,
  data timestamptz not null,
  valor_centavos bigint not null,
  observacao text,
  criado_em timestamptz not null default pg_catalog.now(),
  atualizado_em timestamptz not null default pg_catalog.now(),
  apagado_em timestamptz,
  constraint vales_valor_nao_negativo_ck check (valor_centavos >= 0),
  constraint vales_empresa_id_id_uk unique (empresa_id, id),
  constraint vales_motorista_empresa_fk foreign key (empresa_id, motorista_id)
    references public.motoristas(empresa_id, id)
);

create table public.ajustes_km (
  id uuid primary key,
  empresa_id uuid not null references public.empresas(empresa_id),
  caminhao_id uuid not null,
  motorista_id uuid not null,
  quando timestamptz not null,
  km_anterior numeric(14, 2) not null,
  km_novo numeric(14, 2) not null,
  motivo text not null,
  criado_em timestamptz not null default pg_catalog.now(),
  atualizado_em timestamptz not null default pg_catalog.now(),
  apagado_em timestamptz,
  constraint ajustes_km_empresa_id_id_uk unique (empresa_id, id),
  constraint ajustes_km_caminhao_empresa_fk foreign key (empresa_id, caminhao_id)
    references public.caminhoes(empresa_id, id),
  constraint ajustes_km_motorista_empresa_fk foreign key (empresa_id, motorista_id)
    references public.motoristas(empresa_id, id)
);

create table public.ajustes_gestor (
  id uuid primary key,
  empresa_id uuid not null references public.empresas(empresa_id),
  tabela_alvo text not null,
  registro_id uuid not null,
  campo text not null,
  valor_antigo jsonb,
  valor_novo jsonb,
  motivo text not null,
  autor_id uuid not null,
  criado_em timestamptz not null default pg_catalog.now(),
  atualizado_em timestamptz not null default pg_catalog.now(),
  apagado_em timestamptz,
  constraint ajustes_gestor_empresa_id_id_uk unique (empresa_id, id),
  constraint ajustes_gestor_autor_empresa_fk foreign key (empresa_id, autor_id)
    references public.perfis(empresa_id, id)
);

create table public.auditoria (
  id uuid primary key,
  empresa_id uuid not null references public.empresas(empresa_id),
  autor_id uuid,
  acao text not null,
  tabela text not null,
  registro_id uuid not null,
  antes jsonb,
  depois jsonb,
  criado_em timestamptz not null default pg_catalog.now(),
  atualizado_em timestamptz not null default pg_catalog.now(),
  apagado_em timestamptz,
  constraint auditoria_empresa_id_id_uk unique (empresa_id, id),
  constraint auditoria_autor_empresa_fk foreign key (empresa_id, autor_id)
    references public.perfis(empresa_id, id)
);

create table public.pedidos_entrada (
  id uuid primary key,
  empresa_id uuid not null references public.empresas(empresa_id),
  perfil_id uuid not null references public.perfis(id),
  status text not null check (status in ('pendente', 'aprovado', 'recusado')),
  pedido_em timestamptz not null default pg_catalog.now(),
  decidido_por uuid,
  decidido_em timestamptz,
  criado_em timestamptz not null default pg_catalog.now(),
  atualizado_em timestamptz not null default pg_catalog.now(),
  apagado_em timestamptz,
  constraint pedidos_entrada_empresa_id_id_uk unique (empresa_id, id),
  constraint pedidos_entrada_decisor_empresa_fk foreign key (empresa_id, decidido_por)
    references public.perfis(empresa_id, id)
);

create table public.uso_caminhao (
  id uuid primary key,
  empresa_id uuid not null references public.empresas(empresa_id),
  motorista_id uuid not null,
  caminhao_id uuid not null,
  inicio_em timestamptz not null,
  fim_em timestamptz,
  registrado_por uuid not null,
  criado_em timestamptz not null default pg_catalog.now(),
  atualizado_em timestamptz not null default pg_catalog.now(),
  apagado_em timestamptz,
  constraint uso_caminhao_empresa_id_id_uk unique (empresa_id, id),
  constraint uso_caminhao_motorista_empresa_fk foreign key (empresa_id, motorista_id)
    references public.motoristas(empresa_id, id),
  constraint uso_caminhao_caminhao_empresa_fk foreign key (empresa_id, caminhao_id)
    references public.caminhoes(empresa_id, id),
  constraint uso_caminhao_registrado_por_empresa_fk foreign key (empresa_id, registrado_por)
    references public.perfis(empresa_id, id),
  constraint uso_caminhao_intervalo_ck check (fim_em is null or fim_em >= inicio_em)
);

-- Função de trigger: o valor enviado pelo cliente é sempre substituído pelo servidor.
create or replace function public.definir_atualizado_em()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.atualizado_em := pg_catalog.clock_timestamp();
  return new;
end;
$$;

-- A solicitação de entrada pode apontar para perfil sem empresa (aguardando aprovação),
-- mas nunca para perfil já vinculado a outra empresa.
create or replace function public.validar_pedido_entrada_empresa()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Mantém o perfil bloqueado até o fim da transação para impedir que uma
  -- aprovação/vinculação concorrente o associe a outra empresa.
  perform 1
  from public.perfis p
  where p.id = new.perfil_id
    and p.papel = 'motorista'
    and p.ativo
    and p.apagado_em is null
    and (p.empresa_id is null or p.empresa_id = new.empresa_id)
  for key share;
  if not found then
    raise exception 'Perfil do pedido não é motorista disponível para esta empresa'
      using errcode = '23503';
  end if;
  return new;
end;
$$;

-- tabela_alvo é polimórfica: o trigger valida o par empresa_id/registro_id no alvo,
-- impede alterar identidade/tenant e confere valores de dinheiro/percentual/IDs relacionados.
create or replace function public.validar_ajuste_gestor_empresa()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_alvo_existe boolean;
  v_uuid_novo uuid;
begin
  if new.tabela_alvo not in (
    'empresas', 'perfis', 'motoristas', 'acessos_autorizados', 'dispositivos',
    'caminhoes', 'fretes', 'abastecimentos', 'categorias_gasto', 'gastos_viagem',
    'vales', 'ajustes_km', 'auditoria', 'pedidos_entrada', 'uso_caminhao'
  ) then
    raise exception 'Tabela alvo de ajuste não permitida' using errcode = '23514';
  end if;

  if new.campo in ('id', 'empresa_id', 'criado_em', 'atualizado_em', 'apagado_em') then
    raise exception 'Campo de identidade, tenant ou sistema não pode ser ajustado'
      using errcode = '23514';
  end if;

  if not exists (
    select 1 from information_schema.columns c
    where c.table_schema = 'public'
      and c.table_name = new.tabela_alvo
      and c.column_name = new.campo
  ) then
    raise exception 'Campo não existe na tabela alvo' using errcode = '23514';
  end if;

  execute pg_catalog.format(
    'select exists (select 1 from public.%I where empresa_id = $1 and id = $2)',
    new.tabela_alvo
  ) into v_alvo_existe using new.empresa_id, new.registro_id;
  if not v_alvo_existe then
    raise exception 'Registro alvo não pertence à empresa do ajuste'
      using errcode = '23503';
  end if;

  if new.valor_novo is not null and new.campo ~ '_centavos$' then
    if pg_catalog.jsonb_typeof(new.valor_novo) <> 'number'
       or (new.valor_novo #>> '{}')::numeric < 0
       or pg_catalog.trunc((new.valor_novo #>> '{}')::numeric)
          <> (new.valor_novo #>> '{}')::numeric then
      raise exception 'Valor em centavos deve ser inteiro numérico e não negativo'
        using errcode = '23514';
    end if;
  end if;

  if new.valor_novo is not null and new.campo = 'percentual_comissao' then
    if pg_catalog.jsonb_typeof(new.valor_novo) <> 'number'
       or (new.valor_novo #>> '{}')::numeric < 0
       or (new.valor_novo #>> '{}')::numeric > 100 then
      raise exception 'Percentual de comissão deve ficar entre 0 e 100'
        using errcode = '23514';
    end if;
  end if;

  if new.valor_novo is not null
     and new.campo in ('motorista_id', 'caminhao_id', 'frete_id', 'categoria_id', 'perfil_id', 'autor_id', 'decidido_por', 'registrado_por') then
    if pg_catalog.jsonb_typeof(new.valor_novo) = 'null' then
      if exists (
        select 1 from information_schema.columns c
        where c.table_schema = 'public' and c.table_name = new.tabela_alvo
          and c.column_name = new.campo and c.is_nullable = 'NO'
      ) then
        raise exception 'Chave estrangeira obrigatória não pode ser nula' using errcode = '23514';
      end if;
    elsif pg_catalog.jsonb_typeof(new.valor_novo) <> 'string' then
      raise exception 'Chave estrangeira deve ser UUID textual ou nula' using errcode = '23514';
    else
      begin
        v_uuid_novo := (new.valor_novo #>> '{}')::uuid;
      exception when invalid_text_representation then
        raise exception 'Valor de chave estrangeira não é UUID válido' using errcode = '23514';
      end;

      if new.campo = 'motorista_id' and not exists (
        select 1 from public.motoristas m where m.empresa_id = new.empresa_id and m.id = v_uuid_novo
      ) then
        raise exception 'motorista_id do ajuste pertence a outra empresa' using errcode = '23503';
      elsif new.campo = 'caminhao_id' and not exists (
        select 1 from public.caminhoes c where c.empresa_id = new.empresa_id and c.id = v_uuid_novo
      ) then
        raise exception 'caminhao_id do ajuste pertence a outra empresa' using errcode = '23503';
      elsif new.campo = 'frete_id' and not exists (
        select 1 from public.fretes f where f.empresa_id = new.empresa_id and f.id = v_uuid_novo
      ) then
        raise exception 'frete_id do ajuste pertence a outra empresa' using errcode = '23503';
      elsif new.campo = 'categoria_id' and not exists (
        select 1 from public.categorias_gasto c where c.empresa_id = new.empresa_id and c.id = v_uuid_novo
      ) then
        raise exception 'categoria_id do ajuste pertence a outra empresa' using errcode = '23503';
      elsif new.campo in ('perfil_id', 'autor_id', 'decidido_por', 'registrado_por') and not exists (
        select 1 from public.perfis p where p.empresa_id = new.empresa_id and p.id = v_uuid_novo
      ) then
        raise exception 'perfil referenciado pelo ajuste não pertence à empresa' using errcode = '23503';
      end if;
    end if;
  end if;

  return new;
end;
$$;

-- FKs têm índices compostos próprios ou são acompanhadas por índices abaixo.
create index perfis_empresa_idx on public.perfis (empresa_id);
create index empresas_sync_idx on public.empresas (empresa_id, atualizado_em);
create index perfis_sync_idx on public.perfis (empresa_id, atualizado_em);
create index motoristas_empresa_perfil_idx on public.motoristas (empresa_id, perfil_id);
create index motoristas_sync_idx on public.motoristas (empresa_id, atualizado_em);
create index acessos_autorizados_empresa_email_idx on public.acessos_autorizados (empresa_id, email);
create index acessos_autorizados_sync_idx on public.acessos_autorizados (empresa_id, atualizado_em);
create index dispositivos_empresa_perfil_idx on public.dispositivos (empresa_id, perfil_id);
create index dispositivos_sync_idx on public.dispositivos (empresa_id, atualizado_em);
create index caminhoes_sync_idx on public.caminhoes (empresa_id, atualizado_em);
create index fretes_empresa_motorista_data_idx on public.fretes (empresa_id, motorista_id, data_carga);
create index fretes_empresa_caminhao_data_idx on public.fretes (empresa_id, caminhao_id, data_carga);
create index fretes_sync_idx on public.fretes (empresa_id, atualizado_em);
create index abastecimentos_empresa_motorista_data_idx on public.abastecimentos (empresa_id, motorista_id, data);
create index abastecimentos_empresa_caminhao_data_idx on public.abastecimentos (empresa_id, caminhao_id, data);
create index abastecimentos_frete_empresa_idx on public.abastecimentos (empresa_id, frete_id);
create index abastecimentos_sync_idx on public.abastecimentos (empresa_id, atualizado_em);
create index categorias_gasto_sync_idx on public.categorias_gasto (empresa_id, atualizado_em);
create index gastos_viagem_empresa_motorista_data_idx on public.gastos_viagem (empresa_id, motorista_id, data);
create index gastos_viagem_empresa_caminhao_data_idx on public.gastos_viagem (empresa_id, caminhao_id, data);
create index gastos_viagem_frete_empresa_idx on public.gastos_viagem (empresa_id, frete_id);
create index gastos_viagem_categoria_empresa_idx on public.gastos_viagem (empresa_id, categoria_id);
create index gastos_viagem_sync_idx on public.gastos_viagem (empresa_id, atualizado_em);
create index vales_empresa_motorista_data_idx on public.vales (empresa_id, motorista_id, data);
create index vales_sync_idx on public.vales (empresa_id, atualizado_em);
create index ajustes_km_empresa_caminhao_quando_idx on public.ajustes_km (empresa_id, caminhao_id, quando);
create index ajustes_km_motorista_empresa_idx on public.ajustes_km (empresa_id, motorista_id);
create index ajustes_km_sync_idx on public.ajustes_km (empresa_id, atualizado_em);
create index ajustes_gestor_empresa_autor_idx on public.ajustes_gestor (empresa_id, autor_id);
create index ajustes_gestor_empresa_alvo_registro_idx on public.ajustes_gestor (empresa_id, tabela_alvo, registro_id);
create index ajustes_gestor_sync_idx on public.ajustes_gestor (empresa_id, atualizado_em);
create index auditoria_empresa_registro_idx on public.auditoria (empresa_id, tabela, registro_id);
create index auditoria_autor_empresa_idx on public.auditoria (empresa_id, autor_id);
create index auditoria_sync_idx on public.auditoria (empresa_id, atualizado_em);
create index pedidos_entrada_empresa_perfil_idx on public.pedidos_entrada (empresa_id, perfil_id);
create index pedidos_entrada_empresa_decisor_idx on public.pedidos_entrada (empresa_id, decidido_por);
create index pedidos_entrada_empresa_status_idx on public.pedidos_entrada (empresa_id, status);
create index pedidos_entrada_sync_idx on public.pedidos_entrada (empresa_id, atualizado_em);
create index uso_caminhao_empresa_motorista_idx on public.uso_caminhao (empresa_id, motorista_id);
create index uso_caminhao_empresa_caminhao_idx on public.uso_caminhao (empresa_id, caminhao_id);
create index uso_caminhao_empresa_registrado_por_idx on public.uso_caminhao (empresa_id, registrado_por);
create index uso_caminhao_sync_idx on public.uso_caminhao (empresa_id, atualizado_em);
create unique index uso_caminhao_um_aberto_por_motorista_idx
  on public.uso_caminhao (motorista_id) where fim_em is null and apagado_em is null;

-- Helper functions SECURITY DEFINER e search_path vazio: consultam perfis sem
-- reentrar nas políticas RLS da própria tabela. A role dona da tabela é confiável.
create or replace function public.empresa_do_usuario()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select p.empresa_id
  from public.perfis p
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
    select 1 from public.perfis p
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
    select 1 from public.perfis p
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
  from public.motoristas m
  join public.perfis p on p.id = m.perfil_id and p.empresa_id = m.empresa_id
  where p.id = (select auth.uid()) and p.papel = 'motorista'
    and p.ativo and p.apagado_em is null and m.ativo and m.apagado_em is null
  limit 1
$$;

-- Nenhuma função SECURITY DEFINER fica executável por anon/PUBLIC.
revoke all on function public.definir_atualizado_em() from public, anon, authenticated;
revoke all on function public.validar_pedido_entrada_empresa() from public, anon, authenticated;
revoke all on function public.validar_ajuste_gestor_empresa() from public, anon, authenticated;
revoke all on function public.empresa_do_usuario() from public, anon;
revoke all on function public.eh_dono() from public, anon;
revoke all on function public.eh_gestor_ou_dono() from public, anon;
revoke all on function public.motorista_do_usuario() from public, anon;
grant execute on function public.empresa_do_usuario() to authenticated;
grant execute on function public.eh_dono() to authenticated;
grant execute on function public.eh_gestor_ou_dono() to authenticated;
grant execute on function public.motorista_do_usuario() to authenticated;

create trigger empresas_atualizado_em before insert or update on public.empresas
  for each row execute function public.definir_atualizado_em();
create trigger perfis_atualizado_em before insert or update on public.perfis
  for each row execute function public.definir_atualizado_em();
create trigger motoristas_atualizado_em before insert or update on public.motoristas
  for each row execute function public.definir_atualizado_em();
create trigger acessos_autorizados_atualizado_em before insert or update on public.acessos_autorizados
  for each row execute function public.definir_atualizado_em();
create trigger dispositivos_atualizado_em before insert or update on public.dispositivos
  for each row execute function public.definir_atualizado_em();
create trigger caminhoes_atualizado_em before insert or update on public.caminhoes
  for each row execute function public.definir_atualizado_em();
create trigger fretes_atualizado_em before insert or update on public.fretes
  for each row execute function public.definir_atualizado_em();
create trigger abastecimentos_atualizado_em before insert or update on public.abastecimentos
  for each row execute function public.definir_atualizado_em();
create trigger categorias_gasto_atualizado_em before insert or update on public.categorias_gasto
  for each row execute function public.definir_atualizado_em();
create trigger gastos_viagem_atualizado_em before insert or update on public.gastos_viagem
  for each row execute function public.definir_atualizado_em();
create trigger vales_atualizado_em before insert or update on public.vales
  for each row execute function public.definir_atualizado_em();
create trigger ajustes_km_atualizado_em before insert or update on public.ajustes_km
  for each row execute function public.definir_atualizado_em();
create trigger ajustes_gestor_atualizado_em before insert or update on public.ajustes_gestor
  for each row execute function public.definir_atualizado_em();
create trigger auditoria_atualizado_em before insert or update on public.auditoria
  for each row execute function public.definir_atualizado_em();
create trigger pedidos_entrada_atualizado_em before insert or update on public.pedidos_entrada
  for each row execute function public.definir_atualizado_em();
create trigger uso_caminhao_atualizado_em before insert or update on public.uso_caminhao
  for each row execute function public.definir_atualizado_em();

create trigger pedidos_entrada_validar_empresa before insert or update on public.pedidos_entrada
  for each row execute function public.validar_pedido_entrada_empresa();
create trigger ajustes_gestor_validar_empresa before insert or update on public.ajustes_gestor
  for each row execute function public.validar_ajuste_gestor_empresa();

-- RLS habilitado em todas as 16 tabelas.
do $$
declare
  tabela text;
begin
  foreach tabela in array array[
    'empresas', 'perfis', 'motoristas', 'acessos_autorizados', 'dispositivos', 'caminhoes',
    'fretes', 'abastecimentos', 'categorias_gasto', 'gastos_viagem', 'vales', 'ajustes_km',
    'ajustes_gestor', 'auditoria', 'pedidos_entrada', 'uso_caminhao'
  ] loop
    execute pg_catalog.format('alter table public.%I enable row level security', tabela);
  end loop;
end;
$$;

-- EMPRESAS: qualquer perfil ativo só lê a própria empresa; criação/alteração por função segura.
create policy empresas_ler_propria on public.empresas for select to authenticated
  using (empresa_id = (select public.empresa_do_usuario()) and apagado_em is null);

-- PERFIS: o usuário lê o próprio perfil; dono/gestor leem perfis da empresa.
-- Sem INSERT/UPDATE/DELETE direto: papel e empresa_id não podem ser alterados pelo usuário.
create policy perfis_ler_propria_empresa on public.perfis for select to authenticated
  using (id = (select auth.uid()) or
    (empresa_id = (select public.empresa_do_usuario()) and (select public.eh_gestor_ou_dono())));

-- MOTORISTAS: o próprio motorista lê sua linha; dono/gestor leem as linhas da empresa.
-- Dono/gestor podem ativar/desativar; criação por decidir_entrada; sem DELETE.
create policy motoristas_ler_proprios_ou_empresa on public.motoristas for select to authenticated
  using (empresa_id = (select public.empresa_do_usuario()) and
    (perfil_id = (select auth.uid()) or (select public.eh_gestor_ou_dono())));
create policy motoristas_gestor_alterar_ativo on public.motoristas for update to authenticated
  using (empresa_id = (select public.empresa_do_usuario()) and (select public.eh_gestor_ou_dono()))
  with check (empresa_id = (select public.empresa_do_usuario()) and (select public.eh_gestor_ou_dono()));

-- ACESSOS AUTORIZADOS: dono/gestor leem; somente dono insere/edita; sem DELETE físico.
create policy acessos_autorizados_ler_gestao on public.acessos_autorizados for select to authenticated
  using (empresa_id = (select public.empresa_do_usuario()) and (select public.eh_gestor_ou_dono()));
create policy acessos_autorizados_dono_inserir on public.acessos_autorizados for insert to authenticated
  with check (empresa_id = (select public.empresa_do_usuario()) and (select public.eh_dono()));
create policy acessos_autorizados_dono_atualizar on public.acessos_autorizados for update to authenticated
  using (empresa_id = (select public.empresa_do_usuario()) and (select public.eh_dono()))
  with check (empresa_id = (select public.empresa_do_usuario()) and (select public.eh_dono()));

-- DISPOSITIVOS: usuário lê/escreve o próprio dispositivo; dono/gestor leem os da empresa.
create policy dispositivos_ler_proprios_ou_empresa on public.dispositivos for select to authenticated
  using (empresa_id = (select public.empresa_do_usuario()) and
    (perfil_id = (select auth.uid()) or (select public.eh_gestor_ou_dono())));
create policy dispositivos_proprio_inserir on public.dispositivos for insert to authenticated
  with check (empresa_id = (select public.empresa_do_usuario()) and perfil_id = (select auth.uid()));
create policy dispositivos_proprio_atualizar on public.dispositivos for update to authenticated
  using (empresa_id = (select public.empresa_do_usuario()) and perfil_id = (select auth.uid()))
  with check (empresa_id = (select public.empresa_do_usuario()) and perfil_id = (select auth.uid()));

-- CAMINHOES: motorista lê apenas ativos; gestão lê, insere e altera os da empresa.
-- Motorista pode sugerir somente caminhão não confirmado para a própria empresa.
create policy caminhoes_ler_empresa on public.caminhoes for select to authenticated
  using (empresa_id = (select public.empresa_do_usuario()) and
    ((select public.eh_gestor_ou_dono()) or (ativo and apagado_em is null)));
create policy caminhoes_gestao_inserir on public.caminhoes for insert to authenticated
  with check (empresa_id = (select public.empresa_do_usuario()) and (select public.eh_gestor_ou_dono()));
create policy caminhoes_motorista_sugerir on public.caminhoes for insert to authenticated
  with check (empresa_id = (select public.empresa_do_usuario()) and confirmado = false
    and (select public.motorista_do_usuario()) is not null
    and exists (select 1 from public.empresas e where e.empresa_id = caminhoes.empresa_id and e.status <> 'suspensa' and e.apagado_em is null));
create policy caminhoes_gestao_atualizar on public.caminhoes for update to authenticated
  using (empresa_id = (select public.empresa_do_usuario()) and (select public.eh_gestor_ou_dono()))
  with check (empresa_id = (select public.empresa_do_usuario()) and (select public.eh_gestor_ou_dono()));

-- FRETES: motorista lê e insere somente os próprios; gestão lê os da empresa; ninguém altera/apaga.
create policy fretes_ler_proprios_ou_gestao on public.fretes for select to authenticated
  using (empresa_id = (select public.empresa_do_usuario()) and apagado_em is null and
    (motorista_id = (select public.motorista_do_usuario()) or (select public.eh_gestor_ou_dono())));
create policy fretes_motorista_inserir_proprio on public.fretes for insert to authenticated
  with check (empresa_id = (select public.empresa_do_usuario())
    and motorista_id = (select public.motorista_do_usuario())
    and apagado_em is null
    and exists (select 1 from public.empresas e where e.empresa_id = fretes.empresa_id and e.status <> 'suspensa' and e.apagado_em is null));

-- ABASTECIMENTOS: motorista lê/insere os próprios; gestão lê a empresa; sem UPDATE/DELETE.
create policy abastecimentos_ler_proprios_ou_gestao on public.abastecimentos for select to authenticated
  using (empresa_id = (select public.empresa_do_usuario()) and apagado_em is null and
    (motorista_id = (select public.motorista_do_usuario()) or (select public.eh_gestor_ou_dono())));
create policy abastecimentos_motorista_inserir_proprio on public.abastecimentos for insert to authenticated
  with check (empresa_id = (select public.empresa_do_usuario())
    and motorista_id = (select public.motorista_do_usuario())
    and apagado_em is null
    and exists (select 1 from public.empresas e where e.empresa_id = abastecimentos.empresa_id and e.status <> 'suspensa' and e.apagado_em is null));

-- CATEGORIAS DE GASTO: empresa lê ativas; gestão também lê inativas e insere/altera.
create policy categorias_gasto_ler_empresa on public.categorias_gasto for select to authenticated
  using (empresa_id = (select public.empresa_do_usuario()) and
    ((ativa and apagado_em is null) or (select public.eh_gestor_ou_dono())));
create policy categorias_gasto_gestao_inserir on public.categorias_gasto for insert to authenticated
  with check (empresa_id = (select public.empresa_do_usuario()) and (select public.eh_gestor_ou_dono()));
create policy categorias_gasto_gestao_atualizar on public.categorias_gasto for update to authenticated
  using (empresa_id = (select public.empresa_do_usuario()) and (select public.eh_gestor_ou_dono()))
  with check (empresa_id = (select public.empresa_do_usuario()) and (select public.eh_gestor_ou_dono()));

-- GASTOS DE VIAGEM: motorista lê/insere os próprios; gestão lê a empresa; sem UPDATE/DELETE.
create policy gastos_viagem_ler_proprios_ou_gestao on public.gastos_viagem for select to authenticated
  using (empresa_id = (select public.empresa_do_usuario()) and apagado_em is null and
    (motorista_id = (select public.motorista_do_usuario()) or (select public.eh_gestor_ou_dono())));
create policy gastos_viagem_motorista_inserir_proprio on public.gastos_viagem for insert to authenticated
  with check (empresa_id = (select public.empresa_do_usuario())
    and motorista_id = (select public.motorista_do_usuario())
    and apagado_em is null
    and exists (select 1 from public.empresas e where e.empresa_id = gastos_viagem.empresa_id and e.status <> 'suspensa' and e.apagado_em is null));

-- VALES: motorista lê/insere os próprios; gestão lê a empresa; sem UPDATE/DELETE.
create policy vales_ler_proprios_ou_gestao on public.vales for select to authenticated
  using (empresa_id = (select public.empresa_do_usuario()) and apagado_em is null and
    (motorista_id = (select public.motorista_do_usuario()) or (select public.eh_gestor_ou_dono())));
create policy vales_motorista_inserir_proprio on public.vales for insert to authenticated
  with check (empresa_id = (select public.empresa_do_usuario())
    and motorista_id = (select public.motorista_do_usuario())
    and apagado_em is null
    and exists (select 1 from public.empresas e where e.empresa_id = vales.empresa_id and e.status <> 'suspensa' and e.apagado_em is null));

-- AJUSTES KM: motorista lê somente os próprios; gestão lê e insere na empresa.
create policy ajustes_km_ler_proprios_ou_gestao on public.ajustes_km for select to authenticated
  using (empresa_id = (select public.empresa_do_usuario()) and apagado_em is null and
    (motorista_id = (select public.motorista_do_usuario()) or (select public.eh_gestor_ou_dono())));
create policy ajustes_km_motorista_inserir_proprio on public.ajustes_km for insert to authenticated
  with check (empresa_id = (select public.empresa_do_usuario())
    and motorista_id = (select public.motorista_do_usuario()) and apagado_em is null
    and exists (select 1 from public.empresas e where e.empresa_id = ajustes_km.empresa_id and e.status <> 'suspensa' and e.apagado_em is null));
create policy ajustes_km_gestao_inserir on public.ajustes_km for insert to authenticated
  with check (empresa_id = (select public.empresa_do_usuario()) and (select public.eh_gestor_ou_dono()));

-- AJUSTES GESTOR: gestão lê/insere com autoria própria; motorista lê ajustes dos próprios lançamentos.
create policy ajustes_gestor_ler_gestao on public.ajustes_gestor for select to authenticated
  using (empresa_id = (select public.empresa_do_usuario()) and (select public.eh_gestor_ou_dono()));
create policy ajustes_gestor_ler_proprios_motorista on public.ajustes_gestor for select to authenticated
  using (empresa_id = (select public.empresa_do_usuario()) and (
    (tabela_alvo = 'fretes' and exists (select 1 from public.fretes f where f.empresa_id = ajustes_gestor.empresa_id and f.id = ajustes_gestor.registro_id and f.motorista_id = (select public.motorista_do_usuario()))) or
    (tabela_alvo = 'abastecimentos' and exists (select 1 from public.abastecimentos a where a.empresa_id = ajustes_gestor.empresa_id and a.id = ajustes_gestor.registro_id and a.motorista_id = (select public.motorista_do_usuario()))) or
    (tabela_alvo = 'gastos_viagem' and exists (select 1 from public.gastos_viagem g where g.empresa_id = ajustes_gestor.empresa_id and g.id = ajustes_gestor.registro_id and g.motorista_id = (select public.motorista_do_usuario()))) or
    (tabela_alvo = 'vales' and exists (select 1 from public.vales v where v.empresa_id = ajustes_gestor.empresa_id and v.id = ajustes_gestor.registro_id and v.motorista_id = (select public.motorista_do_usuario())))
  ));
create policy ajustes_gestor_gestao_inserir on public.ajustes_gestor for insert to authenticated
  with check (empresa_id = (select public.empresa_do_usuario())
    and autor_id = (select auth.uid()) and (select public.eh_gestor_ou_dono()));

-- AUDITORIA: dono/gestor leem a empresa; gravação somente por servidor/trigger.
create policy auditoria_ler_gestao on public.auditoria for select to authenticated
  using (empresa_id = (select public.empresa_do_usuario()) and (select public.eh_gestor_ou_dono()) and apagado_em is null);

-- PEDIDOS ENTRADA: solicitante lê os próprios pedidos mesmo sem vínculo; gestão lê os da empresa.
-- INSERT/UPDATE/DELETE ficam reservados às funções seguras pedir_entrada/decidir_entrada.
create policy pedidos_entrada_ler_proprios_ou_gestao on public.pedidos_entrada for select to authenticated
  using (perfil_id = (select auth.uid()) or
    (empresa_id = (select public.empresa_do_usuario()) and (select public.eh_gestor_ou_dono())));

-- USO CAMINHAO: motorista lê e abre/fecha uso próprio; gestão lê e registra/fecha na empresa.
create policy uso_caminhao_ler_proprio_ou_gestao on public.uso_caminhao for select to authenticated
  using (empresa_id = (select public.empresa_do_usuario()) and apagado_em is null and
    (motorista_id = (select public.motorista_do_usuario()) or (select public.eh_gestor_ou_dono())));
create policy uso_caminhao_motorista_inserir_proprio on public.uso_caminhao for insert to authenticated
  with check (empresa_id = (select public.empresa_do_usuario())
    and motorista_id = (select public.motorista_do_usuario())
    and registrado_por = (select auth.uid()) and apagado_em is null
    and exists (select 1 from public.empresas e where e.empresa_id = uso_caminhao.empresa_id and e.status <> 'suspensa' and e.apagado_em is null));
create policy uso_caminhao_gestao_inserir on public.uso_caminhao for insert to authenticated
  with check (empresa_id = (select public.empresa_do_usuario())
    and registrado_por = (select auth.uid()) and (select public.eh_gestor_ou_dono()));
create policy uso_caminhao_motorista_fechar_proprio on public.uso_caminhao for update to authenticated
  using (empresa_id = (select public.empresa_do_usuario())
    and motorista_id = (select public.motorista_do_usuario()) and fim_em is null and apagado_em is null)
  with check (empresa_id = (select public.empresa_do_usuario())
    and motorista_id = (select public.motorista_do_usuario()) and fim_em is not null and apagado_em is null);
create policy uso_caminhao_gestao_fechar on public.uso_caminhao for update to authenticated
  using (empresa_id = (select public.empresa_do_usuario())
    and (select public.eh_gestor_ou_dono()) and fim_em is null and apagado_em is null)
  with check (empresa_id = (select public.empresa_do_usuario())
    and (select public.eh_gestor_ou_dono()) and fim_em is not null and apagado_em is null);

-- Privileges are explicit and narrower than RLS. No authenticated role has DELETE.
revoke all on table
  public.empresas, public.perfis, public.motoristas, public.acessos_autorizados,
  public.dispositivos, public.caminhoes, public.fretes, public.abastecimentos,
  public.categorias_gasto, public.gastos_viagem, public.vales, public.ajustes_km,
  public.ajustes_gestor, public.auditoria, public.pedidos_entrada, public.uso_caminhao
  from public, anon, authenticated;

grant usage on schema public to authenticated;
grant select on table
  public.empresas, public.perfis, public.motoristas, public.acessos_autorizados,
  public.dispositivos, public.caminhoes, public.fretes, public.abastecimentos,
  public.categorias_gasto, public.gastos_viagem, public.vales, public.ajustes_km,
  public.ajustes_gestor, public.auditoria, public.pedidos_entrada, public.uso_caminhao
  to authenticated;

grant insert on table
  public.acessos_autorizados, public.dispositivos, public.caminhoes,
  public.fretes, public.abastecimentos, public.categorias_gasto, public.gastos_viagem,
  public.vales, public.ajustes_km, public.ajustes_gestor, public.uso_caminhao
  to authenticated;

grant update (ativo) on table public.motoristas to authenticated;
grant update (email, papel, ativo, apagado_em) on table public.acessos_autorizados to authenticated;
grant update (apelido, ultimo_sync_em, revogado_em, apagado_em) on table public.dispositivos to authenticated;
grant update (placa, numero_frota, modelo, ano, ativo, confirmado, apagado_em) on table public.caminhoes to authenticated;
grant update (nome, ativa, apagado_em) on table public.categorias_gasto to authenticated;
grant update (fim_em) on table public.uso_caminhao to authenticated;

-- Views usam o RLS do chamador, não os privilégios do dono da view.
create view public.fretes_efetivos with (security_invoker = true) as
select f.*, coalesce(e.valores, '{}'::jsonb) as valores_efetivos
from public.fretes f
left join lateral (
  select jsonb_object_agg(orig.key, coalesce(aj.valor_novo, orig.value)) as valores
  from jsonb_each(to_jsonb(f)) as orig(key, value)
  left join lateral (
    select ag.valor_novo from public.ajustes_gestor ag
    where ag.empresa_id = f.empresa_id and ag.tabela_alvo = 'fretes'
      and ag.registro_id = f.id and ag.campo = orig.key and ag.apagado_em is null
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
    where ag.empresa_id = a.empresa_id and ag.tabela_alvo = 'abastecimentos'
      and ag.registro_id = a.id and ag.campo = orig.key and ag.apagado_em is null
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
    where ag.empresa_id = g.empresa_id and ag.tabela_alvo = 'gastos_viagem'
      and ag.registro_id = g.id and ag.campo = orig.key and ag.apagado_em is null
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
    where ag.empresa_id = v.empresa_id and ag.tabela_alvo = 'vales'
      and ag.registro_id = v.id and ag.campo = orig.key and ag.apagado_em is null
    order by ag.criado_em desc, ag.id desc limit 1
  ) aj on true
) e on true;

grant select on public.fretes_efetivos, public.abastecimentos_efetivos,
  public.gastos_viagem_efetivos, public.vales_efetivos to authenticated;
