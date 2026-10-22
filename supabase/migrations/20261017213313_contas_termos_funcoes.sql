-- Contas, termos e controle da plataforma (parte 2 de 3): permissões e funções.
--
-- 1. Código individual por motorista: o gestor cadastra o motorista (nome e
--    CPF) e o painel gera um código único, de uso único, que vale 7 dias e só
--    serve para aquele CPF. O motorista entra na empresa na hora.
-- 2. Código de recuperação: cada pessoa guarda um código para criar uma senha
--    nova sem depender de e-mail (Edge Function recuperar_acesso).
-- 3. Termos de Uso e Política de Privacidade: o aceite (versão, data e IP)
--    fica guardado.
-- 4. Exclusão de conta e dados: o dono exclui a empresa inteira; a gestão
--    exclui um motorista e os lançamentos dele; o motorista exclui a própria
--    conta (ligado a uma empresa, a exclusão completa acontece em até 15 dias).
-- 5. Controle da plataforma (só o servidor): fim do teste, bloqueio,
--    liberação e exclusão automática dos dados depois do fim do acesso.
--    Empresa bloqueada ou com o teste vencido não acessa nada pelos apps.
-- 6. Registros de acesso (data, hora e IP) guardados por 6 meses
--    (Marco Civil da Internet, art. 15).
--
-- Esta migration só cria objetos ou troca funções (nada da estrutura é apagado).

-- ------------------------------------------------ empresa liberada ou não

-- A empresa pode usar a plataforma: não excluída, não bloqueada e dentro do
-- prazo de acesso (teste). Todas as permissões passam por aqui.
create or replace function public.empresa_liberada(p_empresa uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.empresas e
    where e.id = p_empresa and e.apagado_em is null and e.bloqueada_em is null
      and (e.acesso_ate is null or e.acesso_ate > pg_catalog.now())
  )
$$;

create or replace function public.empresa_do_usuario()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select p.empresa_id
  from public.perfis p
  where p.id = (select auth.uid()) and p.ativo and p.apagado_em is null
    and public.empresa_liberada(p.empresa_id)
  limit 1
$$;

create or replace function public.eh_dono()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.perfis p
    where p.id = (select auth.uid()) and p.papel = 'dono'
      and p.ativo and p.apagado_em is null and p.empresa_id is not null
      and public.empresa_liberada(p.empresa_id)
  )
$$;

create or replace function public.eh_gestor_ou_dono()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.perfis p
    where p.id = (select auth.uid()) and p.papel in ('gestor', 'dono')
      and p.ativo and p.apagado_em is null and p.empresa_id is not null
      and public.empresa_liberada(p.empresa_id)
  )
$$;

create or replace function public.motorista_do_usuario()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select m.id
  from public.motoristas m
  join public.perfis p on p.id = m.perfil_id and p.empresa_id = m.empresa_id
  where p.id = (select auth.uid()) and p.papel = 'motorista'
    and p.ativo and p.apagado_em is null and m.ativo and m.apagado_em is null
    and public.empresa_liberada(m.empresa_id)
  limit 1
$$;

-- ------------------------------------------------------------ utilidades

-- IP de quem chamou (cabeçalho da requisição que o Supabase repassa).
create or replace function public.ip_da_requisicao()
returns text
language plpgsql
stable
set search_path = ''
as $$
declare
  v_cab jsonb;
begin
  begin
    v_cab := nullif(pg_catalog.current_setting('request.headers', true), '')::jsonb;
  exception when others then
    return null;
  end;
  return nullif(pg_catalog.btrim(pg_catalog.split_part(coalesce(v_cab ->> 'x-forwarded-for',
    v_cab ->> 'x-real-ip', ''), ',', 1)), '');
end;
$$;

-- Versão atual dos Termos de Uso e da Política de Privacidade (a mesma dos
-- textos em docs/legal). Mudou o texto: muda aqui e todos aceitam de novo.
create or replace function public.versao_termos()
returns text
language sql
immutable
set search_path = ''
as $$
  select '2026-10-17'::text
$$;

-- Código de 6 caracteres sem 0, O, 1 e I, único entre empresas e convites.
create or replace function public.gerar_codigo_entrada()
returns text
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  alfabeto constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  bytes bytea;
  v_codigo text;
  i integer;
