-- Registro de paradas do motorista (pedido do Evandro em 22/10/2026).
--
-- * Opcional por empresa: desligado por padrão; quem não usa não vê a aba
--   (nem o motorista nem o patrão). O dono liga em Configurações.
-- * O motorista toca em "Registrar parada", escolhe o motivo (café ou pausa
--   curta, refeição, descanso, pernoite, manutenção mecânica, abastecimento,
--   carga, descarga, fiscalização, outro) e o horário fica gravado; "Retomar
--   viagem" fecha a parada. Esqueceu de retomar: ele informa o horário e a
--   parada fica marcada como ajustada. Funciona sem internet.
-- * O painel mostra as paradas por motorista e período e o maior intervalo sem
--   descanso, destacando o que passar do limite da empresa (padrão 5h30).
-- * Nenhum número da lei fica no código: o limite é da empresa e os motivos
--   que contam como descanso (refeição, descanso e pernoite) ficam na tabela
--   motivos_parada.
-- * É um registro interno do motorista; não substitui o tacógrafo.

-- ------------------------------------------------ configuração da empresa

alter table public.empresas add column paradas_ativas boolean not null default false;
alter table public.empresas add column limite_sem_descanso_minutos integer not null default 330;
alter table public.empresas add constraint empresas_limite_sem_descanso_ck
  check (limite_sem_descanso_minutos between 30 and 1440);
-- Só o dono muda (a política empresas_dono_atualizar já confere).
grant update (paradas_ativas, limite_sem_descanso_minutos) on table public.empresas to authenticated;

-- ----------------------------------------------------- motivos (catálogo)

create table public.motivos_parada (
  codigo text primary key check (codigo ~ '^[a-z][a-z0-9_]{1,29}$'),
  nome text not null check (length(btrim(nome)) between 2 and 40),
  conta_como_descanso boolean not null default false,
  ordem integer not null default 100,
  ativo boolean not null default true,
  criado_em timestamptz not null default pg_catalog.now(),
  atualizado_em timestamptz not null default pg_catalog.now()
);
insert into public.motivos_parada (codigo, nome, conta_como_descanso, ordem) values
  ('cafe', 'Café ou pausa curta', false, 10),
  ('refeicao', 'Refeição', true, 20),
  ('descanso', 'Descanso', true, 30),
  ('pernoite', 'Pernoite', true, 40),
  ('manutencao', 'Manutenção mecânica', false, 50),
  ('abastecimento', 'Abastecimento', false, 60),
  ('carga', 'Carga', false, 70),
  ('descarga', 'Descarga', false, 80),
  ('fiscalizacao', 'Fiscalização', false, 90),
  ('outro', 'Outro', false, 100);

-- ---------------------------------------------------------------- paradas

-- Sem fim_em, a parada está acontecendo. ajustado: o motorista informou o
-- horário depois (esqueceu de registrar ou de retomar na hora).
create table public.paradas (
  id uuid primary key,
  empresa_id uuid not null references public.empresas(empresa_id),
  motorista_id uuid not null,
  caminhao_id uuid,
  motivo text not null references public.motivos_parada(codigo),
  descricao text check (descricao is null or length(descricao) <= 120),
  inicio_em timestamptz not null,
  fim_em timestamptz,
  ajustado boolean not null default false,
  criado_no_aparelho_em timestamptz,
  criado_em timestamptz not null default pg_catalog.now(),
  atualizado_em timestamptz not null default pg_catalog.now(),
  apagado_em timestamptz,
  constraint paradas_intervalo_ck check (fim_em is null or fim_em >= inicio_em),
  constraint paradas_empresa_id_id_uk unique (empresa_id, id),
  constraint paradas_motorista_empresa_fk foreign key (empresa_id, motorista_id)
    references public.motoristas(empresa_id, id),
  constraint paradas_caminhao_empresa_fk foreign key (empresa_id, caminhao_id)
    references public.caminhoes(empresa_id, id)
);
create index paradas_empresa_motorista_inicio_idx on public.paradas (empresa_id, motorista_id, inicio_em);
create index paradas_empresa_caminhao_idx on public.paradas (empresa_id, caminhao_id);
create index paradas_motivo_idx on public.paradas (motivo);
create index paradas_sync_idx on public.paradas (empresa_id, atualizado_em);

