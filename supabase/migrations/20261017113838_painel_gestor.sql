-- Apoio ao painel do gestor (Fases 5 e 6).
--
-- pedidos_entrada_da_empresa: o motorista que pede entrada ainda não é da
-- empresa, então o RLS de perfis não deixa o gestor ver o nome e o CPF dele.
-- Esta função mostra só isso, só para a gestão da própria empresa, com os
-- pedidos pendentes e os decididos nos últimos 30 dias.

create or replace function public.pedidos_entrada_da_empresa()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.eh_gestor_ou_dono() then
    perform public.erro('Só o dono ou o gestor podem ver os pedidos de entrada.', 'sem_permissao', '42501');
  end if;
  return coalesce((
    select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'id', pe.id, 'status', pe.status, 'pedido_em', pe.pedido_em, 'decidido_em', pe.decidido_em,
        'perfil_id', p.id, 'nome', p.nome, 'cpf', p.cpf, 'email', p.email)
      order by pe.pedido_em desc)
    from public.pedidos_entrada pe
    join public.perfis p on p.id = pe.perfil_id
    where pe.empresa_id = public.empresa_do_usuario()
      and pe.apagado_em is null
      and (pe.status = 'pendente' or pe.decidido_em > pg_catalog.now() - interval '30 days')
  ), '[]'::jsonb);
end;
$$;

revoke all on function public.pedidos_entrada_da_empresa() from public, anon;
grant execute on function public.pedidos_entrada_da_empresa() to authenticated;
