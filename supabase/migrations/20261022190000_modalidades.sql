-- Modalidades de operação (Graneleiro, Grade baixa, Caçamba, Baú e Sider).
--
-- Pedido do Evandro em 22/10/2026:
-- * a empresa escolhe no painel as modalidades com que trabalha; cada motorista
--   tem uma (o gestor define, ou o motorista escolhe no cadastro entre as
--   habilitadas; com uma só, ninguém pergunta);
-- * tudo o que já existe vira Graneleiro (empresas, motoristas e fretes);
-- * Grade baixa e Caçamba funcionam como o Graneleiro (frete com peso, valor
--   da tonelada e comissão). Baú e Sider funcionam por viagem: uma viagem por
--   carreta engatada (placa, onde e quando engatou, até onde levou e quando,
--   entregas), sem dinheiro do frete; o motorista ganha salário e a comissão é
--   lançada pelo gestor no fechamento do acerto (comissão menos descontos menos
--   vales; diesel e gastos só se a regra da empresa mandar);
-- * os campos de cada modalidade mudam sem refazer o app: o dono mostra,
--   esconde, torna obrigatório e renomeia em Configurações; campos novos são
--   criados pela Plataforma (super administrador) e ficam em "extras".
--
-- Nada do que já existe muda de comportamento: o Graneleiro continua com os
-- mesmos campos, as mesmas contas e o mesmo envio do celular.

-- ------------------------------------------------- campos de fábrica

-- Campos de fábrica de cada tipo de modalidade. "chave" é a coluna do banco;
-- "pode_ocultar" falso quer dizer que o dono só pode renomear o campo.
-- etapa (viagem): engate (começo), entregas (durante) ou desengate (fim).
create or replace function public.campos_padrao_modalidade(p_tipo text)
returns jsonb
language sql
immutable
set search_path = ''
as $$
  select case p_tipo
    when 'frete' then $j$[
      {"chave": "data_carga", "rotulo": "Data da carga", "tipo": "data", "obrigatorio": true, "pode_ocultar": false},
      {"chave": "origem", "rotulo": "Origem (de onde saiu)", "tipo": "cidade", "obrigatorio": true, "pode_ocultar": false},
      {"chave": "destino", "rotulo": "Destino (para onde vai)", "tipo": "cidade", "obrigatorio": true, "pode_ocultar": false},
      {"chave": "embarcador", "rotulo": "Embarcador ou cliente", "tipo": "texto", "obrigatorio": false, "pode_ocultar": true},
      {"chave": "peso_carga_kg", "rotulo": "Peso na carga", "tipo": "peso", "obrigatorio": false, "pode_ocultar": true},
      {"chave": "valor_tonelada_centavos", "rotulo": "Valor da tonelada", "tipo": "dinheiro", "obrigatorio": false, "pode_ocultar": true},
      {"chave": "adiantamento_centavos", "rotulo": "Adiantamento", "tipo": "dinheiro", "obrigatorio": false, "pode_ocultar": true},
      {"chave": "saldo_centavos", "rotulo": "Saldo", "tipo": "dinheiro", "obrigatorio": false, "pode_ocultar": true},
      {"chave": "pedagio_centavos", "rotulo": "Pedágio no cartão ou tag", "tipo": "dinheiro", "obrigatorio": false, "pode_ocultar": true},
      {"chave": "percentual_comissao", "rotulo": "Sua comissão", "tipo": "percentual", "obrigatorio": false, "pode_ocultar": true},
      {"chave": "peso_descarga_kg", "rotulo": "Peso na descarga", "tipo": "peso", "obrigatorio": false, "pode_ocultar": true},
      {"chave": "desconto_quebra_centavos", "rotulo": "Desconto de quebra", "tipo": "dinheiro", "obrigatorio": false, "pode_ocultar": true}
    ]$j$::jsonb
    when 'viagem' then $j$[
      {"chave": "placa_carreta", "rotulo": "Placa da carreta", "tipo": "placa", "obrigatorio": true, "pode_ocultar": false, "etapa": "engate"},
      {"chave": "engate_local", "rotulo": "Onde engatou", "tipo": "cidade", "obrigatorio": true, "pode_ocultar": false, "etapa": "engate"},
      {"chave": "engate_em", "rotulo": "Quando engatou", "tipo": "data_hora", "obrigatorio": true, "pode_ocultar": false, "etapa": "engate"},
      {"chave": "entregas_quantidade", "rotulo": "Quantas entregas", "tipo": "inteiro", "obrigatorio": false, "pode_ocultar": true, "etapa": "entregas"},
      {"chave": "entregas_cidades", "rotulo": "Cidades das entregas", "tipo": "cidades", "obrigatorio": false, "pode_ocultar": true, "etapa": "entregas"},
      {"chave": "desengate_local", "rotulo": "Até onde levou", "tipo": "cidade", "obrigatorio": true, "pode_ocultar": false, "etapa": "desengate"},
      {"chave": "desengate_em", "rotulo": "Quando desengatou", "tipo": "data_hora", "obrigatorio": true, "pode_ocultar": false, "etapa": "desengate"},
      {"chave": "observacao", "rotulo": "Observação", "tipo": "texto", "obrigatorio": false, "pode_ocultar": true, "etapa": "desengate"}
    ]$j$::jsonb
  end
$$;

-- --------------------------------------------------- catálogo da plataforma

create table public.modalidades (
  codigo text primary key check (codigo ~ '^[a-z][a-z0-9_]{1,29}$'),
  nome text not null check (length(btrim(nome)) between 2 and 40),
  tipo text not null check (tipo in ('frete', 'viagem')),
  campos jsonb not null check (jsonb_typeof(campos) = 'array'),
  ordem integer not null default 100,
  ativa boolean not null default true,
  criado_em timestamptz not null default pg_catalog.now(),
  atualizado_em timestamptz not null default pg_catalog.now()
);

