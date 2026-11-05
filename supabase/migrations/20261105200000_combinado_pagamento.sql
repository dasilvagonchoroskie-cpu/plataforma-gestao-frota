-- Combinado de pagamento do motorista (pedido do Evandro em 05/11/2026).
--
-- Cada patrão paga de um jeito: comissão (% do frete), salário fixo por mês,
-- ou fixo mais % do que ele faturou no mês; a porcentagem pode ser sobre o
-- frete cheio (antes dos descontos) ou sobre o que caiu na conta, com ou sem o
-- pedágio. Escolhas dele: padrão da empresa com exceção por motorista; o %
-- do "fixo + %" é sobre os fretes dele no mês; o fixo é proporcional aos dias
-- quando o período não é um mês fechado (conta feita no app); os fretes já
-- lançados com "Frete + pedágio" passam a somar o pedágio de verdade.
--
-- * empresas: comissao_com_pedagio_padrao e salario_fixo_centavos (padrão).
-- * motoristas: percentual_comissao, comissao_sobre_bruto, comissao_com_pedagio
--   e salario_fixo_centavos; nulo = segue o padrão da empresa.
-- * fretes: comissao_com_pedagio (o pedágio entra na comissão) e o frete
--   cheio (valor fechado no lugar de peso x tonelada).
-- * comissao_sobre_bruto continua sendo "sobre o frete cheio, antes dos
--   descontos"; até aqui a tela chamava isso de "Frete + pedágio", mas a conta
--   não somava o pedágio. Daqui em diante são duas escolhas separadas.

-- ------------------------------------------------------------ empresa

alter table public.empresas add column comissao_com_pedagio_padrao boolean not null default false;
alter table public.empresas add column salario_fixo_centavos bigint not null default 0
  check (salario_fixo_centavos between 0 and 100000000);
update public.empresas set comissao_com_pedagio_padrao = comissao_sobre_bruto_padrao
 where comissao_sobre_bruto_padrao;
grant update (comissao_com_pedagio_padrao, salario_fixo_centavos) on table public.empresas to authenticated;

-- ------------------------------------------------- exceção por motorista

alter table public.motoristas add column percentual_comissao numeric(7, 4)
  check (percentual_comissao between 0 and 100);
alter table public.motoristas add column comissao_sobre_bruto boolean;
alter table public.motoristas add column comissao_com_pedagio boolean;
alter table public.motoristas add column salario_fixo_centavos bigint
  check (salario_fixo_centavos between 0 and 100000000);
-- A política motoristas_gestor_alterar_ativo deixa só o dono e o gestor da
-- empresa alterarem; o motorista não muda o próprio combinado.
grant update (percentual_comissao, comissao_sobre_bruto, comissao_com_pedagio, salario_fixo_centavos)
  on table public.motoristas to authenticated;

-- ------------------------------------------------------------- fretes

alter table public.fretes add column comissao_com_pedagio boolean not null default false;
alter table public.fretes add column frete_cheio boolean not null default false;
alter table public.fretes add column valor_frete_cheio_centavos bigint not null default 0
  check (valor_frete_cheio_centavos >= 0);

-- Fretes já lançados com "Frete + pedágio": o pedágio passa a entrar.
update public.fretes set comissao_com_pedagio = true where comissao_sobre_bruto;

-- Fretes com as correções do gestor (agora com os campos novos no fim).
create or replace view public.fretes_efetivos with (security_invoker = true) as
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
  f.criado_no_aparelho_em, f.criado_em, f.atualizado_em,
  f.modalidade, f.extras,
  coalesce((a.v ->> 'comissao_com_pedagio')::boolean, f.comissao_com_pedagio) as comissao_com_pedagio,
  coalesce((a.v ->> 'frete_cheio')::boolean, f.frete_cheio) as frete_cheio,
  coalesce((a.v ->> 'valor_frete_cheio_centavos')::bigint, f.valor_frete_cheio_centavos) as valor_frete_cheio_centavos
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

-- ---------------------------------------------- correção pelo gestor

-- Igual à anterior, com os campos novos do frete.
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
      when 'comissao_com_pedagio' then 'logico'
      when 'frete_cheio' then 'logico'
      when 'valor_frete_cheio_centavos' then 'centavos'
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
      when 'forma_pagamento' then 'forma_pagamento'
      end
    when 'vales' then case p_campo
      when 'data' then 'data' when 'valor_centavos' then 'centavos'
      when 'observacao' then 'texto'
      end
  end
