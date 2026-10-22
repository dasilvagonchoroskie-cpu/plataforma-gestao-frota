-- Teste da exclusão no banco da nuvem SEM deixar nada gravado.
--
-- Cria uma empresa e dois motoristas de teste, confere a limpeza em modo
-- simulação, a exclusão da empresa pela plataforma e a exclusão da própria
-- conta por um motorista sem empresa. No fim, levanta um erro de propósito:
-- o PostgreSQL desfaz tudo o que este bloco fez (nada fica gravado) e o
-- resultado aparece na mensagem do erro. Não mexe em nenhuma empresa real.
do $$
declare
  v_emp uuid;
  v_uid uuid := pg_catalog.gen_random_uuid();
  v_uid2 uuid := pg_catalog.gen_random_uuid();
  v_mot uuid := pg_catalog.gen_random_uuid();
  v_sim jsonb;
  v_antes jsonb;
  v_depois jsonb;
  v_saida text;
  v_conta jsonb;
begin
  -- Contagens das empresas reais antes do teste.
  select pg_catalog.jsonb_object_agg(e.id, pg_catalog.jsonb_build_array(
           (select count(*) from public.motoristas m where m.empresa_id = e.id),
           (select count(*) from public.caminhoes c where c.empresa_id = e.id),
           (select count(*) from public.fretes f where f.empresa_id = e.id),
           (select count(*) from public.perfis p where p.empresa_id = e.id)))
    into v_antes
  from public.empresas e where e.excluida_em is null;

  v_emp := (public.criar_empresa('Teste de exclusão (desfeito)', 'teste.exclusao@exemplo.invalid') ->> 'empresa_id')::uuid;
  insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, recovery_token,
    email_change_token_new, email_change, phone_change, phone_change_token, email_change_token_current,
    reauthentication_token)
  values
    ('00000000-0000-0000-0000-000000000000', v_uid, 'authenticated', 'authenticated', 'teste.mot1@exemplo.invalid',
     '-', pg_catalog.now(), '{}', '{}', pg_catalog.now(), pg_catalog.now(), '', '', '', '', '', '', '', ''),
    ('00000000-0000-0000-0000-000000000000', v_uid2, 'authenticated', 'authenticated', 'teste.mot2@exemplo.invalid',
     '-', pg_catalog.now(), '{}', '{}', pg_catalog.now(), pg_catalog.now(), '', '', '', '', '', '', '', '');
  insert into public.perfis (id, empresa_id, papel, nome, cpf, email) values
    (v_uid, v_emp, 'motorista', 'Motorista Teste 1', '13579246828', 'teste.mot1@exemplo.invalid'),
    (v_uid2, null, 'motorista', 'Motorista Teste 2', '98765432100', 'teste.mot2@exemplo.invalid');
  insert into public.motoristas (id, empresa_id, perfil_id, nome, cpf, email)
  values (v_mot, v_emp, v_uid, 'Motorista Teste 1', '13579246828', 'teste.mot1@exemplo.invalid');
  insert into public.vales (id, empresa_id, motorista_id, data, valor_centavos)
  values (pg_catalog.gen_random_uuid(), v_emp, v_mot, pg_catalog.now(), 10000);

  perform public.bloquear_empresa(v_emp, 'Teste', 0);
  v_sim := public.limpeza_diaria('simulacao');
  perform public.excluir_empresa_plataforma(v_emp);

  perform pg_catalog.set_config('request.jwt.claims',
    pg_catalog.json_build_object('sub', v_uid2, 'role', 'authenticated')::text, true);
  v_conta := public.excluir_minha_conta();
  perform pg_catalog.set_config('request.jwt.claims', '', true);

  select pg_catalog.jsonb_object_agg(e.id, pg_catalog.jsonb_build_array(
           (select count(*) from public.motoristas m where m.empresa_id = e.id),
           (select count(*) from public.caminhoes c where c.empresa_id = e.id),
           (select count(*) from public.fretes f where f.empresa_id = e.id),
           (select count(*) from public.perfis p where p.empresa_id = e.id)))
    into v_depois
  from public.empresas e where e.excluida_em is null;

  v_saida := pg_catalog.format(
    'simulacao_listou_teste=%s | simulacao_listou_outras=%s | vales_teste=%s | motoristas_teste=%s | '
    'perfis_e_logins_teste=%s | nome_empresa_teste=%s | registro_plataforma=%s | conta_sem_empresa_apagada=%s | '
    'registro_conta=%s | empresas_reais_intactas=%s | limpeza_modo=%s',
    (v_sim -> 'empresas') ? v_emp::text,
    pg_catalog.jsonb_array_length(v_sim -> 'empresas') - 1,
    (select count(*) from public.vales v where v.empresa_id = v_emp),
    (select count(*) from public.motoristas m where m.empresa_id = v_emp),
    (select count(*) from public.perfis p where p.id in (v_uid, v_uid2))
      + (select count(*) from auth.users u where u.id in (v_uid, v_uid2)),
    (select e.nome from public.empresas e where e.id = v_emp),
    (select count(*) from public.registro_exclusoes r where r.empresa_id = v_emp and r.pedido_por = 'plataforma'),
    v_conta ->> 'apagada',
    (select count(*) from public.registro_exclusoes r
      where r.empresa_id is null and r.tipo = 'conta_motorista' and r.quando = pg_catalog.now()),
    v_antes = v_depois,
    (select c.valor from public.configuracao_plataforma c where c.chave = 'limpeza_modo'));
  raise exception 'RESULTADO (tudo desfeito): %', v_saida;
end;
$$;