insert into public.modalidades (codigo, nome, tipo, campos, ordem) values
  ('graneleiro', 'Graneleiro', 'frete', public.campos_padrao_modalidade('frete'), 10),
  ('grade_baixa', 'Grade baixa', 'frete', public.campos_padrao_modalidade('frete'), 20),
  ('cacamba', 'Caçamba', 'frete', public.campos_padrao_modalidade('frete'), 30),
  ('bau', 'Baú', 'viagem', public.campos_padrao_modalidade('viagem'), 40),
  ('sider', 'Sider', 'viagem', public.campos_padrao_modalidade('viagem'), 50);

-- ------------------------------------------------- modalidades da empresa

-- campos: ajustes do dono por chave: {"rotulo": "...", "visivel": bool, "obrigatorio": bool}.
create table public.empresas_modalidades (
  id uuid primary key default pg_catalog.gen_random_uuid(),
  empresa_id uuid not null references public.empresas(empresa_id),
  modalidade text not null references public.modalidades(codigo),
  ativa boolean not null default true,
  campos jsonb not null default '{}'::jsonb check (jsonb_typeof(campos) = 'object'),
  criado_em timestamptz not null default pg_catalog.now(),
  atualizado_em timestamptz not null default pg_catalog.now(),
  constraint empresas_modalidades_empresa_modalidade_uk unique (empresa_id, modalidade),
  constraint empresas_modalidades_empresa_id_id_uk unique (empresa_id, id)
);
create index empresas_modalidades_modalidade_idx on public.empresas_modalidades (modalidade);


-- Empresa nova também começa com Graneleiro (o dono habilita as outras).
create or replace function public.empresa_modalidade_padrao()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.empresas_modalidades (empresa_id, modalidade, ativa)
  values (new.id, 'graneleiro', true)
  on conflict (empresa_id, modalidade) do nothing;
  return new;
end;
$$;
create trigger empresas_modalidade_padrao after insert on public.empresas
  for each row execute function public.empresa_modalidade_padrao();

-- ------------------------------------------------- modalidade do motorista

alter table public.motoristas add column modalidade text references public.modalidades(codigo);
alter table public.convites_motorista add column modalidade text references public.modalidades(codigo);
create index motoristas_modalidade_idx on public.motoristas (modalidade);
create index convites_motorista_modalidade_idx on public.convites_motorista (modalidade);

-- Tudo o que já existe vira Graneleiro: as empresas e os motoristas (sem
-- encher a auditoria com uma linha por motorista).
select pg_catalog.set_config('frota.sem_auditoria', 'sim', true);
insert into public.empresas_modalidades (empresa_id, modalidade, ativa)
select e.id, 'graneleiro', true from public.empresas e
on conflict (empresa_id, modalidade) do nothing;
update public.motoristas set modalidade = 'graneleiro' where modalidade is null;
select pg_catalog.set_config('frota.sem_auditoria', '', true);

-- Motorista novo: a modalidade do código individual que o gestor gerou; se a
-- empresa tem uma modalidade só, essa; senão fica vazia e o app pergunta.
create or replace function public.motorista_modalidade_inicial()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_modalidade text;
  v_quantas integer;
begin
  if new.modalidade is not null then
    return new;
  end if;
  select c.modalidade into v_modalidade
  from public.convites_motorista c
  join public.empresas_modalidades em on em.empresa_id = c.empresa_id and em.modalidade = c.modalidade and em.ativa
  where c.empresa_id = new.empresa_id and c.cpf = new.cpf and c.modalidade is not null
    and c.usado_em is null and c.cancelado_em is null and c.apagado_em is null
  order by c.criado_em desc
  limit 1;
  if v_modalidade is null then
    select count(*), pg_catalog.min(em.modalidade) into v_quantas, v_modalidade
    from public.empresas_modalidades em where em.empresa_id = new.empresa_id and em.ativa;
    if v_quantas <> 1 then
      v_modalidade := null;
    end if;
  end if;
  new.modalidade := v_modalidade;
  return new;
end;
$$;
create trigger motoristas_modalidade_inicial before insert on public.motoristas
  for each row execute function public.motorista_modalidade_inicial();

-- ------------------------------------------------------------ fretes

-- Qual modalidade (Graneleiro, Grade baixa, Caçamba...) e os campos novos
-- criados pela Plataforma.
alter table public.fretes add column modalidade text not null default 'graneleiro'
  references public.modalidades(codigo);
alter table public.fretes add column extras jsonb not null default '{}'::jsonb;
alter table public.fretes add constraint fretes_extras_ck
  check (jsonb_typeof(extras) = 'object' and length(extras::text) <= 4000);
create index fretes_modalidade_idx on public.fretes (modalidade);

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
  f.modalidade, f.extras
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

-- ---------------------------------------------- viagens (Baú e Sider)

