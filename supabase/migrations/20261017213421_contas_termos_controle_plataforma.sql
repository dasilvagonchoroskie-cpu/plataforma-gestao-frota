-- Contas, termos e controle da plataforma (parte 3 de 4): controle da plataforma.
-- Só o servidor (service_role) usa estas funções. Explicação completa na parte 2.

-- ------------------------------------------- controle da plataforma (servidor)

-- Encerra o acesso de uma empresa (fim do teste, falta de pagamento...). Os
-- dados são apagados depois de p_dias_ate_excluir dias (nulo = não apaga sozinho).
create or replace function public.bloquear_empresa(
  p_empresa uuid,
  p_motivo text default 'O período de teste terminou.',
  p_dias_ate_excluir integer default 30
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_empresa public.empresas;
begin
  update public.empresas
     set bloqueada_em = coalesce(bloqueada_em, pg_catalog.now()),
         motivo_bloqueio = pg_catalog.left(coalesce(nullif(pg_catalog.btrim(p_motivo), ''), 'Acesso encerrado.'), 200),
         excluir_em = case when p_dias_ate_excluir is null then null
                           else pg_catalog.now() + pg_catalog.make_interval(days => p_dias_ate_excluir) end
   where id = p_empresa and excluida_em is null
  returning * into v_empresa;
  if not found then
    perform public.erro('Empresa não encontrada.', 'empresa_inexistente');
  end if;
  return pg_catalog.jsonb_build_object('empresa', v_empresa.nome, 'bloqueada_em', v_empresa.bloqueada_em,
    'excluir_em', v_empresa.excluir_em);
end;
$$;

-- Libera de novo (ou define o fim do teste com p_acesso_ate; nulo = sem prazo).
create or replace function public.liberar_empresa(p_empresa uuid, p_acesso_ate timestamptz default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_empresa public.empresas;
begin
  update public.empresas
     set bloqueada_em = null, motivo_bloqueio = null, excluir_em = null, acesso_ate = p_acesso_ate
   where id = p_empresa and excluida_em is null
  returning * into v_empresa;
  if not found then
    perform public.erro('Empresa não encontrada.', 'empresa_inexistente');
  end if;
  return pg_catalog.jsonb_build_object('empresa', v_empresa.nome, 'acesso_ate', v_empresa.acesso_ate);
end;
$$;

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
  return pg_catalog.jsonb_build_object('ok', true);
end;
$$;

-- Visão geral para o dono da plataforma (SQL Editor do Supabase).
create or replace function public.empresas_da_plataforma()
returns table (
  empresa_id uuid,
  nome text,
  email_dono text,
  situacao text,
  acesso_ate timestamptz,
  excluir_em timestamptz,
  motoristas integer,
  caminhoes integer,
  ultimo_envio timestamptz,
  criada_em timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select e.id, e.nome,
    (select a.email from public.acessos_autorizados a
      where a.empresa_id = e.id and a.papel = 'dono' and a.apagado_em is null order by a.criado_em limit 1),
    case when e.excluida_em is not null then 'excluída'
         when e.bloqueada_em is not null then 'bloqueada'
         when e.acesso_ate is not null and e.acesso_ate <= pg_catalog.now() then 'teste vencido'
         when e.status = 'suspensa' then 'suspensa'
         else 'liberada' end,
    e.acesso_ate,
    case when e.excluida_em is not null then null
         when e.excluir_em is not null then e.excluir_em
         when e.bloqueada_em is null and e.acesso_ate is not null then e.acesso_ate + interval '30 days' end,
    (select count(*)::integer from public.motoristas m where m.empresa_id = e.id and m.ativo),
    (select count(*)::integer from public.caminhoes c where c.empresa_id = e.id and c.ativo and c.apagado_em is null),
    (select pg_catalog.max(d.ultimo_sync_em) from public.dispositivos d where d.empresa_id = e.id),
    e.criado_em
  from public.empresas e
  order by e.criado_em
$$;

-- ------------------------------------------------------------ privilégios

revoke all on function public.bloquear_empresa(uuid, text, integer) from public, anon, authenticated;
revoke all on function public.liberar_empresa(uuid, timestamptz) from public, anon, authenticated;
revoke all on function public.excluir_empresa_plataforma(uuid) from public, anon, authenticated;
revoke all on function public.empresas_da_plataforma() from public, anon, authenticated;

grant execute on function public.bloquear_empresa(uuid, text, integer) to service_role;
grant execute on function public.liberar_empresa(uuid, timestamptz) to service_role;
grant execute on function public.excluir_empresa_plataforma(uuid) to service_role;
grant execute on function public.empresas_da_plataforma() to service_role;
