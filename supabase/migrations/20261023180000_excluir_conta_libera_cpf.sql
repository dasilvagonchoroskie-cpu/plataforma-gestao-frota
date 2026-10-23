-- aprovado-por: Evandro em 23/10/2026 (motorista que exclui a própria conta: o login sai na hora e o CPF fica livre para uma conta nova; os lançamentos ficam 15 dias com a empresa e depois são apagados)
--
-- Exclusão da conta pelo motorista libera o CPF na hora.
--
-- * Antes: o motorista de uma empresa que excluía a conta ficava 15 dias com
--   o login e o CPF presos (a empresa tinha esse prazo para guardar o PDF).
--   Quem tentava criar conta nova com o mesmo CPF era recusado.
-- * Agora (pedido do Evandro em 23/10/2026): o login (conta, CPF e e-mail)
--   é apagado na hora. O cadastro do motorista na empresa e os lançamentos
--   ficam 15 dias, marcados como "excluiu a conta", para a empresa baixar o
--   PDF; depois a limpeza diária apaga, como antes. O gestor também pode
--   apagar antes (com o PDF) em Motoristas > Excluir motorista e dados.
-- * Cadastro na empresa sem login não pode ser religado.

alter table public.motoristas alter column perfil_id drop not null;
alter table public.motoristas add column exclusao_pedida_em timestamptz;
alter table public.motoristas add constraint motoristas_ativo_tem_login_ck
  check (not ativo or perfil_id is not null);

-- ------------------------------------------------- excluir a própria conta

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
  -- O cadastro na empresa fica sem login, marcado, por 15 dias.
  update public.motoristas
     set ativo = false, exclusao_pedida_em = pg_catalog.now(), perfil_id = null
   where id = v_motorista;
  perform public.expurgar_perfil(v_uid);
  return pg_catalog.jsonb_build_object('ok', true, 'apagada', false, 'login_apagado', true,
    'apagar_em', pg_catalog.now() + interval '15 days');
end;
$$;

-- ------------------------------------- limpeza diária (o prazo é do cadastro)

-- Igual à anterior; os motoristas vencidos agora são os cadastros marcados
-- quando o motorista excluiu a conta (o login já foi apagado na hora).
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
  from public.motoristas m
  where m.exclusao_pedida_em <= pg_catalog.now() - interval '15 days'
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
      perform public.expurgar_motorista((v_item ->> 'motorista_id')::uuid, false);
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

-- --------------------------------------- pedidos de exclusão já feitos

-- Quem já tinha pedido para excluir a conta: o login sai agora e o prazo dos
-- lançamentos continua contando da data do pedido.
do $$
declare
  r record;
begin
  for r in select p.id as perfil_id, p.exclusao_pedida_em, m.id as motorista_id
           from public.perfis p join public.motoristas m on m.perfil_id = p.id
           where p.exclusao_pedida_em is not null loop
    update public.motoristas
       set ativo = false, exclusao_pedida_em = r.exclusao_pedida_em, perfil_id = null
     where id = r.motorista_id;
    perform public.expurgar_perfil(r.perfil_id);
  end loop;
end;
$$;

-- --------------------------------------- código para quem excluiu a conta

-- Igual à anterior, com o aviso certo quando o cadastro antigo é de alguém
-- que excluiu a conta (ainda dentro dos 15 dias).
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
  if exists (select 1 from public.motoristas m where m.empresa_id = v_empresa and m.cpf = v_cpf
             and m.exclusao_pedida_em is not null) then
    perform public.erro('Este motorista excluiu a conta. O cadastro antigo fica até '
      || pg_catalog.to_char((select max(m.exclusao_pedida_em) from public.motoristas m
           where m.empresa_id = v_empresa and m.cpf = v_cpf) at time zone 'America/Sao_Paulo'
           + interval '15 days', 'DD/MM')
      || ' para a empresa guardar o PDF. Para cadastrar de novo agora, abra o nome dele em Motoristas e use "Excluir motorista e dados".',
      'motorista_excluiu_conta');
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

-- ------------------------------- aprovar a entrada de quem excluiu a conta

-- Igual à anterior; quem excluiu a conta e volta com conta nova esbarrava no
-- cadastro antigo (mesmo CPF na empresa). Agora vem o aviso do que fazer.
create or replace function public.decidir_entrada(p_pedido_id uuid, p_aprovar boolean)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_empresa uuid := public.empresa_do_usuario();
  v_pedido public.pedidos_entrada;
  v_perfil public.perfis;
  v_motorista_id uuid;
