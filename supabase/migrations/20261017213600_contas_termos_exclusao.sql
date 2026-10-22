-- Contas, termos e controle da plataforma (parte 4 de 4): exclusão de dados e
-- limpeza diária. Explicação completa na parte 2.
--
-- aprovado-por: Evandro em 22/10/2026 (Etapa 1 da segurança, com as três condições abaixo)
--
-- Aprovado pelo usuário em 22/10/2026 com três condições: (1) backup antes de
-- ligar o pg_cron (o fluxo "Banco: backup e atualização" faz o backup antes de
-- aplicar esta migration); (2) a limpeza diária começa em modo simulação, só
-- anotando o que apagaria, até ele confirmar (definir_modo_limpeza); (3) cada
-- exclusão deixa um registro mínimo, sem dado pessoal (registro_exclusoes).

-- ------------------------------------------------- registros e configuração

-- Registro mínimo de cada exclusão: qual empresa, o que foi excluído, quem
-- pediu (só o papel) e quando. Sem nome, CPF, e-mail ou id de pessoa. Fica
-- guardado mesmo depois de a empresa ser excluída.
create table if not exists public.registro_exclusoes (
  id bigint generated always as identity primary key,
  empresa_id uuid,
  tipo text not null check (tipo in ('empresa', 'motorista', 'conta_motorista')),
  pedido_por text not null check (pedido_por in ('dono', 'gestor', 'motorista', 'plataforma', 'limpeza_diaria')),
  quando timestamptz not null default pg_catalog.now()
);
create index if not exists registro_exclusoes_empresa_idx on public.registro_exclusoes (empresa_id, quando);

-- Configurações da plataforma (só o servidor). limpeza_modo: 'simulacao' (a
-- limpeza diária só anota o que apagaria) ou 'valendo'.
create table if not exists public.configuracao_plataforma (
  chave text primary key,
  valor text not null,
  atualizado_em timestamptz not null default pg_catalog.now()
);
insert into public.configuracao_plataforma (chave, valor) values ('limpeza_modo', 'simulacao')
on conflict (chave) do nothing;

-- Resultado de cada limpeza: modo, quantidades e ids (sem dado pessoal).
create table if not exists public.limpeza_execucoes (
  id bigint generated always as identity primary key,
  quando timestamptz not null default pg_catalog.now(),
  modo text not null check (modo in ('simulacao', 'valendo')),
  resultado jsonb not null
);

alter table public.registro_exclusoes enable row level security;
alter table public.configuracao_plataforma enable row level security;
alter table public.limpeza_execucoes enable row level security;
revoke all on table public.registro_exclusoes, public.configuracao_plataforma, public.limpeza_execucoes
  from public, anon, authenticated;

-- Papel de quem está chamando (dono, gestor ou motorista), para o registro.
create or replace function public.papel_do_usuario()
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select p.papel from public.perfis p where p.id = (select auth.uid())
$$;

-- ------------------------------------------------------ exclusão de dados