-- Uma viagem por carreta engatada. O cavalo é o caminhão do motorista.
-- Sem desengate_em, a viagem está em andamento.
create table public.viagens (
  id uuid primary key,
  empresa_id uuid not null references public.empresas(empresa_id),
  motorista_id uuid not null,
  caminhao_id uuid not null,
  modalidade text not null references public.modalidades(codigo),
  placa_carreta text not null,
  engate_local text not null default '' check (length(engate_local) <= 120),
  engate_em timestamptz not null,
  desengate_local text not null default '' check (length(desengate_local) <= 120),
  desengate_em timestamptz,
  entregas_quantidade integer not null default 0 check (entregas_quantidade between 0 and 999),
  entregas_cidades jsonb not null default '[]'::jsonb,
  observacao text check (observacao is null or length(observacao) <= 300),
  extras jsonb not null default '{}'::jsonb,
  criado_no_aparelho_em timestamptz,
  criado_em timestamptz not null default pg_catalog.now(),
  atualizado_em timestamptz not null default pg_catalog.now(),
  apagado_em timestamptz,
  constraint viagens_placa_carreta_ck check (placa_carreta ~ '^[A-Z]{3}[0-9][A-Z0-9][0-9]{2}$'),
  constraint viagens_entregas_cidades_ck check (jsonb_typeof(entregas_cidades) = 'array'
    and jsonb_array_length(entregas_cidades) <= 100 and length(entregas_cidades::text) <= 4000),
  constraint viagens_extras_ck check (jsonb_typeof(extras) = 'object' and length(extras::text) <= 4000),
  constraint viagens_intervalo_ck check (desengate_em is null or desengate_em >= engate_em),
  constraint viagens_empresa_id_id_uk unique (empresa_id, id),
  constraint viagens_motorista_empresa_fk foreign key (empresa_id, motorista_id)
    references public.motoristas(empresa_id, id),
  constraint viagens_caminhao_empresa_fk foreign key (empresa_id, caminhao_id)
    references public.caminhoes(empresa_id, id)
);
create index viagens_empresa_motorista_engate_idx on public.viagens (empresa_id, motorista_id, engate_em);
create index viagens_empresa_caminhao_idx on public.viagens (empresa_id, caminhao_id);
create index viagens_empresa_engate_idx on public.viagens (empresa_id, engate_em);
create index viagens_sync_idx on public.viagens (empresa_id, atualizado_em);
create index viagens_modalidade_idx on public.viagens (modalidade);

-- ----------------------------------------------------------------- acertos

-- Fechamento do período de um motorista, feito pelo gestor: a comissão em
-- reais, os descontos (descrição e valor) e o que o servidor somou de vales,
-- diesel e gastos no período. O motorista vê o acerto fechado no app.
-- Corrigir um acerto muda a mesma linha (a auditoria guarda o antes).
create table public.acertos (
  id uuid primary key,
  empresa_id uuid not null references public.empresas(empresa_id),
  motorista_id uuid not null,
  periodo_inicio date not null,
  periodo_fim date not null,
  comissao_centavos bigint not null check (comissao_centavos between 0 and 100000000000),
  descontos jsonb not null default '[]'::jsonb,
  total_descontos_centavos bigint not null default 0 check (total_descontos_centavos >= 0),
  vales_centavos bigint not null default 0,
  diesel_centavos bigint not null default 0,
  gastos_centavos bigint not null default 0,
  desconta_vales boolean not null,
  desconta_gastos boolean not null,
  para_receber_centavos bigint not null,
  quantidade_viagens integer not null default 0,
  observacao text check (observacao is null or length(observacao) <= 300),
  autor_id uuid not null,
  fechado_em timestamptz not null default pg_catalog.now(),
  criado_em timestamptz not null default pg_catalog.now(),
  atualizado_em timestamptz not null default pg_catalog.now(),
  apagado_em timestamptz,
  constraint acertos_periodo_ck check (periodo_fim >= periodo_inicio),
  constraint acertos_descontos_ck check (jsonb_typeof(descontos) = 'array' and length(descontos::text) <= 6000),
  constraint acertos_empresa_id_id_uk unique (empresa_id, id),
  constraint acertos_motorista_empresa_fk foreign key (empresa_id, motorista_id)
    references public.motoristas(empresa_id, id),
  constraint acertos_autor_empresa_fk foreign key (empresa_id, autor_id)
    references public.perfis(empresa_id, id)
);
create index acertos_empresa_motorista_periodo_idx on public.acertos (empresa_id, motorista_id, periodo_inicio);
create index acertos_empresa_autor_idx on public.acertos (empresa_id, autor_id);
create index acertos_sync_idx on public.acertos (empresa_id, atualizado_em);

-- ------------------------------------------------ triggers e RLS das novas

create trigger modalidades_atualizado_em before insert or update on public.modalidades
  for each row execute function public.definir_atualizado_em();
create trigger empresas_modalidades_atualizado_em before insert or update on public.empresas_modalidades
  for each row execute function public.definir_atualizado_em();
create trigger viagens_atualizado_em before insert or update on public.viagens
  for each row execute function public.definir_atualizado_em();
create trigger acertos_atualizado_em before insert or update on public.acertos
  for each row execute function public.definir_atualizado_em();

create trigger empresas_modalidades_auditoria after insert or update or delete on public.empresas_modalidades
  for each row execute function public.registrar_auditoria();
create trigger viagens_auditoria after insert or update or delete on public.viagens
  for each row execute function public.registrar_auditoria();
create trigger acertos_auditoria after insert or update or delete on public.acertos
  for each row execute function public.registrar_auditoria();

alter table public.modalidades enable row level security;
alter table public.empresas_modalidades enable row level security;
alter table public.viagens enable row level security;
alter table public.acertos enable row level security;

-- O catálogo não tem dado de empresa nenhuma: quem entrou lê as ativas.
create policy modalidades_ler on public.modalidades for select to authenticated
  using (ativa);
create policy empresas_modalidades_ler_empresa on public.empresas_modalidades for select to authenticated
  using (empresa_id = (select public.empresa_do_usuario()));
create policy viagens_ler_proprias_ou_gestao on public.viagens for select to authenticated
  using (empresa_id = (select public.empresa_do_usuario()) and apagado_em is null and
    (motorista_id = (select public.motorista_do_usuario()) or (select public.eh_gestor_ou_dono())));
create policy acertos_ler_proprios_ou_gestao on public.acertos for select to authenticated
  using (empresa_id = (select public.empresa_do_usuario()) and apagado_em is null and
    (motorista_id = (select public.motorista_do_usuario()) or (select public.eh_gestor_ou_dono())));

revoke all on table public.modalidades, public.empresas_modalidades, public.viagens, public.acertos
  from public, anon, authenticated;
