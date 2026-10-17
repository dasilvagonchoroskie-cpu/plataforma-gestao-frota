-- Contas, termos e controle da plataforma (pedido do usuário em 17/10/2026).
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

-- ------------------------------------------------------------- colunas novas

alter table public.empresas
  add column if not exists acesso_ate timestamptz,
  add column if not exists bloqueada_em timestamptz,
  add column if not exists motivo_bloqueio text
    check (motivo_bloqueio is null or length(motivo_bloqueio) <= 200),
  add column if not exists excluir_em timestamptz,
  add column if not exists excluida_em timestamptz;

alter table public.perfis
  add column if not exists exclusao_pedida_em timestamptz;

-- ------------------------------------------------------------- tabelas novas

-- Código individual que o gestor gera ao cadastrar um motorista.
create table if not exists public.convites_motorista (
  id uuid primary key default pg_catalog.gen_random_uuid(),
  empresa_id uuid not null references public.empresas(empresa_id),
  codigo text not null unique check (codigo ~ '^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{6}$'),
  nome text not null check (length(btrim(nome)) between 2 and 120),
  cpf text not null check (cpf ~ '^[0-9]{11}$'),
  criado_por uuid,
  expira_em timestamptz not null,
  usado_por uuid,
  usado_em timestamptz,
  cancelado_em timestamptz,
  criado_em timestamptz not null default pg_catalog.now(),
  atualizado_em timestamptz not null default pg_catalog.now(),
  apagado_em timestamptz,
  constraint convites_motorista_empresa_id_id_uk unique (empresa_id, id)
);
create index if not exists convites_motorista_empresa_idx on public.convites_motorista (empresa_id, criado_em);
create index if not exists convites_motorista_cpf_idx on public.convites_motorista (empresa_id, cpf);
create index if not exists convites_motorista_usado_por_idx on public.convites_motorista (usado_por);

-- Código de recuperação (só o resumo cifrado; o código aparece uma vez).
create table if not exists public.codigos_recuperacao (
  perfil_id uuid primary key references public.perfis(id) on delete cascade,
  hash text not null,
  criado_em timestamptz not null default pg_catalog.now()
);