-- Apaga a conta de uma pessoa (perfil e login). Uso interno: quem chama já
-- apagou o que é da empresa. Aceite dos termos e código de recuperação vão
-- junto. Os registros de acesso ficam (obrigação legal, 6 meses).
create or replace function public.expurgar_perfil(p_perfil uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_cpf text;
  v_email text;
begin
  select p.cpf, pg_catalog.lower(p.email) into v_cpf, v_email from public.perfis p where p.id = p_perfil;
  delete from public.dispositivos where perfil_id = p_perfil;
  delete from public.pedidos_entrada where perfil_id = p_perfil;
  delete from public.convites_motorista where usado_por = p_perfil;
  delete from public.auditoria where autor_id = p_perfil;
  delete from public.tentativas_acesso
  where chave in ('cpf:' || coalesce(v_cpf, '-'), 'recuperar:' || coalesce(v_cpf, '-'),
                  'recuperar:' || coalesce(v_email, '-'));
  delete from public.perfis where id = p_perfil;
  delete from auth.users where id = p_perfil;
end;
$$;

-- Apaga um motorista e tudo que ele lançou na empresa. Com p_apagar_conta, a
-- conta dele também some; sem, ele fica sem empresa e pode entrar em outra.
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

-- Apaga a empresa inteira: lançamentos, caminhões, motoristas, gestores, donos
-- e os logins deles. Fica só uma linha sem dados ("Empresa excluída"), para o
-- código antigo não voltar a valer e a plataforma saber que existiu.
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
  delete from public.uso_caminhao where empresa_id = p_empresa;
  delete from public.dispositivos where empresa_id = p_empresa;
  delete from public.pedidos_entrada where empresa_id = p_empresa;
  delete from public.convites_motorista where empresa_id = p_empresa;
  delete from public.motoristas where empresa_id = p_empresa;
  delete from public.caminhoes where empresa_id = p_empresa;
  delete from public.categorias_gasto where empresa_id = p_empresa;
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

-- A gestão exclui um motorista e os lançamentos dele. Se o motorista já tinha
-- pedido para excluir a conta, a conta some também; senão ele fica sem empresa.
create or replace function public.excluir_motorista(p_motorista_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  m public.motoristas;
  v_apagar_conta boolean;
begin
  if not public.eh_gestor_ou_dono() then
    perform public.erro('Só o dono ou o gestor podem excluir motoristas.', 'sem_permissao', '42501');
  end if;
  select * into m from public.motoristas x
  where x.id = p_motorista_id and x.empresa_id = public.empresa_do_usuario();
  if not found then
    perform public.erro('Motorista não encontrado.', 'motorista_inexistente');
  end if;
  select p.exclusao_pedida_em is not null into v_apagar_conta from public.perfis p where p.id = m.perfil_id;
  perform public.expurgar_motorista(m.id, coalesce(v_apagar_conta, false));
  insert into public.auditoria (empresa_id, autor_id, acao, tabela, registro_id, depois)
  values (m.empresa_id, auth.uid(), 'excluir_motorista', 'motoristas', m.id,
          pg_catalog.jsonb_build_object('conta_apagada', coalesce(v_apagar_conta, false)));
  insert into public.registro_exclusoes (empresa_id, tipo, pedido_por)
  values (m.empresa_id, 'motorista', coalesce(public.papel_do_usuario(), 'gestor'));
  return pg_catalog.jsonb_build_object('ok', true, 'conta_apagada', coalesce(v_apagar_conta, false));
end;
$$;

-- O motorista exclui a própria conta. Sem empresa, tudo some na hora. Ligado a
-- uma empresa, o acesso fecha na hora e a empresa tem até 15 dias para guardar
-- o que a lei exige; depois tudo é apagado sozinho (limpeza_diaria).
create or replace function public.excluir_minha_conta()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_perfil public.perfis;
  v_motorista uuid;
begin
  select * into v_perfil from public.perfis p where p.id = v_uid for update;
  if not found then
    perform public.erro('Entre na sua conta para continuar.', 'sem_login', '42501');
  end if;
  if v_perfil.papel <> 'motorista' then
    perform public.erro('Contas de dono e de gestor saem junto com a empresa. O dono exclui a empresa em Configurações.',
      'nao_motorista');
  end if;
  select m.id into v_motorista from public.motoristas m where m.perfil_id = v_uid;
  insert into public.registro_exclusoes (empresa_id, tipo, pedido_por)
  values (v_perfil.empresa_id, 'conta_motorista', 'motorista');
  if v_motorista is null then
    perform public.expurgar_perfil(v_uid);
    return pg_catalog.jsonb_build_object('ok', true, 'apagada', true);
  end if;
  update public.perfis set exclusao_pedida_em = pg_catalog.now(), ativo = false where id = v_uid;
  update public.motoristas set ativo = false where id = v_motorista;
  update public.dispositivos set revogado_em = pg_catalog.now()
  where perfil_id = v_uid and revogado_em is null;
  delete from public.codigos_recuperacao where perfil_id = v_uid;
  return pg_catalog.jsonb_build_object('ok', true, 'apagada', false,
    'apagar_em', pg_catalog.now() + interval '15 days');
end;
$$;

-- O dono exclui a conta da empresa e todos os dados. Funciona mesmo com a
-- empresa bloqueada. Confirmação: digitar o nome da empresa.
create or replace function public.excluir_minha_empresa(p_confirmacao text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_perfil public.perfis;
  v_empresa public.empresas;
  v_digitado text := pg_catalog.lower(pg_catalog.regexp_replace(pg_catalog.btrim(coalesce(p_confirmacao, '')), '\s+', ' ', 'g'));
begin
  select * into v_perfil from public.perfis p
  where p.id = auth.uid() and p.papel = 'dono' and p.ativo and p.apagado_em is null and p.empresa_id is not null;
  if not found then
    perform public.erro('Só o dono da empresa pode excluir a conta da empresa.', 'sem_permissao', '42501');
  end if;
  select * into v_empresa from public.empresas e where e.id = v_perfil.empresa_id and e.apagado_em is null
  for update;
  if not found then
    perform public.erro('Empresa não encontrada.', 'empresa_inexistente');
  end if;
  if v_digitado <> pg_catalog.lower(pg_catalog.regexp_replace(pg_catalog.btrim(v_empresa.nome), '\s+', ' ', 'g')) then
    perform public.erro('Para confirmar, digite o nome da empresa igual aparece na tela.', 'confirmacao');
  end if;
  perform public.expurgar_empresa(v_empresa.id, 'Excluída pelo dono');
  insert into public.registro_exclusoes (empresa_id, tipo, pedido_por) values (v_empresa.id, 'empresa', 'dono');
  return pg_catalog.jsonb_build_object('ok', true);
end;
$$;

-- A plataforma exclui uma empresa (refeita aqui para deixar o registro).
create or replace function public.excluir_empresa_plataforma(p_empresa uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not exists (select 1 from public.empresas e where e.id = p_empresa and e.excluida_em is null) then
    perform public.erro('Empresa não encontrada.', 'empresa_inexistente');
  end if;
  perform public.expurgar_empresa(p_empresa, 'Excluída pela plataforma');
  insert into public.registro_exclusoes (empresa_id, tipo, pedido_por) values (p_empresa, 'empresa', 'plataforma');
  return pg_catalog.jsonb_build_object('ok', true);
end;
$$;

-- Roda uma vez por dia (pg_cron). Primeiro calcula o que está vencido:
-- empresas cujo prazo acabou, motoristas e contas que pediram exclusão há mais
-- de 15 dias, registros de acesso com mais de 6 meses, tentativas de login com
-- mais de 30 dias e códigos de entrada usados ou vencidos há mais de 90 dias.
-- No modo 'simulacao' (o padrão até o dono da plataforma confirmar) só anota a
-- lista em limpeza_execucoes; no modo 'valendo' apaga e deixa o registro.
create or replace function public.limpeza_diaria(p_modo text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_modo text := coalesce(p_modo,
    (select c.valor from public.configuracao_plataforma c where c.chave = 'limpeza_modo'), 'simulacao');
  v_empresas uuid[];
  v_motoristas jsonb;
  v_contas uuid[];
  v_resultado jsonb;
  v_id uuid;
  v_item jsonb;
begin
  if v_modo not in ('simulacao', 'valendo') then
    perform public.erro('Modo da limpeza inválido.', 'modo_invalido');
  end if;

  select coalesce(pg_catalog.array_agg(e.id order by e.id), '{}') into v_empresas
  from public.empresas e
  where e.excluida_em is null and e.apagado_em is null
    and (e.excluir_em <= pg_catalog.now()
         or (e.excluir_em is null and e.bloqueada_em is null
             and e.acesso_ate + interval '30 days' <= pg_catalog.now()));

  select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('motorista_id', m.id, 'empresa_id', m.empresa_id)
           order by m.id), '[]') into v_motoristas
  from public.motoristas m join public.perfis p on p.id = m.perfil_id
  where p.exclusao_pedida_em <= pg_catalog.now() - interval '15 days'
    and m.empresa_id <> all (v_empresas);

  select coalesce(pg_catalog.array_agg(p.id order by p.id), '{}') into v_contas
  from public.perfis p
  where p.exclusao_pedida_em <= pg_catalog.now() - interval '15 days'
    and not exists (select 1 from public.motoristas m where m.perfil_id = p.id);

  v_resultado := pg_catalog.jsonb_build_object(
    'empresas', pg_catalog.to_jsonb(v_empresas),
    'motoristas', v_motoristas,
    'contas_sem_empresa', pg_catalog.cardinality(v_contas),
    'registros_acesso_antigos', (select count(*) from public.registros_acesso r
                                 where r.quando < pg_catalog.now() - interval '6 months'),
    'tentativas_antigas', (select count(*) from public.tentativas_acesso t
                           where t.criado_em < pg_catalog.now() - interval '30 days'),
    'codigos_antigos', (select count(*) from public.convites_motorista c
                        where c.criado_em < pg_catalog.now() - interval '90 days'
                          and (c.usado_em is not null or c.cancelado_em is not null or c.expira_em < pg_catalog.now())));

  if v_modo = 'valendo' then
    foreach v_id in array v_empresas loop
      perform public.expurgar_empresa(v_id, 'Excluída automaticamente depois do fim do acesso');
      insert into public.registro_exclusoes (empresa_id, tipo, pedido_por) values (v_id, 'empresa', 'limpeza_diaria');
    end loop;
    for v_item in select x from pg_catalog.jsonb_array_elements(v_motoristas) x loop
      perform public.expurgar_motorista((v_item ->> 'motorista_id')::uuid, true);
      insert into public.registro_exclusoes (empresa_id, tipo, pedido_por)
      values ((v_item ->> 'empresa_id')::uuid, 'motorista', 'limpeza_diaria');
    end loop;
    foreach v_id in array v_contas loop
      perform public.expurgar_perfil(v_id);
      insert into public.registro_exclusoes (empresa_id, tipo, pedido_por) values (null, 'conta_motorista', 'limpeza_diaria');
    end loop;
    delete from public.registros_acesso where quando < pg_catalog.now() - interval '6 months';
    delete from public.tentativas_acesso where criado_em < pg_catalog.now() - interval '30 days';
    delete from public.convites_motorista
    where criado_em < pg_catalog.now() - interval '90 days'
      and (usado_em is not null or cancelado_em is not null or expira_em < pg_catalog.now());
    delete from public.limpeza_execucoes where quando < pg_catalog.now() - interval '1 year';
  end if;

  insert into public.limpeza_execucoes (modo, resultado) values (v_modo, v_resultado);
  return v_resultado || pg_catalog.jsonb_build_object('modo', v_modo);
end;
$$;

-- O dono da plataforma confirma: 'valendo' passa a apagar de verdade;
-- 'simulacao' volta a só anotar. Só o servidor (SQL Editor) usa.
create or replace function public.definir_modo_limpeza(p_modo text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_modo is null or p_modo not in ('simulacao', 'valendo') then
    perform public.erro('Use simulacao ou valendo.', 'modo_invalido');
  end if;
  insert into public.configuracao_plataforma (chave, valor, atualizado_em)
  values ('limpeza_modo', p_modo, pg_catalog.now())
  on conflict (chave) do update set valor = excluded.valor, atualizado_em = excluded.atualizado_em;
  return pg_catalog.jsonb_build_object('limpeza_modo', p_modo);
end;
$$;

-- ------------------------------------------------------------ privilégios

revoke all on function public.expurgar_perfil(uuid) from public, anon, authenticated;
revoke all on function public.expurgar_motorista(uuid, boolean) from public, anon, authenticated;
revoke all on function public.expurgar_empresa(uuid, text) from public, anon, authenticated;
revoke all on function public.excluir_motorista(uuid) from public, anon;
revoke all on function public.excluir_minha_conta() from public, anon;
revoke all on function public.excluir_minha_empresa(text) from public, anon;
revoke all on function public.limpeza_diaria(text) from public, anon, authenticated;
revoke all on function public.definir_modo_limpeza(text) from public, anon, authenticated;
revoke all on function public.papel_do_usuario() from public, anon, authenticated;
revoke all on function public.excluir_empresa_plataforma(uuid) from public, anon, authenticated;

grant execute on function public.excluir_motorista(uuid) to authenticated;
grant execute on function public.excluir_minha_conta() to authenticated;
grant execute on function public.excluir_minha_empresa(text) to authenticated;
grant execute on function public.limpeza_diaria(text) to service_role;
grant execute on function public.definir_modo_limpeza(text) to service_role;
grant execute on function public.excluir_empresa_plataforma(uuid) to service_role;

-- ---------------------------------------------------- limpeza todo dia (pg_cron)

-- Onde o pg_cron existe (Supabase), agenda a limpeza diária às 03:20 de
-- Brasília (06:20 UTC). Ela começa em modo simulação (ver acima). Num
-- PostgreSQL sem pg_cron (testes locais), pula.
do $$
begin
  if exists (select 1 from pg_catalog.pg_available_extensions where name = 'pg_cron') then
    create extension if not exists pg_cron;
    perform cron.schedule('frota-limpeza-diaria', '20 6 * * *', 'select public.limpeza_diaria()');
  end if;
exception when others then
  raise warning 'limpeza diária não agendada (pg_cron): %', sqlerrm;
end;
$$;