grant select on table public.modalidades, public.empresas_modalidades, public.viagens, public.acertos
  to authenticated;

-- ------------------------------------------------ campos de cada empresa

-- Junta os campos do catálogo com os ajustes do dono. Campo que não pode ser
-- escondido continua visível e com a obrigação de fábrica; campo escondido
-- nunca é obrigatório; campo desativado pela Plataforma some dos formulários.
create or replace function public.campos_efetivos(p_catalogo jsonb, p_ajustes jsonb)
returns jsonb
language sql
immutable
set search_path = ''
as $$
  select coalesce(pg_catalog.jsonb_agg(
    (c.campo - 'obrigatorio' - 'rotulo') || pg_catalog.jsonb_build_object(
      'rotulo', coalesce(nullif(pg_catalog.btrim(a.ajuste ->> 'rotulo'), ''), c.campo ->> 'rotulo'),
      'rotulo_padrao', c.campo ->> 'rotulo',
      'visivel', v.visivel,
      'obrigatorio', case
        when not v.visivel then false
        when coalesce((c.campo ->> 'pode_ocultar')::boolean, true)
          then coalesce((a.ajuste ->> 'obrigatorio')::boolean, (c.campo ->> 'obrigatorio')::boolean, false)
        else coalesce((c.campo ->> 'obrigatorio')::boolean, false) end)
    order by c.ordem), '[]'::jsonb)
  from pg_catalog.jsonb_array_elements(coalesce(p_catalogo, '[]'::jsonb)) with ordinality as c(campo, ordem)
  cross join lateral (select coalesce(p_ajustes, '{}'::jsonb) -> (c.campo ->> 'chave') as ajuste) a
  cross join lateral (select not coalesce((c.campo ->> 'desativado')::boolean, false) and case
      when coalesce((c.campo ->> 'pode_ocultar')::boolean, true) then coalesce((a.ajuste ->> 'visivel')::boolean, true)
      else true end as visivel) v
$$;

-- Modalidades do catálogo com a situação na empresa (ativa ou não) e os campos
-- já ajustados. p_so_ativas: só as que a empresa usa.
create or replace function public.modalidades_efetivas(p_empresa uuid, p_so_ativas boolean)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
      'codigo', m.codigo, 'nome', m.nome, 'tipo', m.tipo,
      'ativa', coalesce(em.ativa, false),
      'campos', public.campos_efetivos(m.campos, coalesce(em.campos, '{}'::jsonb)))
    order by m.ordem, m.nome), '[]'::jsonb)
  from public.modalidades m
  left join public.empresas_modalidades em on em.empresa_id = p_empresa and em.modalidade = m.codigo
  where m.ativa and (not p_so_ativas or coalesce(em.ativa, false))
$$;

-- Para a tela de Configurações (dono e gestor): todas as modalidades, com os
-- ajustes que o dono já fez e quantos motoristas usam cada uma.
create or replace function public.modalidades_da_empresa()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_empresa uuid := public.empresa_do_usuario();
begin
  if not public.eh_gestor_ou_dono() then
    perform public.erro('Só o dono ou o gestor veem as modalidades.', 'sem_permissao', '42501');
  end if;
  return (
    select coalesce(pg_catalog.jsonb_agg(x || pg_catalog.jsonb_build_object(
        'ajustes', coalesce((select em.campos from public.empresas_modalidades em
                             where em.empresa_id = v_empresa and em.modalidade = x ->> 'codigo'), '{}'::jsonb),
        'motoristas', (select count(*) from public.motoristas mo
                       where mo.empresa_id = v_empresa and mo.modalidade = x ->> 'codigo'
                         and mo.ativo and mo.apagado_em is null))), '[]'::jsonb)
    from pg_catalog.jsonb_array_elements(public.modalidades_efetivas(v_empresa, false)) x);
end;
$$;