begin
  if not public.eh_gestor_ou_dono() then
    perform public.erro('Só o dono ou o gestor podem aprovar motoristas.', 'sem_permissao', '42501');
  end if;
  select * into v_pedido from public.pedidos_entrada pe
  where pe.id = p_pedido_id and pe.empresa_id = v_empresa
  for update;
  if not found then
    perform public.erro('Pedido não encontrado.', 'pedido_inexistente');
  end if;
  if v_pedido.status <> 'pendente' then
    perform public.erro('Este pedido já foi decidido.', 'pedido_decidido');
  end if;

  if not p_aprovar then
    update public.pedidos_entrada set status = 'recusado', decidido_por = v_uid,
      decidido_em = pg_catalog.now() where id = v_pedido.id;
    return pg_catalog.jsonb_build_object('ok', true, 'status', 'recusado');
  end if;

  select * into v_perfil from public.perfis p where p.id = v_pedido.perfil_id for update;
  if v_perfil.empresa_id is not null and v_perfil.empresa_id <> v_empresa then
    update public.pedidos_entrada set status = 'recusado', decidido_por = v_uid,
      decidido_em = pg_catalog.now() where id = v_pedido.id;
    perform public.erro('Este motorista já entrou em outra empresa.', 'outra_empresa');
  end if;

  update public.perfis set empresa_id = v_empresa, ativo = true where id = v_perfil.id;

  select m.id into v_motorista_id from public.motoristas m where m.perfil_id = v_perfil.id;
  if v_motorista_id is null and exists (select 1 from public.motoristas m
       where m.empresa_id = v_empresa and m.cpf = v_perfil.cpf) then
    perform public.erro('Este motorista excluiu a conta antiga e o cadastro antigo dele ainda está na empresa'
      || coalesce(' (fica até ' || pg_catalog.to_char((select max(m.exclusao_pedida_em) from public.motoristas m
           where m.empresa_id = v_empresa and m.cpf = v_perfil.cpf) at time zone 'America/Sao_Paulo'
           + interval '15 days', 'DD/MM') || ' para a empresa guardar o PDF)', '')
      || '. Para aprovar agora, abra o nome dele em Motoristas, use "Excluir motorista e dados" e depois aprove de novo.',
      'motorista_excluiu_conta');
  end if;
  if v_motorista_id is null then
    v_motorista_id := pg_catalog.gen_random_uuid();
    insert into public.motoristas (id, empresa_id, perfil_id, nome, cpf, email)
    values (v_motorista_id, v_empresa, v_perfil.id, v_perfil.nome, v_perfil.cpf, v_perfil.email);
  else
    update public.motoristas set ativo = true, apagado_em = null where id = v_motorista_id;
  end if;

  update public.pedidos_entrada set status = 'aprovado', decidido_por = v_uid,
    decidido_em = pg_catalog.now() where id = v_pedido.id;
  -- Outros pedidos esperando (para outras empresas) deixam de valer.
  update public.pedidos_entrada set status = 'recusado', decidido_em = pg_catalog.now()
  where perfil_id = v_perfil.id and status = 'pendente' and id <> v_pedido.id;

  return pg_catalog.jsonb_build_object('ok', true, 'status', 'aprovado', 'motorista_id', v_motorista_id);
end;
$$;

-- ------------------------------------ redefinir acesso de quem excluiu

create or replace function public.perfil_para_redefinir(p_motorista_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_resultado jsonb;
begin
  if not public.eh_gestor_ou_dono() then
    perform public.erro('Só o dono ou o gestor podem redefinir o acesso.', 'sem_permissao', '42501');
  end if;
  select pg_catalog.jsonb_build_object('perfil_id', m.perfil_id, 'nome', m.nome, 'email', p.email,
           'empresa_id', m.empresa_id)
    into v_resultado
  from public.motoristas m join public.perfis p on p.id = m.perfil_id
  where m.id = p_motorista_id and m.empresa_id = public.empresa_do_usuario();
  if v_resultado is null and exists (select 1 from public.motoristas m
       where m.id = p_motorista_id and m.empresa_id = public.empresa_do_usuario() and m.perfil_id is null) then
    perform public.erro('Este motorista excluiu a conta. Não tem acesso para redefinir; se ele voltar, cria uma conta nova.',
      'motorista_excluiu_conta');
  end if;
  if v_resultado is null then
    perform public.erro('Motorista não encontrado.', 'motorista_inexistente');
  end if;
  return v_resultado;
end;
$$;
