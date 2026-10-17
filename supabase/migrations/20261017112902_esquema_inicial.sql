-- Esquema inicial da Plataforma de Gestão de Frota.
-- Revisado e testado pelo Claude Code em 17/10/2026 (ver docs/PASSAGEM.md).
--
-- Regras gerais:
-- * IDs uuid sem DEFAULT nas tabelas que nascem no celular (o app gera o id).
-- * empresa_id em tudo; chaves compostas (empresa_id, id) impedem que um
--   registro de uma empresa aponte para outra, mesmo se uma política falhar.
-- * Dinheiro em centavos (bigint), pesos em kg com 2 casas, datas em UTC.
-- * atualizado_em é sempre do servidor; nada é apagado de verdade (apagado_em).
-- * O motorista não grava direto nas tabelas: tudo passa por
--   sincronizar_lote (migration seguinte). Dono e gestor gravam direto só o
--   que as políticas abaixo permitem.

-- ---------------------------------------------------------------- tabelas

-- Empresas é a raiz do tenant. empresa_id repete id (regra geral).
create table public.empresas (
  id uuid primary key,
  empresa_id uuid not null unique,
  nome text not null check (length(btrim(nome)) between 1 and 120),
  documento text check (documento is null or length(documento) <= 20),
  codigo_entrada text not null unique
    check (codigo_entrada ~ '^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{6}$'),
  plano text not null default 'piloto',
  limite_caminhoes integer not null default 5 check (limite_caminhoes >= 0),
  status text not null default 'teste' check (status in ('teste', 'ativa', 'suspensa')),
  -- Como a empresa acerta com o motorista (mesmas perguntas do Meu Frete).
  percentual_comissao_padrao numeric(7, 4) not null default 13
    check (percentual_comissao_padrao between 0 and 100),
  comissao_sobre_bruto_padrao boolean not null default false,
  gastos_descontam_do_liquido boolean not null default false,
  vale_desconta_do_liquido boolean not null default true,
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
  nome text not null check (length(btrim(nome)) between 1 and 120),
  cpf text unique,
  email text not null,
  ativo boolean not null default true,
  criado_em timestamptz not null default pg_catalog.now(),
  atualizado_em timestamptz not null default pg_catalog.now(),
  apagado_em timestamptz,
  constraint perfis_cpf_11_digitos_ck check (cpf is null or cpf ~ '^[0-9]{11}$'),
  constraint perfis_motorista_tem_cpf_ck check (papel <> 'motorista' or cpf is not null),
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
  email text not null check (email = lower(btrim(email)) and email like '%_@_%'),
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
  numero_frota text check (numero_frota is null or length(numero_frota) <= 20),
  modelo text not null default '' check (length(modelo) <= 60),
  ano integer check (ano is null or ano between 1950 and 2100),
  ativo boolean not null default true,
  confirmado boolean not null default false,
  criado_em timestamptz not null default pg_catalog.now(),
  atualizado_em timestamptz not null default pg_catalog.now(),
  apagado_em timestamptz,
  -- Placa brasileira normalizada (maiúscula, sem hífen): ABC1234 ou ABC1D23.
  constraint caminhoes_placa_normalizada_ck check (placa ~ '^[A-Z]{3}[0-9][A-Z0-9][0-9]{2}$'),
  constraint caminhoes_placa_empresa_unique unique (empresa_id, placa),
  constraint caminhoes_empresa_id_id_uk unique (empresa_id, id)
);

create table public.fretes (
  id uuid primary key,
  empresa_id uuid not null references public.empresas(empresa_id),
  motorista_id uuid not null,
  caminhao_id uuid not null,
  origem text not null check (length(origem) <= 120),
  destino text not null check (length(destino) <= 120),
  embarcador text not null default '' check (length(embarcador) <= 120),
  data_carga timestamptz not null,
  peso_carga_kg numeric(12, 2) not null default 0 check (peso_carga_kg >= 0),
  valor_tonelada_centavos bigint not null default 0,
  adiantamento_centavos bigint not null default 0,
  saldo_centavos bigint not null default 0,
  percentual_comissao numeric(7, 4) not null,
  comissao_sobre_bruto boolean not null,
  pedagio_centavos bigint not null default 0,
  peso_descarga_kg numeric(12, 2) not null default 0 check (peso_descarga_kg >= 0),
  desconto_quebra_centavos bigint not null default 0,
  criado_no_aparelho_em timestamptz,
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
  cidade text not null default '' check (length(cidade) <= 120),
  posto text not null default '' check (length(posto) <= 120),
  litros numeric(12, 2) not null default 0 check (litros >= 0),
  valor_centavos bigint not null default 0,
  km_odometro numeric(14, 2) not null check (km_odometro >= 0),
  tanque_cheio boolean not null default true,
  ponto_de_partida boolean not null default false,
  criado_no_aparelho_em timestamptz,
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
  nome text not null check (length(btrim(nome)) between 1 and 60),
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
  observacao text check (observacao is null or length(observacao) <= 300),
  criado_no_aparelho_em timestamptz,
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
  observacao text check (observacao is null or length(observacao) <= 300),
  criado_no_aparelho_em timestamptz,
  criado_em timestamptz not null default pg_catalog.now(),
  atualizado_em timestamptz not null default pg_catalog.now(),
  apagado_em timestamptz,
  constraint vales_valor_nao_negativo_ck check (valor_centavos >= 0),
  constraint vales_empresa_id_id_uk unique (empresa_id, id),
  constraint vales_motorista_empresa_fk foreign key (empresa_id, motorista_id)
    references public.motoristas(empresa_id, id)
);