-- O dono liga ou desliga uma modalidade e ajusta os campos dela.
-- p_campos: {"chave": {"rotulo": "...", "visivel": bool, "obrigatorio": bool}}
-- (null deixa como está).
create or replace function public.salvar_modalidade_empresa(p_modalidade text, p_ativa boolean, p_campos jsonb default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_empresa uuid := public.empresa_do_usuario();
  v_mod public.modalidades;
  v_chaves text[];
  v_chave text;
  v_ajuste jsonb;
  v_limpo jsonb := '{}'::jsonb;
  v_rotulo text;
  v_item jsonb;
begin
  if not public.eh_dono() then
    perform public.erro('Só o dono muda as modalidades da empresa.', 'sem_permissao', '42501');
  end if;
  select * into v_mod from public.modalidades m where m.codigo = p_modalidade and m.ativa;
  if not found then
    perform public.erro('Modalidade não encontrada.', 'modalidade_inexistente');
  end if;
  if p_ativa is null then
    perform public.erro('Diga se a modalidade fica ligada ou desligada.', 'ativa_invalida');
  end if;

  if p_campos is not null then
    if pg_catalog.jsonb_typeof(p_campos) <> 'object' then
      perform public.erro('Campos inválidos.', 'campos_invalidos');
    end if;
    select coalesce(pg_catalog.array_agg(c ->> 'chave'), '{}') into v_chaves
    from pg_catalog.jsonb_array_elements(v_mod.campos) c;
    for v_chave, v_ajuste in select * from pg_catalog.jsonb_each(p_campos) loop
      if not (v_chave = any (v_chaves)) then
        perform public.erro('Este campo não existe nesta modalidade.', 'campo_inexistente');
      end if;
      if pg_catalog.jsonb_typeof(v_ajuste) <> 'object' then
        perform public.erro('Campos inválidos.', 'campos_invalidos');
      end if;
      v_item := '{}'::jsonb;
      v_rotulo := pg_catalog.regexp_replace(pg_catalog.btrim(coalesce(v_ajuste ->> 'rotulo', '')), '\s+', ' ', 'g');
      if v_rotulo <> '' then
        if pg_catalog.length(v_rotulo) > 40 then
          perform public.erro('O nome do campo pode ter até 40 letras.', 'rotulo_grande');
        end if;
        v_item := v_item || pg_catalog.jsonb_build_object('rotulo', v_rotulo);
      end if;
      if v_ajuste ? 'visivel' then
        if pg_catalog.jsonb_typeof(v_ajuste -> 'visivel') <> 'boolean' then
          perform public.erro('Campos inválidos.', 'campos_invalidos');
        end if;
        v_item := v_item || pg_catalog.jsonb_build_object('visivel', v_ajuste -> 'visivel');
      end if;
      if v_ajuste ? 'obrigatorio' then
        if pg_catalog.jsonb_typeof(v_ajuste -> 'obrigatorio') <> 'boolean' then
          perform public.erro('Campos inválidos.', 'campos_invalidos');
        end if;
        v_item := v_item || pg_catalog.jsonb_build_object('obrigatorio', v_ajuste -> 'obrigatorio');
      end if;
      if v_item <> '{}'::jsonb then
        v_limpo := v_limpo || pg_catalog.jsonb_build_object(v_chave, v_item);
      end if;
    end loop;
  end if;

  if not p_ativa then
    if exists (select 1 from public.motoristas mo where mo.empresa_id = v_empresa and mo.modalidade = p_modalidade
               and mo.ativo and mo.apagado_em is null) then
      perform public.erro('Há motoristas nesta modalidade. Troque a modalidade deles antes de desligar.',
        'modalidade_em_uso');
    end if;
    if not exists (select 1 from public.empresas_modalidades em where em.empresa_id = v_empresa
                   and em.ativa and em.modalidade <> p_modalidade) then
      perform public.erro('A empresa precisa de pelo menos uma modalidade ligada.', 'ultima_modalidade');
    end if;
  end if;

  insert into public.empresas_modalidades (empresa_id, modalidade, ativa, campos)
  values (v_empresa, p_modalidade, p_ativa, v_limpo)
  on conflict (empresa_id, modalidade) do update
    set ativa = excluded.ativa,
        campos = case when p_campos is null then public.empresas_modalidades.campos else excluded.campos end;

  return (select x from pg_catalog.jsonb_array_elements(public.modalidades_da_empresa()) x
          where x ->> 'codigo' = p_modalidade);
end;
$$;

-- O gestor define (ou troca) a modalidade de um motorista.
create or replace function public.definir_modalidade_motorista(p_motorista_id uuid, p_modalidade text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_empresa uuid := public.empresa_do_usuario();
begin
  if not public.eh_gestor_ou_dono() then
    perform public.erro('Só o dono ou o gestor mudam a modalidade do motorista.', 'sem_permissao', '42501');
  end if;
  if not exists (select 1 from public.empresas_modalidades em where em.empresa_id = v_empresa
                 and em.modalidade = p_modalidade and em.ativa) then
    perform public.erro('Esta modalidade não está ligada na empresa.', 'modalidade_desligada');
  end if;
  update public.motoristas set modalidade = p_modalidade
  where id = p_motorista_id and empresa_id = v_empresa;
  if not found then
    perform public.erro('Motorista não encontrado.', 'motorista_inexistente');
  end if;
  return pg_catalog.jsonb_build_object('ok', true, 'modalidade', p_modalidade);
end;
$$;

-- O motorista escolhe a modalidade no cadastro, uma vez (depois, só o gestor troca).
create or replace function public.escolher_minha_modalidade(p_modalidade text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_motorista public.motoristas;
begin
  select * into v_motorista from public.motoristas m where m.id = public.motorista_do_usuario() for update;
  if not found then
    perform public.erro('Sua conta ainda não foi aprovada pela empresa ou foi desativada.', 'sem_vinculo', '42501');
  end if;
  if v_motorista.modalidade is not null then
    if v_motorista.modalidade = p_modalidade then
      return pg_catalog.jsonb_build_object('ok', true, 'modalidade', p_modalidade);
    end if;
    perform public.erro('A sua modalidade já foi escolhida. Para trocar, fale com o seu patrão.', 'ja_escolhida');
  end if;
  if not exists (select 1 from public.empresas_modalidades em where em.empresa_id = v_motorista.empresa_id
                 and em.modalidade = p_modalidade and em.ativa) then
    perform public.erro('Esta modalidade não está ligada na empresa.', 'modalidade_desligada');
  end if;
  update public.motoristas set modalidade = p_modalidade where id = v_motorista.id;
  return pg_catalog.jsonb_build_object('ok', true, 'modalidade', p_modalidade);
end;
$$;

-- Código individual do motorista, agora com a modalidade (opcional).
drop function public.gerar_convite_motorista(text, text);
create or replace function public.gerar_convite_motorista(p_nome text, p_cpf text, p_modalidade text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_empresa uuid := public.empresa_do_usuario();
  v_nome text := pg_catalog.regexp_replace(pg_catalog.btrim(coalesce(p_nome, '')), '\s+', ' ', 'g');
  v_cpf text := public.so_digitos(p_cpf);
  v_modalidade text := nullif(pg_catalog.btrim(coalesce(p_modalidade, '')), '');
  v_convite public.convites_motorista;
begin
  if not public.eh_gestor_ou_dono() then
    perform public.erro('Só o dono ou o gestor podem cadastrar motoristas.', 'sem_permissao', '42501');
  end if;
  if pg_catalog.length(v_nome) < 2 or pg_catalog.length(v_nome) > 120 then
    perform public.erro('Escreva o nome do motorista.', 'nome_invalido');
  end if;
  if not public.cpf_valido(v_cpf) then
    perform public.erro('O CPF não está certo. Confira os números.', 'cpf_invalido');
  end if;
  if v_modalidade is not null and not exists (select 1 from public.empresas_modalidades em
      where em.empresa_id = v_empresa and em.modalidade = v_modalidade and em.ativa) then
    perform public.erro('Esta modalidade não está ligada na empresa.', 'modalidade_desligada');
  end if;
  if exists (select 1 from public.motoristas m where m.empresa_id = v_empresa and m.cpf = v_cpf
             and m.ativo and m.apagado_em is null) then
    perform public.erro('Este motorista já está na empresa.', 'ja_na_empresa');
  end if;
  if exists (select 1 from public.motoristas m where m.empresa_id = v_empresa and m.cpf = v_cpf) then
    perform public.erro('Este motorista já tem cadastro na empresa e está desligado. Abra o nome dele em Motoristas para religar o acesso.',
      'motorista_desligado');
  end if;

  update public.convites_motorista c set cancelado_em = pg_catalog.now()
  where c.empresa_id = v_empresa and c.cpf = v_cpf and c.usado_em is null and c.cancelado_em is null;

  insert into public.convites_motorista (empresa_id, codigo, nome, cpf, criado_por, expira_em, modalidade)
  values (v_empresa, public.gerar_codigo_entrada(), v_nome, v_cpf, auth.uid(),
          pg_catalog.now() + interval '7 days', v_modalidade)
  returning * into v_convite;

  return pg_catalog.jsonb_build_object('id', v_convite.id, 'codigo', v_convite.codigo,
    'nome', v_convite.nome, 'cpf', v_convite.cpf, 'expira_em', v_convite.expira_em,
    'modalidade', v_convite.modalidade);
end;
$$;

-- --------------------------------------------------------- acerto (Baú)

-- Vales, diesel, gastos e viagens de um motorista no período (datas de
-- Brasília), com os valores já corrigidos pelo gestor.
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
    'quantidade_viagens', (select count(*) from public.viagens vi
      where vi.empresa_id = p_empresa and vi.motorista_id = p_motorista and vi.apagado_em is null
        and (vi.engate_em at time zone 'America/Sao_Paulo')::date between p_inicio and p_fim))
$$;

-- Mostra ao gestor, antes de fechar, o que o servidor vai somar.
create or replace function public.previa_acerto(p_motorista_id uuid, p_inicio date, p_fim date)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_empresa uuid := public.empresa_do_usuario();
  v_regras public.empresas;
begin
  if not public.eh_gestor_ou_dono() then
    perform public.erro('Só o dono ou o gestor fazem o acerto.', 'sem_permissao', '42501');
  end if;
  if not exists (select 1 from public.motoristas m where m.id = p_motorista_id and m.empresa_id = v_empresa) then
    perform public.erro('Motorista não encontrado.', 'motorista_inexistente');
  end if;
  select * into v_regras from public.empresas e where e.id = v_empresa;
  return public.totais_acerto(v_empresa, p_motorista_id, p_inicio, p_fim) || pg_catalog.jsonb_build_object(
    'desconta_vales', v_regras.vale_desconta_do_liquido,
    'desconta_gastos', v_regras.gastos_descontam_do_liquido);
end;
$$;

-- Fecha (ou corrige) o acerto. Para receber = comissão - descontos - vales
-- (se a regra da empresa manda) - diesel e gastos (se a regra manda).
-- p_descontos: [{"descricao": "...", "valor_centavos": 1000}].
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
  v_receber := p_comissao_centavos - v_total_descontos;
  if v_regras.vale_desconta_do_liquido then
    v_receber := v_receber - (v_totais ->> 'vales_centavos')::bigint;
  end if;
  if v_regras.gastos_descontam_do_liquido then
    v_receber := v_receber - (v_totais ->> 'diesel_centavos')::bigint - (v_totais ->> 'gastos_centavos')::bigint;
  end if;

  if v_existente.id is null then
    insert into public.acertos (id, empresa_id, motorista_id, periodo_inicio, periodo_fim, comissao_centavos,
      descontos, total_descontos_centavos, vales_centavos, diesel_centavos, gastos_centavos,
      desconta_vales, desconta_gastos, para_receber_centavos, quantidade_viagens, observacao, autor_id, fechado_em)
    values (p_id, v_empresa, p_motorista_id, p_inicio, p_fim, p_comissao_centavos,
      v_descontos, v_total_descontos, (v_totais ->> 'vales_centavos')::bigint,
      (v_totais ->> 'diesel_centavos')::bigint, (v_totais ->> 'gastos_centavos')::bigint,
      v_regras.vale_desconta_do_liquido, v_regras.gastos_descontam_do_liquido, v_receber,
      (v_totais ->> 'quantidade_viagens')::integer, v_obs, auth.uid(), pg_catalog.now())
    returning * into v_linha;
  else
    update public.acertos set periodo_inicio = p_inicio, periodo_fim = p_fim,
      comissao_centavos = p_comissao_centavos, descontos = v_descontos,
      total_descontos_centavos = v_total_descontos,
      vales_centavos = (v_totais ->> 'vales_centavos')::bigint,
      diesel_centavos = (v_totais ->> 'diesel_centavos')::bigint,
      gastos_centavos = (v_totais ->> 'gastos_centavos')::bigint,
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

-- ---------------------------------------------- Plataforma (super administrador)

create or replace function public.plataforma_modalidades()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform public.exigir_admin_plataforma();
  return (select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
      'codigo', m.codigo, 'nome', m.nome, 'tipo', m.tipo, 'ativa', m.ativa, 'ordem', m.ordem,
      'campos', m.campos,
      'empresas', (select count(*) from public.empresas_modalidades em where em.modalidade = m.codigo and em.ativa))
    order by m.ordem, m.nome), '[]'::jsonb)
    from public.modalidades m);
