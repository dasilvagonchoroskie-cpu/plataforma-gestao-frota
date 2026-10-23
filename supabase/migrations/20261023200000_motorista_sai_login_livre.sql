-- aprovado-por: Evandro em 23/10/2026 (motorista que sai da empresa — desligado pela empresa ou que excluiu a conta — tem o login solto na hora e o e-mail apagado do registro da empresa, inclusive do histórico; o registro fica com nome, CPF e lançamentos; quem volta começa um cadastro novo)
--
-- Motorista que sai da empresa fica com o login livre na hora.
--
-- Pedido do Evandro (23/10/2026): motorista sai hoje e volta em 3 dias, ou vai
-- para outra empresa que também usa a plataforma. O login (CPF, senha e
-- e-mail) não pode ficar preso à empresa de onde ele saiu.
-- * Desligar o motorista solta o login na hora: ele pode entrar em outra
--   empresa ou voltar com um código novo.
-- * A empresa fica com o registro de quem trabalhou: nome, CPF e todos os
--   lançamentos (caminhão e período). O e-mail sai do registro e do histórico.
-- * Quem volta para a mesma empresa começa um cadastro novo; o registro
--   antigo fica separado (o mesmo CPF pode aparecer em registros sem login).
-- * Quem excluiu a conta continua com o prazo de 15 dias para os lançamentos.

-- ------------------------------------------------------------- estrutura

alter table public.motoristas drop constraint motoristas_cpf_empresa_unique;
create unique index motoristas_cpf_empresa_com_login_uk
  on public.motoristas (empresa_id, cpf) where perfil_id is not null;
alter table public.motoristas alter column email drop not null;
alter table public.motoristas add column desligado_em timestamptz;

-- ------------------------------------------- soltar o login do cadastro

-- Antes de gravar: desligado não fica com login; sem login, sem e-mail.
create or replace function public.motoristas_soltar_login()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if not new.ativo and new.perfil_id is not null then
    new.perfil_id := null;
  end if;
  if old.perfil_id is not null and new.perfil_id is null then
    new.email := null;
    new.desligado_em := coalesce(new.desligado_em, pg_catalog.now());
  end if;
  return new;
end;
$$;

-- Depois de gravar: o login sai da empresa (celulares e quem registrou o
-- caminhão) e o e-mail sai do histórico deste cadastro.
create or replace function public.motoristas_soltar_login_depois()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.perfil_id is not null and new.perfil_id is null then
    update public.uso_caminhao set registrado_por = null
     where empresa_id = old.empresa_id and registrado_por = old.perfil_id;
    delete from public.dispositivos where empresa_id = old.empresa_id and perfil_id = old.perfil_id;
    update public.perfis set empresa_id = null
     where id = old.perfil_id and empresa_id = old.empresa_id;
    update public.auditoria set antes = antes - 'email', depois = depois - 'email'
     where empresa_id = old.empresa_id and tabela = 'motoristas' and registro_id = old.id;
  end if;
  return null;
end;
$$;

revoke all on function public.motoristas_soltar_login() from public, anon, authenticated;
revoke all on function public.motoristas_soltar_login_depois() from public, anon, authenticated;

-- Os nomes garantem a ordem: o histórico (motoristas_auditoria) grava antes
-- e a limpeza do e-mail (motoristas_soltar_login_depois) vem depois.
create trigger motoristas_soltar_login before update on public.motoristas
  for each row execute function public.motoristas_soltar_login();
create trigger motoristas_soltar_login_depois after update on public.motoristas
  for each row execute function public.motoristas_soltar_login_depois();

-- ------------------------------------------------- quem já tinha saído

-- Desligados que ainda tinham login: soltam agora. Registros que já estavam
-- sem login (conta excluída): o e-mail sai do registro e do histórico.
update public.motoristas set ativo = false where not ativo and perfil_id is not null;
update public.motoristas set email = null where perfil_id is null and email is not null;
update public.auditoria a set antes = a.antes - 'email', depois = a.depois - 'email'
  from public.motoristas m
 where m.perfil_id is null and a.empresa_id = m.empresa_id and a.tabela = 'motoristas' and a.registro_id = m.id;

-- Cadastro com login é cadastro ativo, e vice-versa.
alter table public.motoristas drop constraint motoristas_ativo_tem_login_ck;
alter table public.motoristas add constraint motoristas_ativo_e_login_ck
  check (ativo = (perfil_id is not null));

-- --------------------------------------------- código para quem voltou

-- Igual à anterior, sem recusar quem já saiu da empresa: ganha cadastro novo.
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
  -- Quem saiu (desligado ou que excluiu a conta) pode voltar: começa um
  -- cadastro novo; o registro antigo fica separado.

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

-- ---------------------------------------- aprovar a entrada de quem voltou

-- Igual à primeira versão: quem voltou com conta nova ganha cadastro novo.
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

-- ------------------------------------------------ redefinir sem login

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
    perform public.erro('Este motorista não tem mais login na empresa (saiu ou excluiu a conta). Se ele voltar, gere um código novo para ele.',
      'sem_login');
  end if;
  if v_resultado is null then
    perform public.erro('Motorista não encontrado.', 'motorista_inexistente');
  end if;
  return v_resultado;
end;
$$;

-- -------------------------------------------- pedir entrada (texto novo)