begin
  loop
    bytes := pg_catalog.uuid_send(pg_catalog.gen_random_uuid());
    v_codigo := '';
    for i in 0..5 loop
      v_codigo := v_codigo || pg_catalog.substr(alfabeto, (pg_catalog.get_byte(bytes, i) % 32) + 1, 1);
    end loop;
    exit when not exists (select 1 from public.empresas e where e.codigo_entrada = v_codigo)
      and not exists (select 1 from public.convites_motorista c where c.codigo = v_codigo);
  end loop;
  return v_codigo;
end;
$$;

-- Auditoria automática: igual à anterior, mas fica desligada durante uma
-- exclusão de dados pedida (senão a auditoria guardaria uma cópia do que foi
-- apagado). Só as funções de exclusão ligam a chave frota.sem_auditoria.
create or replace function public.registrar_auditoria()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_antes jsonb;
  v_depois jsonb;
  v_empresa uuid;
  v_id uuid;
  v_autor uuid;
  v_acao text;
begin
  if pg_catalog.current_setting('frota.sem_auditoria', true) = 'sim' then
    return coalesce(new, old);
  end if;
  if tg_op = 'DELETE' then
    v_antes := pg_catalog.to_jsonb(old);
  elsif tg_op = 'UPDATE' then
    v_antes := pg_catalog.to_jsonb(old);
    v_depois := pg_catalog.to_jsonb(new);
    if (v_antes - 'atualizado_em') = (v_depois - 'atualizado_em') then
      return new; -- nada mudou de verdade
    end if;
  else
    v_depois := pg_catalog.to_jsonb(new);
  end if;
  v_empresa := coalesce(v_depois ->> 'empresa_id', v_antes ->> 'empresa_id')::uuid;
  v_id := coalesce(v_depois ->> 'id', v_antes ->> 'id')::uuid;
  v_acao := pg_catalog.lower(tg_op);
  if tg_op = 'UPDATE' and v_antes ->> 'apagado_em' is null and v_depois ->> 'apagado_em' is not null then
    v_acao := 'apagar';
  end if;
  select p.id into v_autor from public.perfis p where p.id = (select auth.uid());
  insert into public.auditoria (empresa_id, autor_id, acao, tabela, registro_id, antes, depois)
  values (v_empresa, v_autor, v_acao, tg_table_name, v_id, v_antes, v_depois);
  return coalesce(new, old);
end;
$$;

-- ------------------------------------------------- situação de acesso

-- Quem sou eu, de qual empresa, se a empresa está liberada, se aceitei os
-- termos, se tenho código de recuperação e se tenho pedido esperando.
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
begin
  if v_uid is null then
    return pg_catalog.jsonb_build_object('logado', false);
  end if;
  select (u.email_confirmed_at is not null) into v_email_confirmado from auth.users u where u.id = v_uid;
  select * into v_perfil from public.perfis p where p.id = v_uid;
  if not found then
    return pg_catalog.jsonb_build_object('logado', true, 'email_confirmado', coalesce(v_email_confirmado, false),
      'perfil', null, 'empresa', null, 'motorista', null, 'pedido', null);
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
      'excluir_em', v_excluir_em) end,
    'motorista', case when v_motorista.id is null then null else pg_catalog.jsonb_build_object(
      'id', v_motorista.id, 'nome', v_motorista.nome, 'ativo', v_motorista.ativo and v_motorista.apagado_em is null) end,
    'pedido', v_pedido,
    'termos', pg_catalog.jsonb_build_object('versao', public.versao_termos(),
      'aceito', exists (select 1 from public.aceites_termos a
                        where a.perfil_id = v_uid and a.versao = public.versao_termos())),
    'recuperacao', exists (select 1 from public.codigos_recuperacao c where c.perfil_id = v_uid)
  );
end;
$$;

-- ---------------------------------------------- código individual do motorista