end;
$$;

-- Cria uma modalidade nova (com os campos de fábrica do tipo escolhido) ou
-- muda o nome e a situação de uma que já existe. O tipo não muda depois.
create or replace function public.plataforma_salvar_modalidade(p_codigo text, p_nome text, p_tipo text, p_ativa boolean default true)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_nome text := pg_catalog.regexp_replace(pg_catalog.btrim(coalesce(p_nome, '')), '\s+', ' ', 'g');
  v_codigo text := pg_catalog.lower(pg_catalog.btrim(coalesce(p_codigo, '')));
  v_atual public.modalidades;
begin
  perform public.exigir_admin_plataforma();
  if v_codigo !~ '^[a-z][a-z0-9_]{1,29}$' then
    perform public.erro('Código da modalidade inválido (letras minúsculas, números e _).', 'codigo_invalido');
  end if;
  if pg_catalog.length(v_nome) < 2 or pg_catalog.length(v_nome) > 40 then
    perform public.erro('Escreva o nome da modalidade (até 40 letras).', 'nome_invalido');
  end if;
  if p_tipo is null or p_tipo not in ('frete', 'viagem') then
    perform public.erro('Escolha como a modalidade funciona: por frete ou por viagem.', 'tipo_invalido');
  end if;
  select * into v_atual from public.modalidades m where m.codigo = v_codigo for update;
  if found then
    if v_atual.tipo <> p_tipo then
      perform public.erro('O tipo de uma modalidade não muda depois de criada.', 'tipo_fixo');
    end if;
    if not coalesce(p_ativa, true) and exists (select 1 from public.empresas_modalidades em
        where em.modalidade = v_codigo and em.ativa) then
      perform public.erro('Há empresas usando esta modalidade. Ela não pode ser desligada.', 'modalidade_em_uso');
    end if;
    update public.modalidades set nome = v_nome, ativa = coalesce(p_ativa, true) where codigo = v_codigo;
  else
    if exists (select 1 from public.modalidades m where pg_catalog.lower(m.nome) = pg_catalog.lower(v_nome)) then
      perform public.erro('Já existe uma modalidade com este nome.', 'nome_em_uso');
    end if;
    insert into public.modalidades (codigo, nome, tipo, campos, ordem, ativa)
    values (v_codigo, v_nome, p_tipo, public.campos_padrao_modalidade(p_tipo),
            coalesce((select pg_catalog.max(m.ordem) from public.modalidades m), 0) + 10, coalesce(p_ativa, true));
  end if;
  insert into public.auditoria_plataforma (acao, campos, origem)
  values (case when v_atual.codigo is null then 'modalidade_criada' else 'modalidade_alterada' end,
          pg_catalog.jsonb_build_object('codigo', v_codigo, 'tipo', p_tipo, 'ativa', coalesce(p_ativa, true)),
          public.origem_da_acao());
  return (select x from pg_catalog.jsonb_array_elements(public.plataforma_modalidades()) x
          where x ->> 'codigo' = v_codigo);