-- Igual à anterior, com o texto certo para quem ainda está numa empresa.
create or replace function public.pedir_entrada(p_codigo text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_perfil public.perfis;
  v_codigo text := pg_catalog.upper(pg_catalog.regexp_replace(coalesce(p_codigo, ''), '[^A-Za-z0-9]', '', 'g'));
  v_empresa public.empresas;
  v_convite public.convites_motorista;
  v_erros integer;
  v_pedido public.pedidos_entrada;
  v_motorista_id uuid;
begin
  select * into v_perfil from public.perfis p where p.id = v_uid and p.apagado_em is null;
  if not found then
    perform public.erro('Termine o seu cadastro antes.', 'sem_perfil');
  end if;
  if v_perfil.papel <> 'motorista' then
    perform public.erro('Esta conta é de gestor. Use o app do gestor.', 'nao_motorista');
  end if;
  if v_perfil.empresa_id is not null then
    perform public.erro('Você já está ligado a uma empresa. Para trocar, peça à empresa atual para desligar você; o seu login fica livre na hora.',
      'ja_vinculado');
  end if;
  if not v_perfil.ativo then
    perform public.erro('Esta conta está sendo excluída.', 'conta_excluida');
  end if;

  select count(*) into v_erros from public.tentativas_acesso t
  where t.tipo = 'codigo_empresa' and t.chave = v_uid::text and not t.sucesso
    and t.criado_em > pg_catalog.now() - interval '15 minutes';
  if v_erros >= 10 then
    return pg_catalog.jsonb_build_object('ok', false, 'codigo', 'muitas_tentativas',
      'mensagem', 'Muitas tentativas. Espere 15 minutos e tente de novo.');
  end if;

  -- 1) Código individual gerado pelo gestor para este motorista.
  select * into v_convite from public.convites_motorista c
  where c.codigo = v_codigo and c.apagado_em is null
  for update;
  if found then
    if v_convite.usado_em is not null or v_convite.cancelado_em is not null
       or v_convite.expira_em <= pg_catalog.now() then
      insert into public.tentativas_acesso (tipo, chave, sucesso) values ('codigo_empresa', v_uid::text, false);
      return pg_catalog.jsonb_build_object('ok', false, 'codigo', 'convite_vencido',
        'mensagem', 'Este código já foi usado, foi cancelado ou venceu. Peça um código novo ao seu patrão.');
    end if;
    if v_convite.cpf <> v_perfil.cpf then
      insert into public.tentativas_acesso (tipo, chave, sucesso) values ('codigo_empresa', v_uid::text, false);
      return pg_catalog.jsonb_build_object('ok', false, 'codigo', 'cpf_diferente',
        'mensagem', 'Este código foi feito para outro CPF. Peça ao seu patrão para conferir o seu CPF no cadastro.');
    end if;
    select * into v_empresa from public.empresas e where e.id = v_convite.empresa_id;
    if not public.empresa_liberada(v_empresa.id) or v_empresa.status = 'suspensa' then
      return pg_catalog.jsonb_build_object('ok', false, 'codigo', 'empresa_indisponivel',
        'mensagem', 'A empresa não está usando a plataforma agora. Fale com o seu patrão.');
    end if;
    insert into public.tentativas_acesso (tipo, chave, sucesso) values ('codigo_empresa', v_uid::text, true);

    update public.perfis set empresa_id = v_empresa.id, ativo = true where id = v_uid;
    v_motorista_id := pg_catalog.gen_random_uuid();
    insert into public.motoristas (id, empresa_id, perfil_id, nome, cpf, email)
    values (v_motorista_id, v_empresa.id, v_uid, v_convite.nome, v_perfil.cpf, v_perfil.email);

    update public.pedidos_entrada set status = 'recusado', decidido_em = pg_catalog.now()
    where perfil_id = v_uid and status = 'pendente';
    insert into public.pedidos_entrada (empresa_id, perfil_id, status, decidido_por, decidido_em)
    values (v_empresa.id, v_uid, 'aprovado',
      (select p.id from public.perfis p where p.id = v_convite.criado_por and p.empresa_id = v_empresa.id),
      pg_catalog.now())
    returning * into v_pedido;
    update public.convites_motorista set usado_por = v_uid, usado_em = pg_catalog.now()
    where id = v_convite.id;

    return pg_catalog.jsonb_build_object('ok', true, 'status', 'aprovado', 'pedido_id', v_pedido.id,
      'empresa_nome', v_empresa.nome, 'motorista_id', v_motorista_id);
  end if;

  -- 2) Código da empresa: vira pedido para o gestor aprovar.
  select * into v_empresa from public.empresas e
  where e.codigo_entrada = v_codigo and e.apagado_em is null and e.status <> 'suspensa'
    and public.empresa_liberada(e.id);
  if not found then
    insert into public.tentativas_acesso (tipo, chave, sucesso) values ('codigo_empresa', v_uid::text, false);
    return pg_catalog.jsonb_build_object('ok', false, 'codigo', 'codigo_invalido',
      'mensagem', 'Código não encontrado. Confira com o seu patrão.');
  end if;
  insert into public.tentativas_acesso (tipo, chave, sucesso) values ('codigo_empresa', v_uid::text, true);

  select * into v_pedido from public.pedidos_entrada pe
  where pe.perfil_id = v_uid and pe.empresa_id = v_empresa.id and pe.status = 'pendente';
  if not found then
    insert into public.pedidos_entrada (empresa_id, perfil_id, status)
    values (v_empresa.id, v_uid, 'pendente')
    returning * into v_pedido;
  end if;
  return pg_catalog.jsonb_build_object('ok', true, 'pedido_id', v_pedido.id,
    'empresa_nome', v_empresa.nome, 'status', v_pedido.status);
end;
$$;
