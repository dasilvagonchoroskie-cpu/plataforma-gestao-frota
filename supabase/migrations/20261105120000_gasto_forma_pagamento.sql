-- Forma de pagamento do gasto: dinheiro (do vale) ou nota assinada.
--
-- Pedido do Evandro (23/10/2026): o motorista paga pátio, limpeza, manutenção
-- com o dinheiro do vale. Gasto pago em dinheiro abate do vale; o que foi na
-- nota a empresa paga direto. Escolhas dele: só nos gastos (o diesel não
-- muda); duas formas, dinheiro ou nota; o motorista escolhe toda vez.
-- Os gastos que já existem ficam como nota (nada muda no que já foi lançado).
--
-- Para receber = comissão - descontos
--   - vales + gastos em dinheiro   (se o vale desconta e a empresa paga os gastos)
--   - vales                        (se o vale desconta e os gastos são do motorista)
--   - diesel - gastos na nota      (se os gastos são do motorista)
-- Gasto em dinheiro que passa do vale volta para o motorista.

alter table public.gastos_viagem add column forma_pagamento text not null default 'nota'
  check (forma_pagamento in ('dinheiro', 'nota'));
alter table public.acertos add column gastos_dinheiro_centavos bigint not null default 0
  check (gastos_dinheiro_centavos >= 0);

-- Gastos com os ajustes do gestor (agora com a forma de pagamento no fim).
create or replace view public.gastos_viagem_efetivos with (security_invoker = true) as
select
  g.id, g.empresa_id, g.motorista_id,
  coalesce((a.v ->> 'caminhao_id')::uuid, g.caminhao_id) as caminhao_id,
  g.frete_id,
  coalesce((a.v ->> 'data')::timestamptz, g.data) as data,
  coalesce((a.v ->> 'categoria_id')::uuid, g.categoria_id) as categoria_id,
  coalesce((a.v ->> 'valor_centavos')::bigint, g.valor_centavos) as valor_centavos,
  coalesce(a.v ->> 'observacao', g.observacao) as observacao,
  coalesce(a.campos, '{}'::text[]) as campos_ajustados,
  g.criado_no_aparelho_em, g.criado_em, g.atualizado_em,
  coalesce(a.v ->> 'forma_pagamento', g.forma_pagamento) as forma_pagamento
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

-- ------------------------------------------------------ a conta do acerto

create or replace function public.para_receber_acerto(
  p_comissao bigint, p_descontos bigint, p_vales bigint, p_diesel bigint, p_gastos bigint,
  p_gastos_dinheiro bigint, p_desconta_vales boolean, p_desconta_gastos boolean
)
returns bigint
language sql
immutable
set search_path = ''
as $$
  select p_comissao - p_descontos
    - case when p_desconta_vales
        then p_vales - case when p_desconta_gastos then 0 else p_gastos_dinheiro end
        else 0 end
    - case when p_desconta_gastos then p_diesel + (p_gastos - p_gastos_dinheiro) else 0 end
$$;
revoke all on function public.para_receber_acerto(bigint, bigint, bigint, bigint, bigint, bigint, boolean, boolean)
  from public, anon;
grant execute on function public.para_receber_acerto(bigint, bigint, bigint, bigint, bigint, bigint, boolean, boolean)
  to authenticated;

-- Igual à anterior, com os gastos pagos em dinheiro.
create or replace function public.totais_acerto(p_empresa uuid, p_motorista uuid, p_inicio date, p_fim date)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select pg_catalog.jsonb_build_object(
    'vales_centavos', (select coalesce(sum(v.valor_centavos), 0) from public.vales_efetivos v
      where v.empresa_id = p_empresa and v.motorista_id = p_motorista
        and (v.data at time zone 'America/Sao_Paulo')::date between p_inicio and p_fim),
    'diesel_centavos', (select coalesce(sum(a.valor_centavos), 0) from public.abastecimentos_efetivos a
      where a.empresa_id = p_empresa and a.motorista_id = p_motorista and not a.ponto_de_partida
        and (a.data at time zone 'America/Sao_Paulo')::date between p_inicio and p_fim),
    'gastos_centavos', (select coalesce(sum(g.valor_centavos), 0) from public.gastos_viagem_efetivos g
      where g.empresa_id = p_empresa and g.motorista_id = p_motorista
        and (g.data at time zone 'America/Sao_Paulo')::date between p_inicio and p_fim),
    'gastos_dinheiro_centavos', (select coalesce(sum(g.valor_centavos), 0) from public.gastos_viagem_efetivos g
      where g.empresa_id = p_empresa and g.motorista_id = p_motorista and g.forma_pagamento = 'dinheiro'
        and (g.data at time zone 'America/Sao_Paulo')::date between p_inicio and p_fim),
    'quantidade_viagens', (select count(*) from public.viagens vi
      where vi.empresa_id = p_empresa and vi.motorista_id = p_motorista and vi.apagado_em is null
        and (vi.engate_em at time zone 'America/Sao_Paulo')::date between p_inicio and p_fim))