end;
$$;

-- Cria ou muda um campo novo (extra) de uma modalidade. Os campos de fábrica
-- não mudam aqui (o dono de cada empresa renomeia e esconde em Configurações).
-- p_campo: {"chave", "rotulo", "tipo", "obrigatorio", "etapa", "desativado"}.
create or replace function public.plataforma_salvar_campo(p_modalidade text, p_campo jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_mod public.modalidades;
  v_chave text := pg_catalog.lower(pg_catalog.btrim(coalesce(p_campo ->> 'chave', '')));
  v_rotulo text := pg_catalog.regexp_replace(pg_catalog.btrim(coalesce(p_campo ->> 'rotulo', '')), '\s+', ' ', 'g');
  v_tipo text := coalesce(p_campo ->> 'tipo', '');
  v_etapa text := nullif(coalesce(p_campo ->> 'etapa', ''), '');
  v_campo jsonb;
  v_atual jsonb;
  v_posicao integer;
begin
  perform public.exigir_admin_plataforma();
  select * into v_mod from public.modalidades m where m.codigo = p_modalidade for update;
  if not found then
    perform public.erro('Modalidade não encontrada.', 'modalidade_inexistente');
  end if;
  if p_campo is null or pg_catalog.jsonb_typeof(p_campo) <> 'object' then
    perform public.erro('Campo inválido.', 'campo_invalido');
  end if;
  if v_chave !~ '^[a-z][a-z0-9_]{1,40}$' then
    perform public.erro('Código do campo inválido (letras minúsculas, números e _).', 'chave_invalida');
  end if;
  if pg_catalog.length(v_rotulo) < 2 or pg_catalog.length(v_rotulo) > 40 then
    perform public.erro('Escreva o nome do campo (até 40 letras).', 'rotulo_invalido');
  end if;
  if v_tipo not in ('texto', 'numero', 'inteiro', 'dinheiro', 'data', 'data_hora', 'sim_nao', 'cidade') then
    perform public.erro('Tipo de campo inválido.', 'tipo_invalido');
  end if;
  if v_mod.tipo = 'viagem' and coalesce(v_etapa, '') not in ('engate', 'entregas', 'desengate') then
    perform public.erro('Escolha quando o motorista preenche: no engate, nas entregas ou no desengate.', 'etapa_invalida');
  end if;
  if v_mod.tipo = 'frete' then
    v_etapa := null;
  end if;
  -- Nomes de colunas do banco ficam reservados.
  if exists (select 1 from information_schema.columns c where c.table_schema = 'public'
             and c.table_name in ('fretes', 'viagens') and c.column_name = v_chave) then
    perform public.erro('Este código de campo é reservado. Escolha outro.', 'chave_reservada');
  end if;

  select x.campo, x.pos::integer into v_atual, v_posicao
  from pg_catalog.jsonb_array_elements(v_mod.campos) with ordinality as x(campo, pos)
  where x.campo ->> 'chave' = v_chave;
  if v_atual is not null and not coalesce((v_atual ->> 'extra')::boolean, false) then
    perform public.erro('Os campos de fábrica não mudam aqui.', 'campo_de_fabrica');
  end if;
  if v_atual is not null and v_atual ->> 'tipo' <> v_tipo then
    perform public.erro('O tipo de um campo não muda depois de criado. Crie outro campo.', 'tipo_fixo');
  end if;
  if v_atual is null and (select count(*) from pg_catalog.jsonb_array_elements(v_mod.campos) c
                          where coalesce((c ->> 'extra')::boolean, false)) >= 20 then
    perform public.erro('Até 20 campos novos por modalidade.', 'campos_demais');
  end if;

  v_campo := pg_catalog.jsonb_build_object('chave', v_chave, 'rotulo', v_rotulo, 'tipo', v_tipo,
    'obrigatorio', coalesce((p_campo ->> 'obrigatorio')::boolean, false), 'pode_ocultar', true, 'extra', true,
    'desativado', coalesce((p_campo ->> 'desativado')::boolean, false));
  if v_etapa is not null then
    v_campo := v_campo || pg_catalog.jsonb_build_object('etapa', v_etapa);
  end if;

  if v_atual is null then
    update public.modalidades set campos = campos || pg_catalog.jsonb_build_array(v_campo) where codigo = v_mod.codigo;
  else
    update public.modalidades set campos = pg_catalog.jsonb_set(campos, array[(v_posicao - 1)::text], v_campo)
    where codigo = v_mod.codigo;
  end if;
  insert into public.auditoria_plataforma (acao, campos, origem)
  values (case when v_atual is null then 'campo_criado' else 'campo_alterado' end,
          pg_catalog.jsonb_build_object('modalidade', v_mod.codigo, 'chave', v_chave, 'tipo', v_tipo),
          public.origem_da_acao());
  return (select x from pg_catalog.jsonb_array_elements(public.plataforma_modalidades()) x
          where x ->> 'codigo' = v_mod.codigo);
end;
$$;

-- ------------------------------------------------- situação de acesso

-- Igual à anterior, com a modalidade do motorista e as modalidades ligadas
-- na empresa (já com os campos ajustados pelo dono).
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
        else public.modalidades_efetivas(v_empresa.id, true) end) end,
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