-- O gestor cadastra o motorista (nome e CPF) e recebe um código só dele.
-- Gerar de novo para o mesmo CPF cancela o código anterior.
create or replace function public.gerar_convite_motorista(p_nome text, p_cpf text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_empresa uuid := public.empresa_do_usuario();
  v_nome text := pg_catalog.regexp_replace(pg_catalog.btrim(coalesce(p_nome, '')), '\s+', ' ', 'g');
  v_cpf text := public.so_digitos(p_cpf);
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

  insert into public.convites_motorista (empresa_id, codigo, nome, cpf, criado_por, expira_em)
  values (v_empresa, public.gerar_codigo_entrada(), v_nome, v_cpf, auth.uid(),
          pg_catalog.now() + interval '7 days')
  returning * into v_convite;

  return pg_catalog.jsonb_build_object('id', v_convite.id, 'codigo', v_convite.codigo,
    'nome', v_convite.nome, 'cpf', v_convite.cpf, 'expira_em', v_convite.expira_em);
end;
$$;

create or replace function public.cancelar_convite(p_convite_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.eh_gestor_ou_dono() then
    perform public.erro('Só o dono ou o gestor podem cancelar códigos.', 'sem_permissao', '42501');
  end if;
  update public.convites_motorista c set cancelado_em = pg_catalog.now()
  where c.id = p_convite_id and c.empresa_id = public.empresa_do_usuario()
    and c.usado_em is null and c.cancelado_em is null;
  if not found then
    perform public.erro('Este código já foi usado ou cancelado.', 'convite_inexistente');
  end if;
  return pg_catalog.jsonb_build_object('ok', true);
end;
$$;

-- O motorista digita o código. Primeiro procura o código individual (entra na
-- hora); se não for, procura o código da empresa (pedido para o gestor aprovar).
-- Erro de código não usa exceção, para a tentativa ficar registrada.
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
    perform public.erro('Você já está ligado a uma empresa. Para trocar de empresa, a empresa atual precisa excluir o seu cadastro.',
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

-- ---------------------------------------------------------- termos de uso

create or replace function public.aceitar_termos(p_versao text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null or not exists (select 1 from public.perfis p where p.id = v_uid) then
    perform public.erro('Entre na sua conta para continuar.', 'sem_login', '42501');
  end if;
  if p_versao is distinct from public.versao_termos() then
    perform public.erro('Os termos foram atualizados. Feche e abra o app para ler a versão nova.', 'versao_antiga');
  end if;
  insert into public.aceites_termos (perfil_id, versao, ip)
  values (v_uid, p_versao, public.ip_da_requisicao())
  on conflict (perfil_id, versao) do nothing;
  return public.situacao_acesso();
end;
$$;

-- ---------------------------------------------------- código de recuperação

-- Gera (ou troca) o código de recuperação de um perfil. Formato XXXX-XXXX-XXXX,
-- sem letras que se confundem. Uso interno e da Edge Function.
create or replace function public.novo_codigo_recuperacao(p_perfil uuid)
returns text
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  alfabeto constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  bytes bytea := extensions.gen_random_bytes(12);
  v text := '';
  i integer;
begin
  for i in 0..11 loop
    v := v || pg_catalog.substr(alfabeto, (pg_catalog.get_byte(bytes, i) % 32) + 1, 1);
  end loop;
  insert into public.codigos_recuperacao (perfil_id, hash)
  values (p_perfil, extensions.crypt(v, extensions.gen_salt('bf', 8)))
  on conflict (perfil_id) do update set hash = excluded.hash, criado_em = pg_catalog.now();
  return pg_catalog.substr(v, 1, 4) || '-' || pg_catalog.substr(v, 5, 4) || '-' || pg_catalog.substr(v, 9, 4);
end;
$$;

-- A própria pessoa, já dentro da conta, gera um código novo (o antigo para de valer).
create or replace function public.gerar_codigo_recuperacao()
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null or not exists (select 1 from public.perfis p
                                  where p.id = v_uid and p.ativo and p.apagado_em is null) then
    perform public.erro('Entre na sua conta para continuar.', 'sem_login', '42501');
  end if;
  return public.novo_codigo_recuperacao(v_uid);
end;
$$;

-- Usada só pela Edge Function recuperar_acesso: confere CPF (ou e-mail) e o
-- código. Bloqueio: 5 erros em 15 minutos por conta e por aparelho.
create or replace function public.recuperacao_conferir(p_identificador text, p_codigo text, p_aparelho text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_ident text := pg_catalog.lower(pg_catalog.btrim(coalesce(p_identificador, '')));
  v_codigo text := pg_catalog.upper(pg_catalog.regexp_replace(coalesce(p_codigo, ''), '[^A-Za-z0-9]', '', 'g'));
  v_chaves text[];
  v_chave text;
  v_erros integer;
  v_perfil public.perfis;
  v_hash text;
  v_ok boolean := false;
begin
  if pg_catalog.strpos(v_ident, '@') = 0 then
    v_ident := public.so_digitos(v_ident);
  end if;
  v_chaves := array['recuperar:' || v_ident, 'recuperar:aparelho:' || coalesce(nullif(p_aparelho, ''), '-')];
  foreach v_chave in array v_chaves loop
    select count(*) into v_erros from public.tentativas_acesso t
    where t.tipo = 'login_cpf' and t.chave = v_chave and not t.sucesso
      and t.criado_em > pg_catalog.now() - interval '15 minutes';
    if v_erros >= 5 then
      return pg_catalog.jsonb_build_object('ok', false, 'bloqueado', true);
    end if;
  end loop;

  select * into v_perfil from public.perfis p
  where p.ativo and p.apagado_em is null
    and (case when pg_catalog.strpos(v_ident, '@') > 0 then pg_catalog.lower(p.email) = v_ident
              else p.cpf = v_ident end)
  limit 1;
  if found then
    select c.hash into v_hash from public.codigos_recuperacao c where c.perfil_id = v_perfil.id;
    v_ok := v_hash is not null and pg_catalog.length(v_codigo) = 12
      and extensions.crypt(v_codigo, v_hash) = v_hash;
  end if;
  insert into public.tentativas_acesso (tipo, chave, sucesso)
  select 'login_cpf', c, v_ok from pg_catalog.unnest(v_chaves) c;
  if not v_ok then
    return pg_catalog.jsonb_build_object('ok', false, 'bloqueado', false);
  end if;
  return pg_catalog.jsonb_build_object('ok', true, 'bloqueado', false, 'perfil_id', v_perfil.id,
    'papel', v_perfil.papel, 'email', v_perfil.email, 'cpf', v_perfil.cpf);
end;
$$;

-- ------------------------------------------------------- registros de acesso

-- O app avisa que foi aberto. Guarda data, hora e IP (no máximo um registro por
-- hora para o mesmo app e IP).
create or replace function public.registrar_acesso(p_app text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_ip text := public.ip_da_requisicao();
begin
  if v_uid is null or p_app is null or p_app not in ('motorista', 'gestor', 'web') then
    return;
  end if;
  if exists (select 1 from public.registros_acesso r
             where r.perfil_id = v_uid and r.app = p_app and r.ip is not distinct from v_ip
               and r.quando > pg_catalog.now() - interval '1 hour') then
    return;
  end if;
  insert into public.registros_acesso (perfil_id, empresa_id, app, ip)
  values (v_uid, (select p.empresa_id from public.perfis p where p.id = v_uid), p_app, v_ip);
end;
$$;

-- ------------------------------------------------------------ privilégios

revoke all on function public.empresa_liberada(uuid) from public, anon, authenticated;
revoke all on function public.ip_da_requisicao() from public, anon, authenticated;
revoke all on function public.versao_termos() from public, anon;
revoke all on function public.gerar_codigo_entrada() from public, anon, authenticated;
revoke all on function public.registrar_auditoria() from public, anon, authenticated;
revoke all on function public.situacao_acesso() from public, anon;
revoke all on function public.gerar_convite_motorista(text, text) from public, anon;
revoke all on function public.cancelar_convite(uuid) from public, anon;
revoke all on function public.pedir_entrada(text) from public, anon;
revoke all on function public.aceitar_termos(text) from public, anon;
revoke all on function public.novo_codigo_recuperacao(uuid) from public, anon, authenticated;
revoke all on function public.gerar_codigo_recuperacao() from public, anon;
revoke all on function public.recuperacao_conferir(text, text, text) from public, anon, authenticated;
revoke all on function public.registrar_acesso(text) from public, anon;

grant execute on function public.versao_termos() to authenticated;
grant execute on function public.situacao_acesso() to authenticated;
grant execute on function public.gerar_convite_motorista(text, text) to authenticated;
grant execute on function public.cancelar_convite(uuid) to authenticated;
grant execute on function public.pedir_entrada(text) to authenticated;
grant execute on function public.aceitar_termos(text) to authenticated;
grant execute on function public.gerar_codigo_recuperacao() to authenticated;
grant execute on function public.registrar_acesso(text) to authenticated;
grant execute on function public.novo_codigo_recuperacao(uuid) to service_role;
grant execute on function public.recuperacao_conferir(text, text, text) to service_role;