-- Histórico das mudanças do km inicial (ponto de partida) de um caminhão.
create table public.ajustes_km (
  id uuid primary key,
  empresa_id uuid not null references public.empresas(empresa_id),
  caminhao_id uuid not null,
  motorista_id uuid not null,
  quando timestamptz not null,
  km_anterior numeric(14, 2) not null,
  km_novo numeric(14, 2) not null,
  motivo text not null check (length(motivo) <= 300),
  criado_em timestamptz not null default pg_catalog.now(),
  atualizado_em timestamptz not null default pg_catalog.now(),
  apagado_em timestamptz,
  constraint ajustes_km_empresa_id_id_uk unique (empresa_id, id),
  constraint ajustes_km_caminhao_empresa_fk foreign key (empresa_id, caminhao_id)
    references public.caminhoes(empresa_id, id),
  constraint ajustes_km_motorista_empresa_fk foreign key (empresa_id, motorista_id)
    references public.motoristas(empresa_id, id)
);

-- Correções do gestor, sempre à parte do lançamento original.
create table public.ajustes_gestor (
  id uuid primary key,
  empresa_id uuid not null references public.empresas(empresa_id),
  tabela_alvo text not null
    check (tabela_alvo in ('fretes', 'abastecimentos', 'gastos_viagem', 'vales')),
  registro_id uuid not null,
  campo text not null,
  valor_antigo jsonb,
  valor_novo jsonb not null,
  motivo text not null check (length(btrim(motivo)) between 3 and 300),
  autor_id uuid not null,
  criado_em timestamptz not null default pg_catalog.now(),
  atualizado_em timestamptz not null default pg_catalog.now(),
  apagado_em timestamptz,
  constraint ajustes_gestor_empresa_id_id_uk unique (empresa_id, id),
  constraint ajustes_gestor_autor_empresa_fk foreign key (empresa_id, autor_id)
    references public.perfis(empresa_id, id)
);

create table public.auditoria (
  id uuid primary key default pg_catalog.gen_random_uuid(),
  empresa_id uuid not null references public.empresas(empresa_id),
  autor_id uuid references public.perfis(id),
  acao text not null,
  tabela text not null,
  registro_id uuid not null,
  antes jsonb,
  depois jsonb,
  criado_em timestamptz not null default pg_catalog.now(),
  atualizado_em timestamptz not null default pg_catalog.now(),
  apagado_em timestamptz,
  constraint auditoria_empresa_id_id_uk unique (empresa_id, id)
);