-- ------------------------------------------------------------ sincronização

-- Igual à anterior, mais as viagens (Baú e Sider) e, nos fretes novos, a
-- modalidade do motorista e os campos extras. Os padrões novos valem só na
-- inclusão: numa mudança, o que não veio continua como estava.
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

  if p_tabela not in ('fretes', 'abastecimentos', 'gastos_viagem', 'vales', 'ajustes_km', 'viagens') then
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

-- Igual à anterior; as viagens entram junto com os fretes.
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
      when 'ajustes_km' then 7 else 9 end, i.ordem
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

-- Igual à anterior, mais as viagens e os acertos fechados do motorista.
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

-- ------------------------------------------------------------ privilégios

revoke all on function public.campos_padrao_modalidade(text) from public, anon, authenticated;
revoke all on function public.campos_efetivos(jsonb, jsonb) from public, anon, authenticated;
revoke all on function public.modalidades_efetivas(uuid, boolean) from public, anon, authenticated;
revoke all on function public.empresa_modalidade_padrao() from public, anon, authenticated;
revoke all on function public.motorista_modalidade_inicial() from public, anon, authenticated;
revoke all on function public.totais_acerto(uuid, uuid, date, date) from public, anon, authenticated;
revoke all on function public.modalidades_da_empresa() from public, anon;
revoke all on function public.salvar_modalidade_empresa(text, boolean, jsonb) from public, anon;
revoke all on function public.definir_modalidade_motorista(uuid, text) from public, anon;
revoke all on function public.escolher_minha_modalidade(text) from public, anon;
revoke all on function public.gerar_convite_motorista(text, text, text) from public, anon;
revoke all on function public.previa_acerto(uuid, date, date) from public, anon;
revoke all on function public.fechar_acerto(uuid, uuid, date, date, bigint, jsonb, text) from public, anon;
revoke all on function public.plataforma_modalidades() from public, anon;
revoke all on function public.plataforma_salvar_modalidade(text, text, text, boolean) from public, anon;
revoke all on function public.plataforma_salvar_campo(text, jsonb) from public, anon;
revoke all on function public.situacao_acesso() from public, anon;
revoke all on function public.sync_gravar_item(text, jsonb, uuid, uuid, uuid) from public, anon, authenticated;
revoke all on function public.sincronizar_lote(jsonb) from public, anon;
revoke all on function public.baixar_alteracoes(timestamptz) from public, anon;

grant execute on function public.modalidades_da_empresa() to authenticated;
grant execute on function public.salvar_modalidade_empresa(text, boolean, jsonb) to authenticated;
grant execute on function public.definir_modalidade_motorista(uuid, text) to authenticated;
grant execute on function public.escolher_minha_modalidade(text) to authenticated;
grant execute on function public.gerar_convite_motorista(text, text, text) to authenticated;
grant execute on function public.previa_acerto(uuid, date, date) to authenticated;
grant execute on function public.fechar_acerto(uuid, uuid, date, date, bigint, jsonb, text) to authenticated;
grant execute on function public.plataforma_modalidades() to authenticated;
grant execute on function public.plataforma_salvar_modalidade(text, text, text, boolean) to authenticated;
grant execute on function public.plataforma_salvar_campo(text, jsonb) to authenticated;
grant execute on function public.situacao_acesso() to authenticated;
grant execute on function public.sincronizar_lote(jsonb) to authenticated;
grant execute on function public.baixar_alteracoes(timestamptz) to authenticated;