$$;

-- Correções do gestor em "Frete + pedágio" (comissao_sobre_bruto) valem
-- também para o pedágio. Fica depois de campo_ajustavel_tipo, que agora
-- conhece o campo novo.
insert into public.ajustes_gestor (id, empresa_id, tabela_alvo, registro_id, campo, valor_novo, motivo, autor_id, criado_em)
select gen_random_uuid(), ag.empresa_id, ag.tabela_alvo, ag.registro_id, 'comissao_com_pedagio', ag.valor_novo,
       ag.motivo, ag.autor_id, ag.criado_em
  from public.ajustes_gestor ag
 where ag.tabela_alvo = 'fretes' and ag.campo = 'comissao_sobre_bruto' and ag.apagado_em is null
   and exists (select 1 from public.fretes f where f.id = ag.registro_id and f.apagado_em is null);

-- ------------------------------------------------------- sincronização

-- Igual à anterior: o padrão do frete novo vem do combinado do motorista.
create or replace function public.sync_gravar_item(
  p_tabela text, p_dados jsonb, p_empresa uuid, p_motorista uuid, p_uid uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_combinado public.motoristas;
  v_id uuid := (p_dados ->> 'id')::uuid;
  v_dados jsonb := pg_catalog.jsonb_strip_nulls(p_dados);
  v_padroes jsonb := '{}';
  v_padroes_inclusao jsonb := '{}';
  v_existente jsonb;
  v_novo jsonb;
  v_colunas text;
  v_apagar boolean := (p_dados ->> 'apagado_em') is not null;
  v_empresa public.empresas;
  v_frete uuid;
  v_placa text;
  v_outro public.caminhoes;
  v_modalidade text;
  v_tipo text;
begin
  if v_id is null then
    return pg_catalog.jsonb_build_object('motivo', 'sem_id', 'mensagem', 'Registro sem identificação.');
  end if;
  if (v_dados ? 'motorista_id') and (v_dados ->> 'motorista_id')::uuid <> p_motorista then
    return pg_catalog.jsonb_build_object('motivo', 'outro_motorista',
      'mensagem', 'Este lançamento é de outro motorista.');
  end if;

  -- Caminhão que o motorista cadastrou (não achou na lista).
  if p_tabela = 'caminhoes' then
    if exists (select 1 from public.caminhoes c where c.id = v_id) then
      if exists (select 1 from public.caminhoes c where c.id = v_id and c.empresa_id = p_empresa) then
        return null;
      end if;
      return pg_catalog.jsonb_build_object('motivo', 'id_em_uso', 'mensagem', 'Caminhão repetido.');
    end if;
    v_placa := public.normalizar_placa(v_dados ->> 'placa');
    select * into v_outro from public.caminhoes c where c.empresa_id = p_empresa and c.placa = v_placa;
    if found then
      -- O gestor já tinha cadastrado esta placa: o app passa a usar o id dele.
      return pg_catalog.jsonb_build_object('motivo', 'substituido', 'substituido_por', v_outro.id,
        'atual', pg_catalog.to_jsonb(v_outro));
    end if;
    insert into public.caminhoes (id, empresa_id, placa, numero_frota, modelo, ativo, confirmado)
    values (v_id, p_empresa, v_placa, nullif(pg_catalog.btrim(v_dados ->> 'numero_frota'), ''),
            coalesce(v_dados ->> 'modelo', ''), true, false);
    return null;
  end if;

  if p_tabela = 'uso_caminhao' then
    perform public.registrar_uso_caminhao(v_id, p_empresa, p_motorista,
      (v_dados ->> 'caminhao_id')::uuid, (v_dados ->> 'inicio_em')::timestamptz, p_uid);
    return null;
  end if;

  if p_tabela not in ('fretes', 'abastecimentos', 'gastos_viagem', 'vales', 'ajustes_km', 'viagens', 'paradas') then
    return pg_catalog.jsonb_build_object('motivo', 'tabela_invalida', 'mensagem', 'Tipo de registro desconhecido.');
  end if;

  if p_tabela in ('fretes', 'viagens') then
    select m.modalidade, md.tipo into v_modalidade, v_tipo
    from public.motoristas m left join public.modalidades md on md.codigo = m.modalidade
    where m.id = p_motorista;
  end if;

  if p_tabela = 'fretes' then
    select * into v_empresa from public.empresas e where e.id = p_empresa;
    select * into v_combinado from public.motoristas m where m.id = p_motorista;
    v_padroes := pg_catalog.jsonb_build_object(
      'embarcador', '', 'peso_carga_kg', 0, 'valor_tonelada_centavos', 0, 'adiantamento_centavos', 0,
      'saldo_centavos', 0, 'pedagio_centavos', 0, 'peso_descarga_kg', 0, 'desconto_quebra_centavos', 0,
      'percentual_comissao', coalesce(v_combinado.percentual_comissao, v_empresa.percentual_comissao_padrao),
      'comissao_sobre_bruto', coalesce(v_combinado.comissao_sobre_bruto, v_empresa.comissao_sobre_bruto_padrao));
    -- Campos novos de 05/11/2026 só no frete novo (o app antigo não manda e,
    -- numa alteração, eles ficam como estão). No app antigo, "Frete + pedágio"
    -- (comissao_sobre_bruto) quer dizer também com pedágio.
    v_padroes_inclusao := pg_catalog.jsonb_build_object(
      'modalidade', case when v_tipo = 'frete' then v_modalidade else 'graneleiro' end,
      'extras', '{}'::jsonb,
      'comissao_com_pedagio', coalesce((v_dados ->> 'comissao_sobre_bruto')::boolean,
        v_combinado.comissao_com_pedagio, v_empresa.comissao_com_pedagio_padrao),
      'frete_cheio', false,
      'valor_frete_cheio_centavos', 0);
  elsif p_tabela = 'viagens' then
    if v_dados ? 'placa_carreta' then
      v_dados := v_dados || pg_catalog.jsonb_build_object('placa_carreta',
        public.normalizar_placa(v_dados ->> 'placa_carreta'));
    end if;
    v_padroes_inclusao := pg_catalog.jsonb_build_object(
      'modalidade', case when v_tipo = 'viagem' then v_modalidade else 'bau' end,
      'engate_local', '', 'desengate_local', '', 'entregas_quantidade', 0,
      'entregas_cidades', '[]'::jsonb, 'extras', '{}'::jsonb);
  elsif p_tabela = 'paradas' then
    v_padroes_inclusao := '{"ajustado": false}'::jsonb;
  elsif p_tabela = 'gastos_viagem' then
    -- App antigo não manda a forma de pagamento: conta como nota assinada.
    v_padroes_inclusao := '{"forma_pagamento": "nota"}'::jsonb;
  elsif p_tabela = 'abastecimentos' then
    v_padroes := '{"cidade": "", "posto": "", "litros": 0, "valor_centavos": 0, "tanque_cheio": true, "ponto_de_partida": false}';
  end if;

  -- Frete ligado precisa ser do próprio motorista.
  if p_tabela in ('abastecimentos', 'gastos_viagem') and v_dados ? 'frete_id' then
    select f.id into v_frete from public.fretes f
    where f.id = (v_dados ->> 'frete_id')::uuid and f.motorista_id = p_motorista and f.empresa_id = p_empresa;
    if v_frete is null then
      return pg_catalog.jsonb_build_object('motivo', 'frete_invalido', 'mensagem', 'O frete ligado não foi encontrado.');
    end if;
  end if;

  v_novo := v_padroes || (v_dados - 'apagado_em' - 'criado_em' - 'atualizado_em')
    || pg_catalog.jsonb_build_object('id', v_id, 'empresa_id', p_empresa, 'motorista_id', p_motorista);

  execute pg_catalog.format('select pg_catalog.to_jsonb(t) from public.%I t where t.id = $1 for update', p_tabela)
    into v_existente using v_id;

  if v_existente is null then
    if v_apagar then
      return null; -- criado e apagado antes de chegar: nada a gravar
    end if;
    v_novo := v_padroes_inclusao || v_novo;
    execute pg_catalog.format(
      'insert into public.%I select * from pg_catalog.jsonb_populate_record(null::public.%I, $1)',
      p_tabela, p_tabela) using v_novo;
    return null;
  end if;

  if (v_existente ->> 'empresa_id')::uuid <> p_empresa or (v_existente ->> 'motorista_id')::uuid <> p_motorista then
    return pg_catalog.jsonb_build_object('motivo', 'id_em_uso', 'mensagem', 'Registro repetido.');
  end if;
  if v_existente ->> 'apagado_em' is not null then
    if v_apagar then return null; end if;
    return pg_catalog.jsonb_build_object('motivo', 'apagado', 'mensagem', 'Este lançamento já foi apagado.');
  end if;

  -- Mesmo conteúdo (reenvio): aceita sem mudar nada.
  execute pg_catalog.format(
    'select pg_catalog.to_jsonb(r) from pg_catalog.jsonb_populate_record(null::public.%I, $1) r', p_tabela)
    into v_novo using (v_existente || v_novo);
  if not v_apagar and (v_novo - 'criado_em' - 'atualizado_em') = (v_existente - 'criado_em' - 'atualizado_em') then
    return null;
  end if;

  if p_tabela in ('fretes', 'abastecimentos', 'gastos_viagem', 'vales') and exists (
    select 1 from public.ajustes_gestor ag
    where ag.tabela_alvo = p_tabela and ag.registro_id = v_id and ag.apagado_em is null
  ) then
    return pg_catalog.jsonb_build_object('motivo', 'ajustado',
      'mensagem', 'O seu patrão já corrigiu este lançamento. Para mudar de novo, fale com ele.',
      'atual', v_existente);
  end if;

  if v_apagar then
    execute pg_catalog.format('update public.%I set apagado_em = pg_catalog.clock_timestamp() where id = $1', p_tabela)
      using v_id;
    return null;
  end if;

  select pg_catalog.string_agg(pg_catalog.quote_ident(c.column_name), ', ' order by c.ordinal_position)
    into v_colunas
  from information_schema.columns c
  where c.table_schema = 'public' and c.table_name = p_tabela
    and c.column_name not in ('id', 'empresa_id', 'motorista_id', 'criado_em', 'atualizado_em', 'apagado_em');
  execute pg_catalog.format(
    'update public.%I t set (%s) = (select %s from pg_catalog.jsonb_populate_record(null::public.%I, $1)) where t.id = $2',
    p_tabela, v_colunas, v_colunas, p_tabela) using v_novo, v_id;
  return null;
end;
$$;

-- ------------------------------------------------------- o que o app lê

-- Igual à anterior, com o padrão novo da empresa e o combinado do motorista.
create or replace function public.situacao_acesso()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_perfil public.perfis;
  v_empresa public.empresas;
  v_motorista public.motoristas;
  v_pedido jsonb;
  v_email_confirmado boolean;
  v_bloqueada boolean;
  v_excluir_em timestamptz;
  v_admin boolean;
  v_provisoria boolean;
begin
  if v_uid is null then
    return pg_catalog.jsonb_build_object('logado', false);
  end if;
  select (u.email_confirmed_at is not null) into v_email_confirmado from auth.users u where u.id = v_uid;
  v_admin := exists (select 1 from public.admins_plataforma a where a.usuario_id = v_uid);
  v_provisoria := public.senha_provisoria_pendente();
  select * into v_perfil from public.perfis p where p.id = v_uid;
  if not found then
    return pg_catalog.jsonb_build_object('logado', true, 'email_confirmado', coalesce(v_email_confirmado, false),
      'perfil', null, 'empresa', null, 'motorista', null, 'pedido', null,
      'admin_plataforma', v_admin, 'senha_provisoria', v_provisoria);
  end if;
  if v_perfil.empresa_id is not null and v_perfil.ativo and v_perfil.apagado_em is null then
    select * into v_empresa from public.empresas e where e.id = v_perfil.empresa_id and e.apagado_em is null;
  end if;
  if v_perfil.papel = 'motorista' and v_perfil.empresa_id is not null then
    select * into v_motorista from public.motoristas m
    where m.perfil_id = v_uid and m.empresa_id = v_perfil.empresa_id;
  end if;
  select pg_catalog.jsonb_build_object(
      'id', pe.id, 'status', pe.status, 'pedido_em', pe.pedido_em,
      'decidido_em', pe.decidido_em, 'empresa_nome', e.nome)
    into v_pedido
  from public.pedidos_entrada pe
  join public.empresas e on e.id = pe.empresa_id
  where pe.perfil_id = v_uid and pe.apagado_em is null
  order by pe.pedido_em desc
  limit 1;

  if v_empresa.id is not null then
    v_bloqueada := v_empresa.bloqueada_em is not null
      or (v_empresa.acesso_ate is not null and v_empresa.acesso_ate <= pg_catalog.now());
    v_excluir_em := case
      when v_empresa.excluir_em is not null then v_empresa.excluir_em
      when v_empresa.bloqueada_em is null and v_empresa.acesso_ate is not null
        then v_empresa.acesso_ate + interval '30 days' end;
  end if;

  return pg_catalog.jsonb_build_object(
    'logado', true,
    'email_confirmado', coalesce(v_email_confirmado, false),
    'admin_plataforma', v_admin,
    'senha_provisoria', v_provisoria,
    'perfil', pg_catalog.jsonb_build_object(
      'id', v_perfil.id, 'nome', v_perfil.nome, 'papel', v_perfil.papel,
      'email', v_perfil.email, 'cpf', v_perfil.cpf, 'ativo', v_perfil.ativo and v_perfil.apagado_em is null,
      'exclusao_pedida_em', v_perfil.exclusao_pedida_em),
    'empresa', case when v_empresa.id is null then null else pg_catalog.jsonb_build_object(
      'id', v_empresa.id, 'nome', v_empresa.nome, 'status', v_empresa.status,
      'plano', v_empresa.plano, 'limite_caminhoes', v_empresa.limite_caminhoes,
      'percentual_comissao_padrao', v_empresa.percentual_comissao_padrao,
      'comissao_sobre_bruto_padrao', v_empresa.comissao_sobre_bruto_padrao,
      'comissao_com_pedagio_padrao', v_empresa.comissao_com_pedagio_padrao,
      'salario_fixo_centavos', v_empresa.salario_fixo_centavos,
      'gastos_descontam_do_liquido', v_empresa.gastos_descontam_do_liquido,
      'vale_desconta_do_liquido', v_empresa.vale_desconta_do_liquido,
      'codigo_entrada', case when v_perfil.papel in ('dono', 'gestor') then v_empresa.codigo_entrada end,
      'bloqueada', v_bloqueada,
      'motivo_bloqueio', case when v_bloqueada then coalesce(v_empresa.motivo_bloqueio,
        'O período de teste terminou.') end,
      'acesso_ate', v_empresa.acesso_ate,
      'excluir_em', v_excluir_em,
      'modalidades', case when v_bloqueada then '[]'::jsonb
        else public.modalidades_efetivas(v_empresa.id, true) end,
      'paradas_ativas', v_empresa.paradas_ativas,
      'limite_sem_descanso_minutos', v_empresa.limite_sem_descanso_minutos,
      'motivos_parada', case when v_empresa.paradas_ativas then (
        select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
            'codigo', mp.codigo, 'nome', mp.nome, 'conta_como_descanso', mp.conta_como_descanso, 'ativo', mp.ativo)
          order by mp.ordem, mp.nome), '[]'::jsonb)
        from public.motivos_parada mp) else '[]'::jsonb end) end,
    'motorista', case when v_motorista.id is null then null else pg_catalog.jsonb_build_object(
      'id', v_motorista.id, 'nome', v_motorista.nome, 'ativo', v_motorista.ativo and v_motorista.apagado_em is null,
      'modalidade', v_motorista.modalidade,
      -- Combinado só dele (nulo = segue o padrão da empresa).
      'percentual_comissao', v_motorista.percentual_comissao,
      'comissao_sobre_bruto', v_motorista.comissao_sobre_bruto,
      'comissao_com_pedagio', v_motorista.comissao_com_pedagio,
      'salario_fixo_centavos', v_motorista.salario_fixo_centavos) end,
    'pedido', v_pedido,
    'termos', pg_catalog.jsonb_build_object('versao', public.versao_termos(),
      'aceito', exists (select 1 from public.aceites_termos a
                        where a.perfil_id = v_uid and a.versao = public.versao_termos())),
    'recuperacao', exists (select 1 from public.codigos_recuperacao c where c.perfil_id = v_uid)
  );
end;
$$;