create trigger motivos_parada_atualizado_em before insert or update on public.motivos_parada
  for each row execute function public.definir_atualizado_em();
create trigger paradas_atualizado_em before insert or update on public.paradas
  for each row execute function public.definir_atualizado_em();
create trigger paradas_auditoria after insert or update or delete on public.paradas
  for each row execute function public.registrar_auditoria();

alter table public.motivos_parada enable row level security;
alter table public.paradas enable row level security;

-- O catálogo não tem dado de empresa nenhuma.
create policy motivos_parada_ler on public.motivos_parada for select to authenticated using (true);
create policy paradas_ler_proprias_ou_gestao on public.paradas for select to authenticated
  using (empresa_id = (select public.empresa_do_usuario()) and apagado_em is null and
    (motorista_id = (select public.motorista_do_usuario()) or (select public.eh_gestor_ou_dono())));

revoke all on table public.motivos_parada, public.paradas from public, anon, authenticated;
grant select on table public.motivos_parada, public.paradas to authenticated;

-- ------------------------------------------- situação e sincronização

-- Iguais às anteriores, com as paradas: a configuração e os motivos na
-- situação da conta, as paradas no envio e na volta do celular.

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
      'modalidade', v_motorista.modalidade) end,
    'pedido', v_pedido,
    'termos', pg_catalog.jsonb_build_object('versao', public.versao_termos(),
      'aceito', exists (select 1 from public.aceites_termos a
                        where a.perfil_id = v_uid and a.versao = public.versao_termos())),
    'recuperacao', exists (select 1 from public.codigos_recuperacao c where c.perfil_id = v_uid)
  );
end;
$$;

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

