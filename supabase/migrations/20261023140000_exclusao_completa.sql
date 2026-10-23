-- aprovado-por: Evandro em 23/10/2026 (exclusão de motorista e de empresa apaga também viagens, acertos, paradas e as modalidades da empresa; sempre com o PDF de todos os dados gerado antes)
--
-- Exclusão completa e o arquivo de dados antes de apagar.
--
-- * O Evandro aprovou em 23/10/2026, no chat, com a condição de a empresa
--   receber antes um PDF com todos os dados (da empresa ou do motorista). O
--   PDF é gerado pelo app do gestor antes de pedir a exclusão; nas exclusões
--   automáticas, o painel avisa antes do prazo com o botão do PDF.
-- * expurgar_motorista e expurgar_empresa: iguais às aprovadas em 22/10/2026,
--   agora também com viagens, acertos, paradas e as modalidades da empresa.
-- * exportar_dados_empresa(): o dono baixa todos os dados da empresa para o
--   PDF, mesmo com o acesso encerrado (até a data da exclusão). Só leitura.

-- ------------------------------------------------- exclusão de dados

-- Iguais às anteriores (aprovadas em 22/10/2026), agora também com as
-- viagens, os acertos, as paradas e as modalidades da empresa. Sem isso,
-- excluir um motorista com viagem, acerto ou parada dava erro.
create or replace function public.expurgar_motorista(p_motorista uuid, p_apagar_conta boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  m public.motoristas;
  v_ids uuid[];
begin
  select * into m from public.motoristas where id = p_motorista;
  if not found then
    return;
  end if;
  perform pg_catalog.set_config('frota.sem_auditoria', 'sim', true);

  select coalesce(pg_catalog.array_agg(t.id), '{}') into v_ids from (
    select f.id from public.fretes f where f.empresa_id = m.empresa_id and f.motorista_id = m.id
    union all select a.id from public.abastecimentos a where a.empresa_id = m.empresa_id and a.motorista_id = m.id
    union all select g.id from public.gastos_viagem g where g.empresa_id = m.empresa_id and g.motorista_id = m.id
    union all select v.id from public.vales v where v.empresa_id = m.empresa_id and v.motorista_id = m.id
    union all select k.id from public.ajustes_km k where k.empresa_id = m.empresa_id and k.motorista_id = m.id
    union all select u.id from public.uso_caminhao u where u.empresa_id = m.empresa_id and u.motorista_id = m.id
    union all select vi.id from public.viagens vi where vi.empresa_id = m.empresa_id and vi.motorista_id = m.id
    union all select ac.id from public.acertos ac where ac.empresa_id = m.empresa_id and ac.motorista_id = m.id
    union all select pa.id from public.paradas pa where pa.empresa_id = m.empresa_id and pa.motorista_id = m.id
  ) t;

  delete from public.ajustes_gestor where empresa_id = m.empresa_id and registro_id = any (v_ids);
  -- Lançamento de outro motorista ligado a um frete deste fica sem o frete.
  update public.abastecimentos set frete_id = null
  where empresa_id = m.empresa_id and motorista_id <> m.id and frete_id = any (v_ids);
  update public.gastos_viagem set frete_id = null
  where empresa_id = m.empresa_id and motorista_id <> m.id and frete_id = any (v_ids);
  delete from public.ajustes_km where empresa_id = m.empresa_id and motorista_id = m.id;
  delete from public.gastos_viagem where empresa_id = m.empresa_id and motorista_id = m.id;
  delete from public.abastecimentos where empresa_id = m.empresa_id and motorista_id = m.id;
  delete from public.vales where empresa_id = m.empresa_id and motorista_id = m.id;
  delete from public.fretes where empresa_id = m.empresa_id and motorista_id = m.id;
  delete from public.viagens where empresa_id = m.empresa_id and motorista_id = m.id;
  delete from public.acertos where empresa_id = m.empresa_id and motorista_id = m.id;
  delete from public.paradas where empresa_id = m.empresa_id and motorista_id = m.id;
  delete from public.uso_caminhao where empresa_id = m.empresa_id and motorista_id = m.id;
  delete from public.dispositivos where empresa_id = m.empresa_id and perfil_id = m.perfil_id;
  delete from public.pedidos_entrada where perfil_id = m.perfil_id;
  delete from public.convites_motorista
  where empresa_id = m.empresa_id and (usado_por = m.perfil_id or cpf = m.cpf);
  delete from public.auditoria
  where empresa_id = m.empresa_id
    and (registro_id = any (v_ids) or registro_id = m.id or autor_id = m.perfil_id);
  delete from public.motoristas where id = m.id;

  if p_apagar_conta then
    perform public.expurgar_perfil(m.perfil_id);
  else
    update public.perfis set empresa_id = null, ativo = true, exclusao_pedida_em = null
    where id = m.perfil_id;
  end if;
  perform pg_catalog.set_config('frota.sem_auditoria', '', true);
end;
$$;

create or replace function public.expurgar_empresa(p_empresa uuid, p_motivo text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_perfil uuid;
begin
  perform pg_catalog.set_config('frota.sem_auditoria', 'sim', true);
  delete from public.ajustes_gestor where empresa_id = p_empresa;
  delete from public.ajustes_km where empresa_id = p_empresa;
  delete from public.gastos_viagem where empresa_id = p_empresa;
  delete from public.abastecimentos where empresa_id = p_empresa;
  delete from public.vales where empresa_id = p_empresa;
  delete from public.fretes where empresa_id = p_empresa;
  delete from public.viagens where empresa_id = p_empresa;
  delete from public.acertos where empresa_id = p_empresa;
  delete from public.paradas where empresa_id = p_empresa;
  delete from public.uso_caminhao where empresa_id = p_empresa;
  delete from public.dispositivos where empresa_id = p_empresa;
  delete from public.pedidos_entrada where empresa_id = p_empresa;
  delete from public.convites_motorista where empresa_id = p_empresa;
  delete from public.motoristas where empresa_id = p_empresa;
  delete from public.caminhoes where empresa_id = p_empresa;
  delete from public.categorias_gasto where empresa_id = p_empresa;
  delete from public.empresas_modalidades where empresa_id = p_empresa;
  delete from public.auditoria where empresa_id = p_empresa;
  delete from public.acessos_autorizados where empresa_id = p_empresa;
  for v_perfil in select p.id from public.perfis p where p.empresa_id = p_empresa loop
    perform public.expurgar_perfil(v_perfil);
  end loop;
  update public.empresas
     set nome = 'Empresa excluída', documento = null, codigo_entrada = public.gerar_codigo_entrada(),
         apagado_em = pg_catalog.now(), excluida_em = pg_catalog.now(),
         bloqueada_em = coalesce(bloqueada_em, pg_catalog.now()),
         motivo_bloqueio = pg_catalog.left(coalesce(p_motivo, 'Conta excluída'), 200), excluir_em = null
   where id = p_empresa;
  perform pg_catalog.set_config('frota.sem_auditoria', '', true);
end;
$$;


-- ------------------------------------------ arquivo de dados (só leitura)

-- Todos os dados da empresa do dono, no mesmo formato que o painel carrega
-- (uma lista por fonte). Funciona com o acesso encerrado, para o dono guardar
-- o PDF antes da exclusão. Gestor e motorista não usam (o painel já tem os
-- dados pelas permissões normais).
create or replace function public.exportar_dados_empresa()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_perfil public.perfis;
  v_empresa uuid;
begin
  select * into v_perfil from public.perfis p
  where p.id = auth.uid() and p.papel = 'dono' and p.ativo and p.apagado_em is null and p.empresa_id is not null;
  if not found then
    perform public.erro('Só o dono da empresa baixa todos os dados.', 'sem_permissao', '42501');
  end if;
  select e.id into v_empresa from public.empresas e where e.id = v_perfil.empresa_id and e.apagado_em is null;
  if v_empresa is null then
    perform public.erro('Empresa não encontrada.', 'empresa_inexistente');
  end if;
  return pg_catalog.jsonb_build_object(
    'empresas', (select coalesce(pg_catalog.jsonb_agg(pg_catalog.to_jsonb(x)), '[]') from public.empresas x where x.id = v_empresa),
    'perfis', (select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id', x.id, 'nome', x.nome,
        'email', x.email, 'papel', x.papel, 'ativo', x.ativo, 'exclusao_pedida_em', x.exclusao_pedida_em)), '[]')
      from public.perfis x where x.empresa_id = v_empresa),
    'motoristas', (select coalesce(pg_catalog.jsonb_agg(pg_catalog.to_jsonb(x)), '[]') from public.motoristas x where x.empresa_id = v_empresa),
    'caminhoes', (select coalesce(pg_catalog.jsonb_agg(pg_catalog.to_jsonb(x)), '[]') from public.caminhoes x where x.empresa_id = v_empresa),
    'categorias_gasto', (select coalesce(pg_catalog.jsonb_agg(pg_catalog.to_jsonb(x)), '[]') from public.categorias_gasto x where x.empresa_id = v_empresa),
    'fretes_efetivos', (select coalesce(pg_catalog.jsonb_agg(pg_catalog.to_jsonb(x)), '[]') from public.fretes_efetivos x where x.empresa_id = v_empresa),
    'abastecimentos_efetivos', (select coalesce(pg_catalog.jsonb_agg(pg_catalog.to_jsonb(x)), '[]') from public.abastecimentos_efetivos x where x.empresa_id = v_empresa),
    'gastos_viagem_efetivos', (select coalesce(pg_catalog.jsonb_agg(pg_catalog.to_jsonb(x)), '[]') from public.gastos_viagem_efetivos x where x.empresa_id = v_empresa),
    'vales_efetivos', (select coalesce(pg_catalog.jsonb_agg(pg_catalog.to_jsonb(x)), '[]') from public.vales_efetivos x where x.empresa_id = v_empresa),
    'ajustes_km', (select coalesce(pg_catalog.jsonb_agg(pg_catalog.to_jsonb(x)), '[]') from public.ajustes_km x where x.empresa_id = v_empresa),
    'uso_caminhao', (select coalesce(pg_catalog.jsonb_agg(pg_catalog.to_jsonb(x)), '[]') from public.uso_caminhao x where x.empresa_id = v_empresa),
    'ajustes_gestor', (select coalesce(pg_catalog.jsonb_agg(pg_catalog.to_jsonb(x)), '[]') from public.ajustes_gestor x where x.empresa_id = v_empresa),
    'viagens', (select coalesce(pg_catalog.jsonb_agg(pg_catalog.to_jsonb(x)), '[]') from public.viagens x where x.empresa_id = v_empresa),
    'acertos', (select coalesce(pg_catalog.jsonb_agg(pg_catalog.to_jsonb(x)), '[]') from public.acertos x where x.empresa_id = v_empresa),
    'paradas', (select coalesce(pg_catalog.jsonb_agg(pg_catalog.to_jsonb(x)), '[]') from public.paradas x where x.empresa_id = v_empresa),
    'motivos_parada', (select coalesce(pg_catalog.jsonb_agg(pg_catalog.to_jsonb(x)), '[]') from public.motivos_parada x),
    'modalidades', public.modalidades_efetivas(v_empresa, false)
  );
end;
$$;

revoke all on function public.exportar_dados_empresa() from public, anon;
grant execute on function public.exportar_dados_empresa() to authenticated;