$$;

-- Igual à anterior, com a conta nova (para_receber_acerto) e os gastos em dinheiro.
create or replace function public.fechar_acerto(
  p_id uuid, p_motorista_id uuid, p_inicio date, p_fim date,
  p_comissao_centavos bigint, p_descontos jsonb default '[]'::jsonb, p_observacao text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_empresa uuid := public.empresa_do_usuario();
  v_regras public.empresas;
  v_existente public.acertos;
  v_descontos jsonb := '[]'::jsonb;
  v_total_descontos bigint := 0;
  v_item jsonb;
  v_descricao text;
  v_valor numeric;
  v_totais jsonb;
  v_receber bigint;
  v_obs text := nullif(pg_catalog.btrim(coalesce(p_observacao, '')), '');
  v_outro public.acertos;
  v_linha public.acertos;
begin
  if not public.eh_gestor_ou_dono() then
    perform public.erro('Só o dono ou o gestor fazem o acerto.', 'sem_permissao', '42501');
  end if;
  if p_id is null then
    perform public.erro('Acerto sem identificação.', 'sem_id');
  end if;
  perform 1 from public.motoristas m where m.id = p_motorista_id and m.empresa_id = v_empresa for update;
  if not found then
    perform public.erro('Motorista não encontrado.', 'motorista_inexistente');
  end if;
  if p_inicio is null or p_fim is null or p_fim < p_inicio then
    perform public.erro('Confira o período: o fim vem depois do começo.', 'periodo_invalido');
  end if;
  if p_fim - p_inicio > 366 then
    perform public.erro('O acerto pode ter até um ano.', 'periodo_grande');
  end if;
  if p_comissao_centavos is null or p_comissao_centavos < 0 or p_comissao_centavos > 100000000000 then
    perform public.erro('Confira o valor da comissão.', 'comissao_invalida');
  end if;
  if v_obs is not null and pg_catalog.length(v_obs) > 300 then
    perform public.erro('A observação pode ter até 300 letras.', 'observacao_grande');
  end if;

  if p_descontos is not null then
    if pg_catalog.jsonb_typeof(p_descontos) <> 'array' or pg_catalog.jsonb_array_length(p_descontos) > 30 then
      perform public.erro('Até 30 descontos por acerto.', 'descontos_invalidos');
    end if;
    for v_item in select x from pg_catalog.jsonb_array_elements(p_descontos) x loop
      v_descricao := pg_catalog.regexp_replace(pg_catalog.btrim(coalesce(v_item ->> 'descricao', '')), '\s+', ' ', 'g');
      if v_descricao = '' or pg_catalog.length(v_descricao) > 80 then
        perform public.erro('Escreva o motivo de cada desconto (até 80 letras).', 'desconto_sem_descricao');
      end if;
      if pg_catalog.jsonb_typeof(v_item -> 'valor_centavos') <> 'number' then
        perform public.erro('Confira o valor de cada desconto.', 'desconto_invalido');
      end if;
      v_valor := (v_item ->> 'valor_centavos')::numeric;
      if v_valor <= 0 or v_valor <> pg_catalog.trunc(v_valor) or v_valor > 100000000000 then
        perform public.erro('Confira o valor de cada desconto.', 'desconto_invalido');
      end if;
      v_descontos := v_descontos || pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object('descricao', v_descricao, 'valor_centavos', v_valor::bigint));
      v_total_descontos := v_total_descontos + v_valor::bigint;
    end loop;
  end if;

  select * into v_existente from public.acertos a where a.id = p_id for update;
  if found and (v_existente.empresa_id <> v_empresa or v_existente.motorista_id <> p_motorista_id) then
    perform public.erro('Acerto repetido com outros dados.', 'id_em_uso');
  end if;

  select * into v_outro from public.acertos a
  where a.empresa_id = v_empresa and a.motorista_id = p_motorista_id and a.apagado_em is null and a.id <> p_id
    and a.periodo_inicio <= p_fim and a.periodo_fim >= p_inicio
  order by a.periodo_inicio
  limit 1;
  if found then
    perform public.erro(pg_catalog.format('Já tem acerto fechado de %s a %s. Abra esse acerto para corrigir.',
      pg_catalog.to_char(v_outro.periodo_inicio, 'DD/MM/YYYY'), pg_catalog.to_char(v_outro.periodo_fim, 'DD/MM/YYYY')),
      'periodo_com_acerto');
  end if;

  select * into v_regras from public.empresas e where e.id = v_empresa;
  v_totais := public.totais_acerto(v_empresa, p_motorista_id, p_inicio, p_fim);
  v_receber := public.para_receber_acerto(p_comissao_centavos, v_total_descontos,
    (v_totais ->> 'vales_centavos')::bigint, (v_totais ->> 'diesel_centavos')::bigint,
    (v_totais ->> 'gastos_centavos')::bigint, (v_totais ->> 'gastos_dinheiro_centavos')::bigint,
    v_regras.vale_desconta_do_liquido, v_regras.gastos_descontam_do_liquido);

  if v_existente.id is null then
    insert into public.acertos (id, empresa_id, motorista_id, periodo_inicio, periodo_fim, comissao_centavos,
      descontos, total_descontos_centavos, vales_centavos, diesel_centavos, gastos_centavos,
      gastos_dinheiro_centavos, desconta_vales, desconta_gastos, para_receber_centavos, quantidade_viagens, observacao, autor_id, fechado_em)
    values (p_id, v_empresa, p_motorista_id, p_inicio, p_fim, p_comissao_centavos,
      v_descontos, v_total_descontos, (v_totais ->> 'vales_centavos')::bigint,
      (v_totais ->> 'diesel_centavos')::bigint, (v_totais ->> 'gastos_centavos')::bigint,
      (v_totais ->> 'gastos_dinheiro_centavos')::bigint, v_regras.vale_desconta_do_liquido, v_regras.gastos_descontam_do_liquido, v_receber,
      (v_totais ->> 'quantidade_viagens')::integer, v_obs, auth.uid(), pg_catalog.now())
    returning * into v_linha;
  else
    update public.acertos set periodo_inicio = p_inicio, periodo_fim = p_fim,
      comissao_centavos = p_comissao_centavos, descontos = v_descontos,
      total_descontos_centavos = v_total_descontos,
      vales_centavos = (v_totais ->> 'vales_centavos')::bigint,
      diesel_centavos = (v_totais ->> 'diesel_centavos')::bigint,
      gastos_centavos = (v_totais ->> 'gastos_centavos')::bigint,
      gastos_dinheiro_centavos = (v_totais ->> 'gastos_dinheiro_centavos')::bigint,
      desconta_vales = v_regras.vale_desconta_do_liquido,
      desconta_gastos = v_regras.gastos_descontam_do_liquido,
      para_receber_centavos = v_receber,
      quantidade_viagens = (v_totais ->> 'quantidade_viagens')::integer,
      observacao = v_obs, autor_id = auth.uid(), fechado_em = pg_catalog.now()
    where id = p_id
    returning * into v_linha;
  end if;
  return pg_catalog.to_jsonb(v_linha);