create or replace function public.sincronizar_lote(p_lote jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_motorista uuid := public.motorista_do_usuario();
  v_empresa uuid;
  v_status text;
  v_dispositivo uuid := nullif(p_lote ->> 'dispositivo_id', '')::uuid;
  v_item record;
  v_dados jsonb;
  v_resultado jsonb;
  v_aceitos jsonb := '[]';
  v_rejeitados jsonb := '[]';
  v_mapa jsonb := '{}';
  v_qtd integer := coalesce(pg_catalog.jsonb_array_length(p_lote -> 'itens'), 0);
begin
  if v_motorista is null then
    perform public.erro('Sua conta ainda não foi aprovada pela empresa ou foi desativada.', 'sem_vinculo', '42501');
  end if;
  if v_qtd > 500 then
    perform public.erro('Lote grande demais.', 'lote_grande');
  end if;
  select m.empresa_id, e.status into v_empresa, v_status
  from public.motoristas m join public.empresas e on e.id = m.empresa_id
  where m.id = v_motorista;

  if v_dispositivo is not null then
    if exists (select 1 from public.dispositivos d where d.id = v_dispositivo
               and (d.perfil_id <> v_uid or d.revogado_em is not null)) then
      perform public.erro('Este celular foi desligado da empresa. Fale com o seu patrão.', 'dispositivo_revogado', '42501');
    end if;
    insert into public.dispositivos (id, empresa_id, perfil_id, apelido, ultimo_sync_em)
    values (v_dispositivo, v_empresa, v_uid, coalesce(nullif(p_lote ->> 'apelido', ''), 'Celular'),
            pg_catalog.clock_timestamp())
    on conflict (id) do update set ultimo_sync_em = excluded.ultimo_sync_em;
  end if;

  if v_status = 'suspensa' then
    select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
             'tabela', i ->> 'tabela', 'id', i -> 'dados' ->> 'id', 'motivo', 'empresa_suspensa',
             'mensagem', 'A empresa está suspensa. Os seus dados estão guardados, mas não dá para enviar agora.')), '[]')
      into v_rejeitados
    from pg_catalog.jsonb_array_elements(coalesce(p_lote -> 'itens', '[]')) i;
    return pg_catalog.jsonb_build_object('aceitos', '[]'::jsonb, 'rejeitados', v_rejeitados,
      'suspensa', true, 'servidor_em', pg_catalog.clock_timestamp());
  end if;

  for v_item in
    select i.valor, i.ordem
    from pg_catalog.jsonb_array_elements(coalesce(p_lote -> 'itens', '[]')) with ordinality as i(valor, ordem)
    order by case i.valor ->> 'tabela'
      when 'caminhoes' then 1 when 'uso_caminhao' then 2 when 'fretes' then 3 when 'viagens' then 3
      when 'abastecimentos' then 4 when 'gastos_viagem' then 5 when 'vales' then 6
      when 'ajustes_km' then 7 when 'paradas' then 8 else 9 end, i.ordem
  loop
    v_dados := v_item.valor -> 'dados';
    -- Caminhão trocado pelo id do gestor dentro do mesmo lote.
    if v_dados ? 'caminhao_id' and v_mapa ? (v_dados ->> 'caminhao_id') then
      v_dados := v_dados || pg_catalog.jsonb_build_object('caminhao_id', v_mapa ->> (v_dados ->> 'caminhao_id'));
    end if;
    begin
      v_resultado := public.sync_gravar_item(v_item.valor ->> 'tabela', v_dados, v_empresa, v_motorista, v_uid);
      if v_resultado is null then
        v_aceitos := v_aceitos || pg_catalog.jsonb_build_object('tabela', v_item.valor ->> 'tabela', 'id', v_dados ->> 'id');
      elsif v_resultado ->> 'motivo' = 'substituido' then
        v_mapa := v_mapa || pg_catalog.jsonb_build_object(v_dados ->> 'id', v_resultado ->> 'substituido_por');
        v_aceitos := v_aceitos || (pg_catalog.jsonb_build_object('tabela', 'caminhoes', 'id', v_dados ->> 'id')
          || (v_resultado - 'motivo'));
      else
        v_rejeitados := v_rejeitados || (pg_catalog.jsonb_build_object('tabela', v_item.valor ->> 'tabela',
          'id', v_dados ->> 'id') || v_resultado);
      end if;
    exception when others then
      v_rejeitados := v_rejeitados || pg_catalog.jsonb_build_object('tabela', v_item.valor ->> 'tabela',
        'id', v_dados ->> 'id', 'motivo', 'invalido',
        'mensagem', 'Este registro tem um dado que não foi aceito.', 'detalhe', sqlerrm);
    end;
  end loop;

  return pg_catalog.jsonb_build_object('aceitos', v_aceitos, 'rejeitados', v_rejeitados,
    'suspensa', false, 'servidor_em', pg_catalog.clock_timestamp());
end;
$$;

