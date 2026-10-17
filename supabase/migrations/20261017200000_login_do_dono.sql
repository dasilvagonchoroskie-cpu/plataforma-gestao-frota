-- Login do dono criado pela plataforma, sem depender de e-mail.
--
-- Para o piloto não precisar do envio de e-mail (código de cadastro), quem
-- opera a plataforma cria o acesso do dono com uma senha provisória e passa
-- para ele; no primeiro login o app pede para trocar (trocar_senha).
-- Gestores e motoristas são criados pelas Edge Functions criar_acesso_gestor
-- e cadastrar_motorista (API oficial do Supabase Auth).
-- Só o servidor (service_role) executa.

create or replace function public.criar_login_dono(p_email text, p_nome text, p_senha text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_email text := pg_catalog.lower(pg_catalog.btrim(coalesce(p_email, '')));
  v_nome text := pg_catalog.btrim(coalesce(p_nome, ''));
  v_empresa uuid;
  v_id uuid;
begin
  select a.empresa_id into v_empresa from public.acessos_autorizados a
  where a.email = v_email and a.papel = 'dono' and a.ativo and a.apagado_em is null
  order by a.criado_em
  limit 1;
  if v_empresa is null then
    perform public.erro('Este e-mail não está liberado como dono de nenhuma empresa.', 'nao_autorizado');
  end if;
  if pg_catalog.length(coalesce(p_senha, '')) < 6 then
    perform public.erro('A senha precisa ter pelo menos 6 letras ou números.', 'senha_curta');
  end if;
  if pg_catalog.length(v_nome) < 2 then
    perform public.erro('Escreva o nome do dono.', 'nome_invalido');
  end if;

  select u.id into v_id from auth.users u where pg_catalog.lower(u.email) = v_email limit 1;
  if v_id is null then
    v_id := pg_catalog.gen_random_uuid();
    insert into auth.users (
      instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
      raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
      confirmation_token, recovery_token, email_change_token_new, email_change,
      phone_change, phone_change_token, email_change_token_current, reauthentication_token)
    values (
      '00000000-0000-0000-0000-000000000000', v_id, 'authenticated', 'authenticated', v_email,
      extensions.crypt(p_senha, extensions.gen_salt('bf')), pg_catalog.now(),
      '{"provider": "email", "providers": ["email"]}'::jsonb, '{"trocar_senha": true}'::jsonb,
      pg_catalog.now(), pg_catalog.now(), '', '', '', '', '', '', '', '');
    insert into auth.identities (provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
    values (v_id::text, v_id,
      pg_catalog.jsonb_build_object('sub', v_id::text, 'email', v_email, 'email_verified', true, 'phone_verified', false),
      'email', pg_catalog.now(), pg_catalog.now(), pg_catalog.now());
  else
    update auth.users u
       set encrypted_password = extensions.crypt(p_senha, extensions.gen_salt('bf')),
           email_confirmed_at = coalesce(u.email_confirmed_at, pg_catalog.now()),
           raw_user_meta_data = coalesce(u.raw_user_meta_data, '{}'::jsonb) || '{"trocar_senha": true}'::jsonb,
           updated_at = pg_catalog.now()
     where u.id = v_id;
  end if;

  insert into public.perfis (id, empresa_id, papel, nome, email)
  values (v_id, v_empresa, 'dono', v_nome, v_email)
  on conflict (id) do update
    set empresa_id = excluded.empresa_id, papel = 'dono', ativo = true, apagado_em = null;

  return pg_catalog.jsonb_build_object('usuario_id', v_id, 'empresa_id', v_empresa, 'email', v_email);
end;
$$;

revoke all on function public.criar_login_dono(text, text, text) from public, anon, authenticated;
grant execute on function public.criar_login_dono(text, text, text) to service_role;