create table public.pedidos_entrada (
  id uuid primary key default pg_catalog.gen_random_uuid(),
  empresa_id uuid not null references public.empresas(empresa_id),
  perfil_id uuid not null references public.perfis(id),
  status text not null default 'pendente' check (status in ('pendente', 'aprovado', 'recusado')),
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

-- Tentativas de login por CPF e de código de empresa (limite contra abuso).
-- Só o servidor lê e grava (RLS ligado e nenhuma política).
create table public.tentativas_acesso (
  id uuid primary key default pg_catalog.gen_random_uuid(),
  tipo text not null check (tipo in ('login_cpf', 'codigo_empresa')),
  chave text not null,
  sucesso boolean not null,
  criado_em timestamptz not null default pg_catalog.now()
);

-- ---------------------------------------------------------------- índices

create index perfis_empresa_idx on public.perfis (empresa_id);
create index perfis_email_idx on public.perfis (lower(email));
create index empresas_sync_idx on public.empresas (empresa_id, atualizado_em);
create index perfis_sync_idx on public.perfis (empresa_id, atualizado_em);
create index motoristas_empresa_perfil_idx on public.motoristas (empresa_id, perfil_id);
create index motoristas_sync_idx on public.motoristas (empresa_id, atualizado_em);
create unique index acessos_autorizados_email_unico_idx
  on public.acessos_autorizados (empresa_id, email) where apagado_em is null;
create index acessos_autorizados_email_idx on public.acessos_autorizados (email);
create index acessos_autorizados_sync_idx on public.acessos_autorizados (empresa_id, atualizado_em);
create index dispositivos_empresa_perfil_idx on public.dispositivos (empresa_id, perfil_id);
create index dispositivos_sync_idx on public.dispositivos (empresa_id, atualizado_em);
create index caminhoes_sync_idx on public.caminhoes (empresa_id, atualizado_em);
create index fretes_empresa_motorista_data_idx on public.fretes (empresa_id, motorista_id, data_carga);
create index fretes_empresa_caminhao_data_idx on public.fretes (empresa_id, caminhao_id, data_carga);
create index fretes_empresa_data_idx on public.fretes (empresa_id, data_carga);
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
create index ajustes_gestor_empresa_alvo_registro_idx
  on public.ajustes_gestor (empresa_id, tabela_alvo, registro_id, campo, criado_em);
create index ajustes_gestor_sync_idx on public.ajustes_gestor (empresa_id, atualizado_em);
create index auditoria_empresa_registro_idx on public.auditoria (empresa_id, tabela, registro_id);
create index auditoria_autor_idx on public.auditoria (autor_id);
create index auditoria_empresa_criado_idx on public.auditoria (empresa_id, criado_em);
create index pedidos_entrada_empresa_perfil_idx on public.pedidos_entrada (empresa_id, perfil_id);
create index pedidos_entrada_perfil_idx on public.pedidos_entrada (perfil_id);
create index pedidos_entrada_empresa_decisor_idx on public.pedidos_entrada (empresa_id, decidido_por);
create index pedidos_entrada_empresa_status_idx on public.pedidos_entrada (empresa_id, status);
create unique index pedidos_entrada_um_pendente_idx
  on public.pedidos_entrada (perfil_id, empresa_id) where status = 'pendente';
create index uso_caminhao_empresa_motorista_idx on public.uso_caminhao (empresa_id, motorista_id, inicio_em);
create index uso_caminhao_empresa_caminhao_idx on public.uso_caminhao (empresa_id, caminhao_id);
create index uso_caminhao_empresa_registrado_por_idx on public.uso_caminhao (empresa_id, registrado_por);
create index uso_caminhao_sync_idx on public.uso_caminhao (empresa_id, atualizado_em);
create unique index uso_caminhao_um_aberto_por_motorista_idx
  on public.uso_caminhao (motorista_id) where fim_em is null and apagado_em is null;
create index tentativas_acesso_chave_idx on public.tentativas_acesso (tipo, chave, criado_em);

-- ------------------------------------------------- funções de trigger

-- O valor enviado pelo cliente é sempre substituído pelo relógio do servidor.
create or replace function public.definir_atualizado_em()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.atualizado_em := pg_catalog.clock_timestamp();
  if tg_op = 'INSERT' then
    new.criado_em := pg_catalog.clock_timestamp();
  else
    new.criado_em := old.criado_em;
  end if;
  return new;
end;
$$;

-- O pedido pode apontar para perfil sem empresa (aguardando aprovação),
-- mas nunca para perfil já vinculado a outra empresa.
create or replace function public.validar_pedido_entrada_empresa()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
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

-- Campos que o gestor pode corrigir em cada tabela, com o tipo esperado.
create or replace function public.campo_ajustavel_tipo(p_tabela text, p_campo text)
returns text
language sql
immutable
set search_path = ''
as $$
  select case p_tabela
    when 'fretes' then case p_campo
      when 'origem' then 'texto' when 'destino' then 'texto' when 'embarcador' then 'texto'
      when 'data_carga' then 'data'
      when 'peso_carga_kg' then 'numero' when 'peso_descarga_kg' then 'numero'
      when 'valor_tonelada_centavos' then 'centavos' when 'adiantamento_centavos' then 'centavos'
      when 'saldo_centavos' then 'centavos' when 'pedagio_centavos' then 'centavos'
      when 'desconto_quebra_centavos' then 'centavos'
      when 'percentual_comissao' then 'percentual'
      when 'comissao_sobre_bruto' then 'logico'
      when 'caminhao_id' then 'caminhao'
      end
    when 'abastecimentos' then case p_campo
      when 'data' then 'data' when 'cidade' then 'texto' when 'posto' then 'texto'
      when 'litros' then 'numero' when 'km_odometro' then 'numero'
      when 'valor_centavos' then 'centavos'
      when 'tanque_cheio' then 'logico'
      when 'caminhao_id' then 'caminhao'
      end
    when 'gastos_viagem' then case p_campo
      when 'data' then 'data' when 'valor_centavos' then 'centavos'
      when 'observacao' then 'texto'
      when 'categoria_id' then 'categoria' when 'caminhao_id' then 'caminhao'
      end
    when 'vales' then case p_campo
      when 'data' then 'data' when 'valor_centavos' then 'centavos'
      when 'observacao' then 'texto'
      end
  end
$$;

-- Ajuste do gestor: confere alvo, campo, tipo do valor e autoria, e guarda
-- o valor que estava valendo antes (original ou ajuste anterior).
create or replace function public.validar_ajuste_gestor()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tipo text;
  v_original jsonb;
  v_numero numeric;
  v_uuid uuid;
begin
  if tg_op <> 'INSERT' then
    raise exception 'Ajuste não pode ser alterado; crie um novo ajuste' using errcode = '42501';
  end if;

  v_tipo := public.campo_ajustavel_tipo(new.tabela_alvo, new.campo);
  if v_tipo is null then
    raise exception 'Este campo não pode ser corrigido' using errcode = '23514';
  end if;

  execute pg_catalog.format(
    'select to_jsonb(t) -> %L from public.%I t where t.empresa_id = $1 and t.id = $2 and t.apagado_em is null',
    new.campo, new.tabela_alvo
  ) into v_original using new.empresa_id, new.registro_id;
  if v_original is null then
    raise exception 'Lançamento não encontrado nesta empresa' using errcode = '23503';
  end if;

  if new.valor_novo is null or pg_catalog.jsonb_typeof(new.valor_novo) = 'null' then
    raise exception 'Informe o valor corrigido' using errcode = '23514';
  end if;

  if v_tipo in ('centavos', 'numero', 'percentual') then
    if pg_catalog.jsonb_typeof(new.valor_novo) <> 'number' then
      raise exception 'O valor corrigido precisa ser um número' using errcode = '23514';
    end if;
    v_numero := (new.valor_novo #>> '{}')::numeric;
    if v_numero < 0 then
      raise exception 'O valor corrigido não pode ser negativo' using errcode = '23514';
    end if;
    if v_tipo = 'centavos' and pg_catalog.trunc(v_numero) <> v_numero then
      raise exception 'Valor em centavos precisa ser inteiro' using errcode = '23514';
    end if;
    if v_tipo = 'percentual' and v_numero > 100 then
      raise exception 'A comissão fica entre 0 e 100' using errcode = '23514';
    end if;
  elsif v_tipo = 'logico' then
    if pg_catalog.jsonb_typeof(new.valor_novo) <> 'boolean' then
      raise exception 'O valor corrigido precisa ser sim ou não' using errcode = '23514';
    end if;
  elsif v_tipo = 'texto' then
    if pg_catalog.jsonb_typeof(new.valor_novo) <> 'string'
       or pg_catalog.length(new.valor_novo #>> '{}') > 300 then
      raise exception 'Texto corrigido inválido' using errcode = '23514';
    end if;
  elsif v_tipo = 'data' then
    if pg_catalog.jsonb_typeof(new.valor_novo) <> 'string' then
      raise exception 'Data corrigida inválida' using errcode = '23514';
    end if;
    perform (new.valor_novo #>> '{}')::timestamptz;
  elsif v_tipo in ('caminhao', 'categoria') then
    if pg_catalog.jsonb_typeof(new.valor_novo) <> 'string' then
      raise exception 'Escolha um item da lista' using errcode = '23514';
    end if;
    v_uuid := (new.valor_novo #>> '{}')::uuid;
    if v_tipo = 'caminhao' and not exists (
      select 1 from public.caminhoes c
      where c.empresa_id = new.empresa_id and c.id = v_uuid and c.apagado_em is null
    ) then
      raise exception 'Caminhão não é desta empresa' using errcode = '23503';
    end if;
    if v_tipo = 'categoria' and not exists (
      select 1 from public.categorias_gasto c
      where c.empresa_id = new.empresa_id and c.id = v_uuid and c.apagado_em is null
    ) then
      raise exception 'Categoria não é desta empresa' using errcode = '23503';
    end if;
  end if;

  -- Valor que estava valendo: o último ajuste do mesmo campo ou o original.
  select ag.valor_novo into new.valor_antigo
  from public.ajustes_gestor ag
  where ag.empresa_id = new.empresa_id and ag.tabela_alvo = new.tabela_alvo
    and ag.registro_id = new.registro_id and ag.campo = new.campo and ag.apagado_em is null
  order by ag.criado_em desc, ag.id desc
  limit 1;
  if new.valor_antigo is null then
    new.valor_antigo := v_original;
  end if;
  new.motivo := pg_catalog.btrim(new.motivo);
  return new;
end;
$$;

-- Auditoria automática: quem fez o quê, antes e depois.
create or replace function public.registrar_auditoria()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_antes jsonb;
  v_depois jsonb;
  v_empresa uuid;
  v_id uuid;
  v_autor uuid;
  v_acao text;
begin
  if tg_op = 'DELETE' then
    v_antes := pg_catalog.to_jsonb(old);
  elsif tg_op = 'UPDATE' then
    v_antes := pg_catalog.to_jsonb(old);
    v_depois := pg_catalog.to_jsonb(new);
    if (v_antes - 'atualizado_em') = (v_depois - 'atualizado_em') then
      return new; -- nada mudou de verdade
    end if;
  else
    v_depois := pg_catalog.to_jsonb(new);
  end if;
  v_empresa := coalesce(v_depois ->> 'empresa_id', v_antes ->> 'empresa_id')::uuid;
  v_id := coalesce(v_depois ->> 'id', v_antes ->> 'id')::uuid;
  v_acao := pg_catalog.lower(tg_op);
  if tg_op = 'UPDATE' and v_antes ->> 'apagado_em' is null and v_depois ->> 'apagado_em' is not null then
    v_acao := 'apagar';
  end if;
  select p.id into v_autor from public.perfis p where p.id = (select auth.uid());
  insert into public.auditoria (empresa_id, autor_id, acao, tabela, registro_id, antes, depois)
  values (v_empresa, v_autor, v_acao, tg_table_name, v_id, v_antes, v_depois);
  return coalesce(new, old);
end;
$$;

-- Limite de caminhões confirmados do plano da empresa.
create or replace function public.validar_limite_caminhoes()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_limite integer;
  v_total integer;
begin
  if not (new.confirmado and new.ativo and new.apagado_em is null) then
    return new;
  end if;
  if tg_op = 'UPDATE' and old.confirmado and old.ativo and old.apagado_em is null then
    return new;
  end if;
  select e.limite_caminhoes into v_limite from public.empresas e where e.id = new.empresa_id;
  select count(*) into v_total from public.caminhoes c
  where c.empresa_id = new.empresa_id and c.id <> new.id
    and c.confirmado and c.ativo and c.apagado_em is null;
  if v_total >= v_limite then
    raise exception 'O plano da empresa permite até % caminhões ativos', v_limite
      using errcode = '23514';
  end if;
  return new;
end;
$$;

-- ------------------------------------------------- funções auxiliares (RLS)

-- SECURITY DEFINER e search_path vazio: consultam perfis sem reentrar nas
-- políticas da própria tabela.
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

-- ----------------------------------------------------------------- triggers

do $$
declare
  tabela text;
begin
  foreach tabela in array array[
    'empresas', 'perfis', 'motoristas', 'acessos_autorizados', 'dispositivos', 'caminhoes',
    'fretes', 'abastecimentos', 'categorias_gasto', 'gastos_viagem', 'vales', 'ajustes_km',
    'ajustes_gestor', 'auditoria', 'pedidos_entrada', 'uso_caminhao'
  ] loop
    execute pg_catalog.format(
      'create trigger %I before insert or update on public.%I
         for each row execute function public.definir_atualizado_em()',
      tabela || '_atualizado_em', tabela);
  end loop;

  foreach tabela in array array[
    'empresas', 'motoristas', 'acessos_autorizados', 'caminhoes', 'fretes', 'abastecimentos',
    'categorias_gasto', 'gastos_viagem', 'vales', 'ajustes_km', 'ajustes_gestor',
    'pedidos_entrada', 'uso_caminhao'
  ] loop
    execute pg_catalog.format(
      'create trigger %I after insert or update or delete on public.%I
         for each row execute function public.registrar_auditoria()',
      tabela || '_auditoria', tabela);
  end loop;
end;
$$;

create trigger pedidos_entrada_validar_empresa before insert or update on public.pedidos_entrada
  for each row execute function public.validar_pedido_entrada_empresa();
create trigger ajustes_gestor_validar before insert or update on public.ajustes_gestor
  for each row execute function public.validar_ajuste_gestor();
create trigger caminhoes_validar_limite before insert or update on public.caminhoes
  for each row execute function public.validar_limite_caminhoes();

-- ---------------------------------------------------------------------- RLS

do $$
declare
  tabela text;
begin
  foreach tabela in array array[
    'empresas', 'perfis', 'motoristas', 'acessos_autorizados', 'dispositivos', 'caminhoes',
    'fretes', 'abastecimentos', 'categorias_gasto', 'gastos_viagem', 'vales', 'ajustes_km',
    'ajustes_gestor', 'auditoria', 'pedidos_entrada', 'uso_caminhao', 'tentativas_acesso'
  ] loop
    execute pg_catalog.format('alter table public.%I enable row level security', tabela);
  end loop;
end;
$$;

-- EMPRESAS: membros ativos leem a própria empresa; só o dono altera os dados
-- e as regras de acerto (colunas liberadas no grant).
create policy empresas_ler_propria on public.empresas for select to authenticated
  using (empresa_id = (select public.empresa_do_usuario()) and apagado_em is null);
create policy empresas_dono_atualizar on public.empresas for update to authenticated
  using (empresa_id = (select public.empresa_do_usuario()) and (select public.eh_dono()))
  with check (empresa_id = (select public.empresa_do_usuario()) and (select public.eh_dono()));

-- PERFIS: cada um lê o próprio; dono/gestor leem os da empresa. Sem escrita
-- direta: papel e empresa só mudam pelas funções seguras.
create policy perfis_ler_propria_empresa on public.perfis for select to authenticated
  using (id = (select auth.uid()) or
    (empresa_id = (select public.empresa_do_usuario()) and (select public.eh_gestor_ou_dono())));

-- MOTORISTAS: o próprio lê sua linha; gestão lê e ativa/desativa.
create policy motoristas_ler_proprios_ou_empresa on public.motoristas for select to authenticated
  using (empresa_id = (select public.empresa_do_usuario()) and
    (perfil_id = (select auth.uid()) or (select public.eh_gestor_ou_dono())));
create policy motoristas_gestor_alterar_ativo on public.motoristas for update to authenticated
  using (empresa_id = (select public.empresa_do_usuario()) and (select public.eh_gestor_ou_dono()))
  with check (empresa_id = (select public.empresa_do_usuario()) and (select public.eh_gestor_ou_dono()));

-- ACESSOS AUTORIZADOS: gestão lê; só o dono inclui e altera.
create policy acessos_autorizados_ler_gestao on public.acessos_autorizados for select to authenticated
  using (empresa_id = (select public.empresa_do_usuario()) and (select public.eh_gestor_ou_dono()));
create policy acessos_autorizados_dono_inserir on public.acessos_autorizados for insert to authenticated
  with check (empresa_id = (select public.empresa_do_usuario()) and (select public.eh_dono()));
create policy acessos_autorizados_dono_atualizar on public.acessos_autorizados for update to authenticated
  using (empresa_id = (select public.empresa_do_usuario()) and (select public.eh_dono()))
  with check (empresa_id = (select public.empresa_do_usuario()) and (select public.eh_dono()));

-- DISPOSITIVOS: gestão vê os aparelhos da empresa e pode revogar; cada um vê
-- os próprios. O registro do aparelho é feito por sincronizar_lote.
create policy dispositivos_ler_proprios_ou_empresa on public.dispositivos for select to authenticated
  using (empresa_id = (select public.empresa_do_usuario()) and
    (perfil_id = (select auth.uid()) or (select public.eh_gestor_ou_dono())));
create policy dispositivos_gestao_revogar on public.dispositivos for update to authenticated
  using (empresa_id = (select public.empresa_do_usuario()) and (select public.eh_gestor_ou_dono()))
  with check (empresa_id = (select public.empresa_do_usuario()) and (select public.eh_gestor_ou_dono()));

-- CAMINHOES: motorista lê os ativos; gestão lê, cadastra e altera.
create policy caminhoes_ler_empresa on public.caminhoes for select to authenticated
  using (empresa_id = (select public.empresa_do_usuario()) and apagado_em is null and
    ((select public.eh_gestor_ou_dono()) or ativo));
create policy caminhoes_gestao_inserir on public.caminhoes for insert to authenticated
  with check (empresa_id = (select public.empresa_do_usuario()) and (select public.eh_gestor_ou_dono()));
create policy caminhoes_gestao_atualizar on public.caminhoes for update to authenticated
  using (empresa_id = (select public.empresa_do_usuario()) and (select public.eh_gestor_ou_dono()))
  with check (empresa_id = (select public.empresa_do_usuario()) and (select public.eh_gestor_ou_dono()));

-- LANÇAMENTOS (fretes, abastecimentos, gastos, vales, ajustes de km):
-- motorista lê os próprios; gestão lê os da empresa. Ninguém altera nem apaga
-- direto; o motorista grava por sincronizar_lote e a gestão corrige por ajuste.
create policy fretes_ler_proprios_ou_gestao on public.fretes for select to authenticated
  using (empresa_id = (select public.empresa_do_usuario()) and apagado_em is null and
    (motorista_id = (select public.motorista_do_usuario()) or (select public.eh_gestor_ou_dono())));
create policy abastecimentos_ler_proprios_ou_gestao on public.abastecimentos for select to authenticated
  using (empresa_id = (select public.empresa_do_usuario()) and apagado_em is null and
    (motorista_id = (select public.motorista_do_usuario()) or (select public.eh_gestor_ou_dono())));
create policy gastos_viagem_ler_proprios_ou_gestao on public.gastos_viagem for select to authenticated
  using (empresa_id = (select public.empresa_do_usuario()) and apagado_em is null and
    (motorista_id = (select public.motorista_do_usuario()) or (select public.eh_gestor_ou_dono())));
create policy vales_ler_proprios_ou_gestao on public.vales for select to authenticated
  using (empresa_id = (select public.empresa_do_usuario()) and apagado_em is null and
    (motorista_id = (select public.motorista_do_usuario()) or (select public.eh_gestor_ou_dono())));
create policy ajustes_km_ler_proprios_ou_gestao on public.ajustes_km for select to authenticated
  using (empresa_id = (select public.empresa_do_usuario()) and apagado_em is null and
    (motorista_id = (select public.motorista_do_usuario()) or (select public.eh_gestor_ou_dono())));

-- CATEGORIAS DE GASTO: empresa lê as ativas; gestão lê todas e cadastra/altera.
create policy categorias_gasto_ler_empresa on public.categorias_gasto for select to authenticated
  using (empresa_id = (select public.empresa_do_usuario()) and apagado_em is null and
    (ativa or (select public.eh_gestor_ou_dono())));
create policy categorias_gasto_gestao_inserir on public.categorias_gasto for insert to authenticated
  with check (empresa_id = (select public.empresa_do_usuario()) and (select public.eh_gestor_ou_dono()));
create policy categorias_gasto_gestao_atualizar on public.categorias_gasto for update to authenticated
  using (empresa_id = (select public.empresa_do_usuario()) and (select public.eh_gestor_ou_dono()))
  with check (empresa_id = (select public.empresa_do_usuario()) and (select public.eh_gestor_ou_dono()));

-- AJUSTES DO GESTOR: gestão lê e cria com a própria autoria; o motorista lê
-- os ajustes dos próprios lançamentos.
create policy ajustes_gestor_ler_gestao on public.ajustes_gestor for select to authenticated
  using (empresa_id = (select public.empresa_do_usuario()) and (select public.eh_gestor_ou_dono()));
create policy ajustes_gestor_ler_proprios_motorista on public.ajustes_gestor for select to authenticated
  using (empresa_id = (select public.empresa_do_usuario()) and apagado_em is null and (
    (tabela_alvo = 'fretes' and exists (select 1 from public.fretes f
      where f.empresa_id = ajustes_gestor.empresa_id and f.id = ajustes_gestor.registro_id
        and f.motorista_id = (select public.motorista_do_usuario()))) or
    (tabela_alvo = 'abastecimentos' and exists (select 1 from public.abastecimentos a
      where a.empresa_id = ajustes_gestor.empresa_id and a.id = ajustes_gestor.registro_id
        and a.motorista_id = (select public.motorista_do_usuario()))) or
    (tabela_alvo = 'gastos_viagem' and exists (select 1 from public.gastos_viagem g
      where g.empresa_id = ajustes_gestor.empresa_id and g.id = ajustes_gestor.registro_id
        and g.motorista_id = (select public.motorista_do_usuario()))) or
    (tabela_alvo = 'vales' and exists (select 1 from public.vales v
      where v.empresa_id = ajustes_gestor.empresa_id and v.id = ajustes_gestor.registro_id
        and v.motorista_id = (select public.motorista_do_usuario())))
  ));
create policy ajustes_gestor_gestao_inserir on public.ajustes_gestor for insert to authenticated
  with check (empresa_id = (select public.empresa_do_usuario())
    and autor_id = (select auth.uid()) and (select public.eh_gestor_ou_dono()));

-- AUDITORIA: dono/gestor leem a da empresa; só os triggers gravam.
create policy auditoria_ler_gestao on public.auditoria for select to authenticated
  using (empresa_id = (select public.empresa_do_usuario()) and (select public.eh_gestor_ou_dono())
    and apagado_em is null);

-- PEDIDOS DE ENTRADA: o solicitante lê os próprios mesmo sem vínculo; gestão
-- lê os da empresa. Criação e decisão só por pedir_entrada / decidir_entrada.
create policy pedidos_entrada_ler_proprios_ou_gestao on public.pedidos_entrada for select to authenticated
  using (perfil_id = (select auth.uid()) or
    (empresa_id = (select public.empresa_do_usuario()) and (select public.eh_gestor_ou_dono())));

-- USO DO CAMINHÃO: motorista lê o próprio; gestão lê o da empresa. Troca de
-- caminhão por sincronizar_lote (motorista) ou definir_caminhao_atual (gestão).
create policy uso_caminhao_ler_proprio_ou_gestao on public.uso_caminhao for select to authenticated
  using (empresa_id = (select public.empresa_do_usuario()) and apagado_em is null and
    (motorista_id = (select public.motorista_do_usuario()) or (select public.eh_gestor_ou_dono())));

-- ---------------------------------------------------------------- privilégios

-- Mais estreitos que o RLS. Nenhuma role de cliente apaga linha de verdade.
revoke all on table
  public.empresas, public.perfis, public.motoristas, public.acessos_autorizados,
  public.dispositivos, public.caminhoes, public.fretes, public.abastecimentos,
  public.categorias_gasto, public.gastos_viagem, public.vales, public.ajustes_km,
  public.ajustes_gestor, public.auditoria, public.pedidos_entrada, public.uso_caminhao,
  public.tentativas_acesso
  from public, anon, authenticated;

grant usage on schema public to authenticated;
grant select on table
  public.empresas, public.perfis, public.motoristas, public.acessos_autorizados,
  public.dispositivos, public.caminhoes, public.fretes, public.abastecimentos,
  public.categorias_gasto, public.gastos_viagem, public.vales, public.ajustes_km,
  public.ajustes_gestor, public.auditoria, public.pedidos_entrada, public.uso_caminhao
  to authenticated;

grant insert on table
  public.acessos_autorizados, public.caminhoes, public.categorias_gasto, public.ajustes_gestor
  to authenticated;

grant update (nome, documento, percentual_comissao_padrao, comissao_sobre_bruto_padrao,
  gastos_descontam_do_liquido, vale_desconta_do_liquido) on table public.empresas to authenticated;
grant update (ativo) on table public.motoristas to authenticated;
grant update (email, papel, ativo, apagado_em) on table public.acessos_autorizados to authenticated;
grant update (revogado_em) on table public.dispositivos to authenticated;
grant update (placa, numero_frota, modelo, ano, ativo, confirmado, apagado_em)
  on table public.caminhoes to authenticated;
grant update (nome, ativa, apagado_em) on table public.categorias_gasto to authenticated;

-- Funções de trigger não são chamáveis por clientes.
revoke all on function public.definir_atualizado_em() from public, anon, authenticated;
revoke all on function public.validar_pedido_entrada_empresa() from public, anon, authenticated;
revoke all on function public.validar_ajuste_gestor() from public, anon, authenticated;
revoke all on function public.registrar_auditoria() from public, anon, authenticated;
revoke all on function public.validar_limite_caminhoes() from public, anon, authenticated;
revoke all on function public.campo_ajustavel_tipo(text, text) from public, anon;
revoke all on function public.empresa_do_usuario() from public, anon;
revoke all on function public.eh_dono() from public, anon;
revoke all on function public.eh_gestor_ou_dono() from public, anon;
revoke all on function public.motorista_do_usuario() from public, anon;
grant execute on function public.campo_ajustavel_tipo(text, text) to authenticated;
grant execute on function public.empresa_do_usuario() to authenticated;
grant execute on function public.eh_dono() to authenticated;
grant execute on function public.eh_gestor_ou_dono() to authenticated;
grant execute on function public.motorista_do_usuario() to authenticated;

-- ------------------------------------------------- views de valores efetivos

-- Valor efetivo = original + último ajuste de cada campo. As views usam o RLS
-- de quem consulta (security_invoker). campos_ajustados lista o que mudou.
create view public.fretes_efetivos with (security_invoker = true) as
select
  f.id, f.empresa_id, f.motorista_id,
  coalesce((a.v ->> 'caminhao_id')::uuid, f.caminhao_id) as caminhao_id,
  coalesce(a.v ->> 'origem', f.origem) as origem,
  coalesce(a.v ->> 'destino', f.destino) as destino,
  coalesce(a.v ->> 'embarcador', f.embarcador) as embarcador,
  coalesce((a.v ->> 'data_carga')::timestamptz, f.data_carga) as data_carga,
  coalesce((a.v ->> 'peso_carga_kg')::numeric, f.peso_carga_kg) as peso_carga_kg,
  coalesce((a.v ->> 'valor_tonelada_centavos')::bigint, f.valor_tonelada_centavos) as valor_tonelada_centavos,
  coalesce((a.v ->> 'adiantamento_centavos')::bigint, f.adiantamento_centavos) as adiantamento_centavos,
  coalesce((a.v ->> 'saldo_centavos')::bigint, f.saldo_centavos) as saldo_centavos,
  coalesce((a.v ->> 'percentual_comissao')::numeric, f.percentual_comissao) as percentual_comissao,
  coalesce((a.v ->> 'comissao_sobre_bruto')::boolean, f.comissao_sobre_bruto) as comissao_sobre_bruto,
  coalesce((a.v ->> 'pedagio_centavos')::bigint, f.pedagio_centavos) as pedagio_centavos,
  coalesce((a.v ->> 'peso_descarga_kg')::numeric, f.peso_descarga_kg) as peso_descarga_kg,
  coalesce((a.v ->> 'desconto_quebra_centavos')::bigint, f.desconto_quebra_centavos) as desconto_quebra_centavos,
  coalesce(a.campos, '{}'::text[]) as campos_ajustados,
  f.criado_no_aparelho_em, f.criado_em, f.atualizado_em
from public.fretes f
left join lateral (
  select pg_catalog.jsonb_object_agg(u.campo, u.valor_novo) as v,
         pg_catalog.array_agg(u.campo order by u.campo) as campos
  from (
    select distinct on (ag.campo) ag.campo, ag.valor_novo
    from public.ajustes_gestor ag
    where ag.empresa_id = f.empresa_id and ag.tabela_alvo = 'fretes'
      and ag.registro_id = f.id and ag.apagado_em is null
    order by ag.campo, ag.criado_em desc, ag.id desc
  ) u
) a on true
where f.apagado_em is null;

create view public.abastecimentos_efetivos with (security_invoker = true) as
select
  b.id, b.empresa_id, b.motorista_id,
  coalesce((a.v ->> 'caminhao_id')::uuid, b.caminhao_id) as caminhao_id,
  b.frete_id,
  coalesce((a.v ->> 'data')::timestamptz, b.data) as data,
  coalesce(a.v ->> 'cidade', b.cidade) as cidade,
  coalesce(a.v ->> 'posto', b.posto) as posto,
  coalesce((a.v ->> 'litros')::numeric, b.litros) as litros,
  coalesce((a.v ->> 'valor_centavos')::bigint, b.valor_centavos) as valor_centavos,
  coalesce((a.v ->> 'km_odometro')::numeric, b.km_odometro) as km_odometro,
  coalesce((a.v ->> 'tanque_cheio')::boolean, b.tanque_cheio) as tanque_cheio,
  b.ponto_de_partida,
  coalesce(a.campos, '{}'::text[]) as campos_ajustados,
  b.criado_no_aparelho_em, b.criado_em, b.atualizado_em
from public.abastecimentos b
left join lateral (
  select pg_catalog.jsonb_object_agg(u.campo, u.valor_novo) as v,
         pg_catalog.array_agg(u.campo order by u.campo) as campos
  from (
    select distinct on (ag.campo) ag.campo, ag.valor_novo
    from public.ajustes_gestor ag
    where ag.empresa_id = b.empresa_id and ag.tabela_alvo = 'abastecimentos'
      and ag.registro_id = b.id and ag.apagado_em is null
    order by ag.campo, ag.criado_em desc, ag.id desc
  ) u
) a on true
where b.apagado_em is null;

create view public.gastos_viagem_efetivos with (security_invoker = true) as
select
  g.id, g.empresa_id, g.motorista_id,
  coalesce((a.v ->> 'caminhao_id')::uuid, g.caminhao_id) as caminhao_id,
  g.frete_id,
  coalesce((a.v ->> 'data')::timestamptz, g.data) as data,
  coalesce((a.v ->> 'categoria_id')::uuid, g.categoria_id) as categoria_id,
  coalesce((a.v ->> 'valor_centavos')::bigint, g.valor_centavos) as valor_centavos,
  coalesce(a.v ->> 'observacao', g.observacao) as observacao,
  coalesce(a.campos, '{}'::text[]) as campos_ajustados,
  g.criado_no_aparelho_em, g.criado_em, g.atualizado_em
from public.gastos_viagem g
left join lateral (
  select pg_catalog.jsonb_object_agg(u.campo, u.valor_novo) as v,
         pg_catalog.array_agg(u.campo order by u.campo) as campos
  from (
    select distinct on (ag.campo) ag.campo, ag.valor_novo
    from public.ajustes_gestor ag
    where ag.empresa_id = g.empresa_id and ag.tabela_alvo = 'gastos_viagem'
      and ag.registro_id = g.id and ag.apagado_em is null
    order by ag.campo, ag.criado_em desc, ag.id desc
  ) u
) a on true
where g.apagado_em is null;

create view public.vales_efetivos with (security_invoker = true) as
select
  v.id, v.empresa_id, v.motorista_id,
  coalesce((a.v ->> 'data')::timestamptz, v.data) as data,
  coalesce((a.v ->> 'valor_centavos')::bigint, v.valor_centavos) as valor_centavos,
  coalesce(a.v ->> 'observacao', v.observacao) as observacao,
  coalesce(a.campos, '{}'::text[]) as campos_ajustados,
  v.criado_no_aparelho_em, v.criado_em, v.atualizado_em
from public.vales v
left join lateral (
  select pg_catalog.jsonb_object_agg(u.campo, u.valor_novo) as v,
         pg_catalog.array_agg(u.campo order by u.campo) as campos
  from (
    select distinct on (ag.campo) ag.campo, ag.valor_novo
    from public.ajustes_gestor ag
    where ag.empresa_id = v.empresa_id and ag.tabela_alvo = 'vales'
      and ag.registro_id = v.id and ag.apagado_em is null
    order by ag.campo, ag.criado_em desc, ag.id desc
  ) u
) a on true
where v.apagado_em is null;

revoke all on public.fretes_efetivos, public.abastecimentos_efetivos,
  public.gastos_viagem_efetivos, public.vales_efetivos from public, anon, authenticated;
grant select on public.fretes_efetivos, public.abastecimentos_efetivos,
  public.gastos_viagem_efetivos, public.vales_efetivos to authenticated;