create or replace function public.baixar_alteracoes(p_desde timestamptz default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_agora timestamptz := pg_catalog.clock_timestamp();
  v_motorista uuid := public.motorista_do_usuario();
  v_empresa uuid;
  v_desde timestamptz := coalesce(p_desde - interval '2 minutes', '-infinity'::timestamptz);
begin
  if v_motorista is null then
    return pg_catalog.jsonb_build_object('servidor_em', v_agora, 'situacao', public.situacao_acesso());
  end if;
  select m.empresa_id into v_empresa from public.motoristas m where m.id = v_motorista;

  return pg_catalog.jsonb_build_object(
    'servidor_em', v_agora,
    'situacao', public.situacao_acesso(),
    'caminhoes', (select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'id', c.id, 'placa', c.placa, 'numero_frota', c.numero_frota, 'modelo', c.modelo,
        'ativo', c.ativo and c.apagado_em is null, 'confirmado', c.confirmado) order by c.placa), '[]')
      from public.caminhoes c where c.empresa_id = v_empresa and c.atualizado_em > v_desde),
    'categorias', (select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'id', g.id, 'nome', g.nome, 'ativa', g.ativa and g.apagado_em is null) order by g.nome), '[]')
      from public.categorias_gasto g where g.empresa_id = v_empresa and g.atualizado_em > v_desde),
    'fretes', (select coalesce(pg_catalog.jsonb_agg(pg_catalog.to_jsonb(f)), '[]')
      from public.fretes f where f.motorista_id = v_motorista and f.atualizado_em > v_desde),
    'viagens', (select coalesce(pg_catalog.jsonb_agg(pg_catalog.to_jsonb(vi)), '[]')
      from public.viagens vi where vi.motorista_id = v_motorista and vi.atualizado_em > v_desde),
    'abastecimentos', (select coalesce(pg_catalog.jsonb_agg(pg_catalog.to_jsonb(a)), '[]')
      from public.abastecimentos a where a.motorista_id = v_motorista and a.atualizado_em > v_desde),
    'gastos_viagem', (select coalesce(pg_catalog.jsonb_agg(pg_catalog.to_jsonb(g)), '[]')
      from public.gastos_viagem g where g.motorista_id = v_motorista and g.atualizado_em > v_desde),
    'vales', (select coalesce(pg_catalog.jsonb_agg(pg_catalog.to_jsonb(v)), '[]')
      from public.vales v where v.motorista_id = v_motorista and v.atualizado_em > v_desde),
    'ajustes_km', (select coalesce(pg_catalog.jsonb_agg(pg_catalog.to_jsonb(k)), '[]')
      from public.ajustes_km k where k.motorista_id = v_motorista and k.atualizado_em > v_desde),
    'uso_caminhao', (select coalesce(pg_catalog.jsonb_agg(pg_catalog.to_jsonb(u)), '[]')
      from public.uso_caminhao u where u.motorista_id = v_motorista and u.atualizado_em > v_desde),
    'paradas', (select coalesce(pg_catalog.jsonb_agg(pg_catalog.to_jsonb(pa)), '[]')
      from public.paradas pa where pa.motorista_id = v_motorista and pa.atualizado_em > v_desde),
    'acertos', (select coalesce(pg_catalog.jsonb_agg(pg_catalog.to_jsonb(ac) - 'autor_id'), '[]')
      from public.acertos ac where ac.motorista_id = v_motorista and ac.apagado_em is null
        and ac.atualizado_em > v_desde),
    'ajustes', (select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'id', ag.id, 'tabela_alvo', ag.tabela_alvo, 'registro_id', ag.registro_id, 'campo', ag.campo,
        'valor_antigo', ag.valor_antigo, 'valor_novo', ag.valor_novo, 'motivo', ag.motivo,
        'criado_em', ag.criado_em, 'apagado', ag.apagado_em is not null) order by ag.criado_em), '[]')
      from public.ajustes_gestor ag
      where ag.empresa_id = v_empresa and ag.atualizado_em > v_desde and (
        (ag.tabela_alvo = 'fretes' and exists (select 1 from public.fretes f where f.id = ag.registro_id and f.motorista_id = v_motorista)) or
        (ag.tabela_alvo = 'abastecimentos' and exists (select 1 from public.abastecimentos a where a.id = ag.registro_id and a.motorista_id = v_motorista)) or
        (ag.tabela_alvo = 'gastos_viagem' and exists (select 1 from public.gastos_viagem g where g.id = ag.registro_id and g.motorista_id = v_motorista)) or
        (ag.tabela_alvo = 'vales' and exists (select 1 from public.vales v where v.id = ag.registro_id and v.motorista_id = v_motorista))))
  );
end;
$$;

revoke all on function public.situacao_acesso() from public, anon;
revoke all on function public.sync_gravar_item(text, jsonb, uuid, uuid, uuid) from public, anon, authenticated;
revoke all on function public.sincronizar_lote(jsonb) from public, anon;
revoke all on function public.baixar_alteracoes(timestamptz) from public, anon;
grant execute on function public.situacao_acesso() to authenticated;
grant execute on function public.sincronizar_lote(jsonb) to authenticated;
grant execute on function public.baixar_alteracoes(timestamptz) to authenticated;