-- Aceite dos Termos de Uso e da Política de Privacidade.
create table if not exists public.aceites_termos (
  id uuid primary key default pg_catalog.gen_random_uuid(),
  perfil_id uuid not null references public.perfis(id) on delete cascade,
  versao text not null check (versao ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'),
  ip text,
  aceito_em timestamptz not null default pg_catalog.now(),
  constraint aceites_termos_perfil_versao_uk unique (perfil_id, versao)
);

-- Registros de acesso (Marco Civil, art. 15). Sem chave estrangeira de
-- propósito: ficam guardados 6 meses mesmo depois de a conta ser excluída.
create table if not exists public.registros_acesso (
  id bigint generated always as identity primary key,
  perfil_id uuid not null,
  empresa_id uuid,
  app text not null check (app in ('motorista', 'gestor', 'web')),
  ip text,
  quando timestamptz not null default pg_catalog.now()
);
create index if not exists registros_acesso_perfil_idx on public.registros_acesso (perfil_id, quando);
create index if not exists registros_acesso_quando_idx on public.registros_acesso (quando);

create trigger convites_motorista_atualizado_em before insert or update on public.convites_motorista
  for each row execute function public.definir_atualizado_em();

alter table public.convites_motorista enable row level security;
alter table public.codigos_recuperacao enable row level security;
alter table public.aceites_termos enable row level security;
alter table public.registros_acesso enable row level security;

-- Convites: só a gestão da própria empresa lê. Criar e cancelar só pelas funções.
create policy convites_motorista_ler_gestao on public.convites_motorista for select to authenticated
  using (empresa_id = (select public.empresa_do_usuario()) and (select public.eh_gestor_ou_dono()));
-- Aceites: cada um lê os próprios. Códigos e registros: só o servidor.
create policy aceites_termos_ler_proprios on public.aceites_termos for select to authenticated
  using (perfil_id = (select auth.uid()));

revoke all on table public.convites_motorista, public.codigos_recuperacao, public.aceites_termos,
  public.registros_acesso from public, anon, authenticated;
grant select on table public.convites_motorista, public.aceites_termos to authenticated;

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
  return pg_catalog.jsonb_build_object('ok', true);
end;
$$;

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

-- Roda uma vez por dia (pg_cron): apaga empresas cujo prazo acabou, contas de
-- motoristas que pediram exclusão há mais de 15 dias, registros de acesso com
-- mais de 6 meses, tentativas de login antigas e códigos vencidos.
create or replace function public.limpeza_diaria()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
  v_empresas integer := 0;
  v_motoristas integer := 0;
  v_contas integer := 0;
  v_registros integer;
begin
  for v_id in
    select e.id from public.empresas e
    where e.excluida_em is null and e.apagado_em is null
      and (e.excluir_em <= pg_catalog.now()
           or (e.excluir_em is null and e.bloqueada_em is null
               and e.acesso_ate + interval '30 days' <= pg_catalog.now()))
  loop
    perform public.expurgar_empresa(v_id, 'Excluída automaticamente depois do fim do acesso');
    v_empresas := v_empresas + 1;
  end loop;

  for v_id in
    select m.id from public.motoristas m join public.perfis p on p.id = m.perfil_id
    where p.exclusao_pedida_em <= pg_catalog.now() - interval '15 days'
  loop
    perform public.expurgar_motorista(v_id, true);
    v_motoristas := v_motoristas + 1;
  end loop;

  for v_id in
    select p.id from public.perfis p
    where p.exclusao_pedida_em <= pg_catalog.now() - interval '15 days'
      and not exists (select 1 from public.motoristas m where m.perfil_id = p.id)
  loop
    perform public.expurgar_perfil(v_id);
    v_contas := v_contas + 1;
  end loop;

  delete from public.registros_acesso where quando < pg_catalog.now() - interval '6 months';
  get diagnostics v_registros = row_count;
  delete from public.tentativas_acesso where criado_em < pg_catalog.now() - interval '30 days';
  delete from public.convites_motorista
  where criado_em < pg_catalog.now() - interval '90 days'
    and (usado_em is not null or cancelado_em is not null or expira_em < pg_catalog.now());

  return pg_catalog.jsonb_build_object('empresas_excluidas', v_empresas, 'motoristas_excluidos', v_motoristas,
    'contas_excluidas', v_contas, 'registros_antigos', v_registros);
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
revoke all on function public.expurgar_perfil(uuid) from public, anon, authenticated;
revoke all on function public.expurgar_motorista(uuid, boolean) from public, anon, authenticated;
revoke all on function public.expurgar_empresa(uuid, text) from public, anon, authenticated;
revoke all on function public.excluir_motorista(uuid) from public, anon;
revoke all on function public.excluir_minha_conta() from public, anon;
revoke all on function public.excluir_minha_empresa(text) from public, anon;
revoke all on function public.bloquear_empresa(uuid, text, integer) from public, anon, authenticated;
revoke all on function public.liberar_empresa(uuid, timestamptz) from public, anon, authenticated;
revoke all on function public.excluir_empresa_plataforma(uuid) from public, anon, authenticated;
revoke all on function public.empresas_da_plataforma() from public, anon, authenticated;
revoke all on function public.limpeza_diaria() from public, anon, authenticated;

grant execute on function public.versao_termos() to authenticated;
grant execute on function public.situacao_acesso() to authenticated;
grant execute on function public.gerar_convite_motorista(text, text) to authenticated;
grant execute on function public.cancelar_convite(uuid) to authenticated;
grant execute on function public.pedir_entrada(text) to authenticated;
grant execute on function public.aceitar_termos(text) to authenticated;
grant execute on function public.gerar_codigo_recuperacao() to authenticated;
grant execute on function public.registrar_acesso(text) to authenticated;
grant execute on function public.excluir_motorista(uuid) to authenticated;
grant execute on function public.excluir_minha_conta() to authenticated;
grant execute on function public.excluir_minha_empresa(text) to authenticated;
grant execute on function public.novo_codigo_recuperacao(uuid) to service_role;
grant execute on function public.recuperacao_conferir(text, text, text) to service_role;
grant execute on function public.bloquear_empresa(uuid, text, integer) to service_role;
grant execute on function public.liberar_empresa(uuid, timestamptz) to service_role;
grant execute on function public.excluir_empresa_plataforma(uuid) to service_role;
grant execute on function public.empresas_da_plataforma() to service_role;
grant execute on function public.limpeza_diaria() to service_role;

-- ---------------------------------------------------- limpeza todo dia (pg_cron)

-- Onde o pg_cron existe (Supabase), agenda a limpeza diária às 03:20 de
-- Brasília (06:20 UTC). Num PostgreSQL sem pg_cron (testes locais), pula.
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