end;
$$;

-- ---------------------------------------------- correção pelo gestor

-- Igual à anterior: o gestor também corrige a forma de pagamento do gasto.
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
      when 'forma_pagamento' then 'forma_pagamento'
      end
    when 'vales' then case p_campo
      when 'data' then 'data' when 'valor_centavos' then 'centavos'
      when 'observacao' then 'texto'
      end
  end
$$;

-- Igual à anterior, conferindo a forma de pagamento corrigida.
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
  elsif v_tipo = 'forma_pagamento' then
    if pg_catalog.jsonb_typeof(new.valor_novo) <> 'string'
       or (new.valor_novo #>> '{}') not in ('dinheiro', 'nota') then
      raise exception 'Escolha dinheiro ou nota' using errcode = '23514';
    end if;
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

-- ------------------------------------------------------- sincronização

-- Igual à anterior: gasto novo sem forma de pagamento (app antigo) vira nota.
create or replace function public.sync_gravar_item(
  p_tabela text, p_dados jsonb, p_empresa uuid, p_motorista uuid, p_uid uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
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
    v_padroes := pg_catalog.jsonb_build_object(
      'embarcador', '', 'peso_carga_kg', 0, 'valor_tonelada_centavos', 0, 'adiantamento_centavos', 0,
      'saldo_centavos', 0, 'pedagio_centavos', 0, 'peso_descarga_kg', 0, 'desconto_quebra_centavos', 0,
      'percentual_comissao', v_empresa.percentual_comissao_padrao,
      'comissao_sobre_bruto', v_empresa.comissao_sobre_bruto_padrao);
    v_padroes_inclusao := pg_catalog.jsonb_build_object(
      'modalidade', case when v_tipo = 'frete' then v_modalidade else 'graneleiro' end,
      'extras', '{}'::jsonb);
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
