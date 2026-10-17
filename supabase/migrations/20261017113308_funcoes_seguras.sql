-- Funções seguras da Plataforma de Gestão de Frota (Fase 1 e Fase 4).
--
-- Todas são SECURITY DEFINER com search_path vazio e conferem por conta
-- própria quem está chamando (auth.uid()). As mensagens de erro já saem em
-- português simples para o app mostrar; o campo hint leva um código curto.

-- ------------------------------------------------------------ utilidades

create or replace function public.so_digitos(p text)
returns text
language sql
immutable
set search_path = ''
as $$
  select pg_catalog.regexp_replace(coalesce(p, ''), '[^0-9]', '', 'g')
$$;

-- Confere os dois dígitos verificadores do CPF.
create or replace function public.cpf_valido(p text)
returns boolean
language plpgsql
immutable
set search_path = ''
as $$
declare
  d text := public.so_digitos(p);
  soma integer;
  dv1 integer;
  dv2 integer;
  i integer;
begin
  if pg_catalog.length(d) <> 11 or d ~ '^(\d)\1{10}$' then
    return false;
  end if;
  soma := 0;
  for i in 1..9 loop
    soma := soma + pg_catalog.substr(d, i, 1)::integer * (11 - i);
  end loop;
  dv1 := (soma * 10) % 11;
  if dv1 = 10 then dv1 := 0; end if;
  soma := 0;
  for i in 1..10 loop
    soma := soma + pg_catalog.substr(d, i, 1)::integer * (12 - i);
  end loop;
  dv2 := (soma * 10) % 11;
  if dv2 = 10 then dv2 := 0; end if;
  return dv1 = pg_catalog.substr(d, 10, 1)::integer and dv2 = pg_catalog.substr(d, 11, 1)::integer;
end;
$$;

create or replace function public.normalizar_placa(p text)
returns text
language sql
immutable
set search_path = ''
as $$
  select pg_catalog.upper(pg_catalog.regexp_replace(coalesce(p, ''), '[^A-Za-z0-9]', '', 'g'))
$$;

-- Código de 6 caracteres sem 0, O, 1 e I (não se confundem no WhatsApp).
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
  codigo text;
  i integer;
begin
  loop
    bytes := pg_catalog.uuid_send(pg_catalog.gen_random_uuid());
    codigo := '';
    for i in 0..5 loop
      codigo := codigo || pg_catalog.substr(alfabeto, (pg_catalog.get_byte(bytes, i) % 32) + 1, 1);
    end loop;
    exit when not exists (select 1 from public.empresas e where e.codigo_entrada = codigo);
  end loop;
  return codigo;
end;
$$;

create or replace function public.erro(p_mensagem text, p_codigo text, p_errcode text default 'P0001')
returns void
language plpgsql
set search_path = ''
as $$
begin
  raise exception using message = p_mensagem, hint = p_codigo, errcode = p_errcode;
end;
$$;

-- ------------------------------------------------- situação de acesso

-- Quem sou eu, de qual empresa e se tenho pedido de entrada esperando.
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

  return pg_catalog.jsonb_build_object(
    'logado', true,
    'email_confirmado', coalesce(v_email_confirmado, false),
    'perfil', pg_catalog.jsonb_build_object(
      'id', v_perfil.id, 'nome', v_perfil.nome, 'papel', v_perfil.papel,
      'email', v_perfil.email, 'cpf', v_perfil.cpf, 'ativo', v_perfil.ativo and v_perfil.apagado_em is null),
    'empresa', case when v_empresa.id is null then null else pg_catalog.jsonb_build_object(
      'id', v_empresa.id, 'nome', v_empresa.nome, 'status', v_empresa.status,
      'plano', v_empresa.plano, 'limite_caminhoes', v_empresa.limite_caminhoes,
      'percentual_comissao_padrao', v_empresa.percentual_comissao_padrao,
      'comissao_sobre_bruto_padrao', v_empresa.comissao_sobre_bruto_padrao,
      'gastos_descontam_do_liquido', v_empresa.gastos_descontam_do_liquido,
      'vale_desconta_do_liquido', v_empresa.vale_desconta_do_liquido,
      'codigo_entrada', case when v_perfil.papel in ('dono', 'gestor') then v_empresa.codigo_entrada end) end,
    'motorista', case when v_motorista.id is null then null else pg_catalog.jsonb_build_object(
      'id', v_motorista.id, 'nome', v_motorista.nome, 'ativo', v_motorista.ativo and v_motorista.apagado_em is null) end,
    'pedido', v_pedido
  );
end;
$$;

-- ------------------------------------------------------ cadastro e acesso

-- Liga um perfil sem empresa (ou reativa) quando o e-mail está autorizado.
create or replace function public.aplicar_acesso_autorizado()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_restantes integer;
begin
  if new.ativo and new.apagado_em is null then
    update public.perfis p
       set empresa_id = new.empresa_id, papel = new.papel, ativo = true
     where pg_catalog.lower(p.email) = new.email
       and p.apagado_em is null
       and (p.empresa_id = new.empresa_id
            or (p.empresa_id is null and not exists (
                  select 1 from public.motoristas m where m.perfil_id = p.id)));
  elsif tg_op = 'UPDATE' then
    -- Não deixa a empresa sem nenhum dono ativo.
    if old.papel = 'dono' and old.ativo and old.apagado_em is null then
      select count(*) into v_restantes from public.acessos_autorizados a
      where a.empresa_id = new.empresa_id and a.papel = 'dono' and a.ativo
        and a.apagado_em is null and a.id <> new.id;
      if v_restantes = 0 then
        perform public.erro('A empresa precisa ter pelo menos um dono ativo.', 'ultimo_dono');
      end if;
    end if;
    update public.perfis p
       set ativo = false
     where p.empresa_id = new.empresa_id and pg_catalog.lower(p.email) = new.email
       and p.papel in ('dono', 'gestor');
  end if;
  return new;
end;
$$;

create trigger acessos_autorizados_aplicar after insert or update on public.acessos_autorizados
  for each row execute function public.aplicar_acesso_autorizado();

-- Depois de confirmar o e-mail pelo código: grava nome e CPF. Se o e-mail
-- estiver autorizado (dono ou gestor), já entra na empresa.
create or replace function public.completar_cadastro(p_nome text, p_cpf text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_email text;
  v_confirmado timestamptz;
  v_nome text := pg_catalog.btrim(coalesce(p_nome, ''));
  v_cpf text := nullif(public.so_digitos(p_cpf), '');
  v_acesso public.acessos_autorizados;
  v_perfil public.perfis;
begin
  if v_uid is null then
    perform public.erro('Entre na sua conta para continuar.', 'sem_login', '42501');
  end if;
  select pg_catalog.lower(u.email), u.email_confirmed_at into v_email, v_confirmado
  from auth.users u where u.id = v_uid;
  if v_confirmado is null then
    perform public.erro('Confirme o seu e-mail com o código antes de continuar.', 'email_nao_confirmado');
  end if;
  if pg_catalog.length(v_nome) < 2 or pg_catalog.length(v_nome) > 120 then
    perform public.erro('Escreva o seu nome.', 'nome_invalido');
  end if;

  select * into v_acesso from public.acessos_autorizados a
  where a.email = v_email and a.ativo and a.apagado_em is null
  order by (a.papel = 'dono') desc, a.criado_em
  limit 1;

  if v_cpf is not null and not public.cpf_valido(v_cpf) then
    perform public.erro('O CPF não está certo. Confira os números.', 'cpf_invalido');
  end if;
  if v_acesso.id is null and v_cpf is null then
    perform public.erro('Digite o seu CPF.', 'cpf_obrigatorio');
  end if;
  if v_cpf is not null and exists (select 1 from public.perfis p where p.cpf = v_cpf and p.id <> v_uid) then
    perform public.erro('Este CPF já tem cadastro. Use "Esqueci a senha" para entrar.', 'cpf_em_uso');
  end if;

  select * into v_perfil from public.perfis p where p.id = v_uid for update;
  if not found then
    insert into public.perfis (id, empresa_id, papel, nome, cpf, email)
    values (v_uid, v_acesso.empresa_id, coalesce(v_acesso.papel, 'motorista'), v_nome, v_cpf, v_email);
  else
    update public.perfis p
       set nome = v_nome,
           cpf = coalesce(v_cpf, p.cpf),
           empresa_id = case when p.empresa_id is null and v_acesso.id is not null
                               and not exists (select 1 from public.motoristas m where m.perfil_id = p.id)
                             then v_acesso.empresa_id else p.empresa_id end,
           papel = case when p.empresa_id is null and v_acesso.id is not null
                          and not exists (select 1 from public.motoristas m where m.perfil_id = p.id)
                        then v_acesso.papel else p.papel end
     where p.id = v_uid;
  end if;
  return public.situacao_acesso();
end;
$$;

-- O motorista digita o código que o patrão mandou. Cria um pedido pendente.
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
  v_erros integer;
  v_pedido public.pedidos_entrada;
begin
  select * into v_perfil from public.perfis p where p.id = v_uid and p.apagado_em is null;
  if not found then
    perform public.erro('Termine o seu cadastro antes.', 'sem_perfil');
  end if;
  if v_perfil.papel <> 'motorista' then
    perform public.erro('Esta conta é de gestor. Use o app do gestor.', 'nao_motorista');
  end if;
  if v_perfil.empresa_id is not null then
    perform public.erro('Você já está ligado a uma empresa.', 'ja_vinculado');
  end if;

  select count(*) into v_erros from public.tentativas_acesso t
  where t.tipo = 'codigo_empresa' and t.chave = v_uid::text and not t.sucesso
    and t.criado_em > pg_catalog.now() - interval '15 minutes';
  if v_erros >= 10 then
    return pg_catalog.jsonb_build_object('ok', false, 'codigo', 'muitas_tentativas',
      'mensagem', 'Muitas tentativas. Espere 15 minutos e tente de novo.');
  end if;

  select * into v_empresa from public.empresas e
  where e.codigo_entrada = v_codigo and e.apagado_em is null and e.status <> 'suspensa';
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

-- O gestor ou dono aprova (cria o motorista e liga o perfil) ou recusa.
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

-- O gestor gera outro código; o anterior deixa de valer na hora.
create or replace function public.gerar_novo_codigo_entrada()
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_codigo text;
begin
  if not public.eh_gestor_ou_dono() then
    perform public.erro('Só o dono ou o gestor podem trocar o código.', 'sem_permissao', '42501');
  end if;
  v_codigo := public.gerar_codigo_entrada();
  update public.empresas set codigo_entrada = v_codigo where id = public.empresa_do_usuario();
  return v_codigo;
end;
$$;

-- Usado pela Edge Function redefinir_acesso, com o token do gestor: confere
-- que o motorista é da empresa dele e devolve o perfil a redefinir.
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
  if v_resultado is null then
    perform public.erro('Motorista não encontrado.', 'motorista_inexistente');
  end if;
  return v_resultado;
end;
$$;

-- ------------------------------------------- criação de empresa (plataforma)

-- Só o dono da plataforma (service_role, pelo painel do Supabase ou script).
create or replace function public.criar_empresa(
  p_nome text,
  p_email_dono text,
  p_documento text default null,
  p_plano text default 'piloto',
  p_limite_caminhoes integer default 5,
  p_status text default 'teste'
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid := pg_catalog.gen_random_uuid();
  v_codigo text := public.gerar_codigo_entrada();
  v_email text := pg_catalog.lower(pg_catalog.btrim(p_email_dono));
  v_categoria text;
begin
  insert into public.empresas (id, empresa_id, nome, documento, codigo_entrada, plano, limite_caminhoes, status)
  values (v_id, v_id, pg_catalog.btrim(p_nome), p_documento, v_codigo, p_plano, p_limite_caminhoes, p_status);
  -- Categorias iniciais: as mesmas do Meu Frete.
  foreach v_categoria in array array['Alimentação', 'Arla 32', 'Borracharia', 'Chapa',
    'Estacionamento', 'Lavagem', 'Manutenção', 'Óleo', 'Pedágio', 'Peças', 'Outros'] loop
    insert into public.categorias_gasto (id, empresa_id, nome)
    values (pg_catalog.gen_random_uuid(), v_id, v_categoria);
  end loop;
  insert into public.acessos_autorizados (id, empresa_id, email, papel)
  values (pg_catalog.gen_random_uuid(), v_id, v_email, 'dono');
  return pg_catalog.jsonb_build_object('empresa_id', v_id, 'codigo_entrada', v_codigo, 'email_dono', v_email);
end;
$$;

-- --------------------------------------------------- troca de caminhão

-- Abre um uso de caminhão a partir de p_inicio, fechando o anterior. Funciona
-- também quando trocas feitas sem internet chegam fora de ordem.
create or replace function public.registrar_uso_caminhao(
  p_id uuid, p_empresa uuid, p_motorista uuid, p_caminhao uuid, p_inicio timestamptz, p_por uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_existente public.uso_caminhao;
  v_anterior public.uso_caminhao;
  v_proximo timestamptz;
begin
  select * into v_existente from public.uso_caminhao u where u.id = p_id;
  if found then
    if v_existente.empresa_id = p_empresa and v_existente.motorista_id = p_motorista
       and v_existente.caminhao_id = p_caminhao and v_existente.inicio_em = p_inicio then
      return; -- reenvio do mesmo registro
    end if;
    perform public.erro('Registro de troca de caminhão repetido com outros dados.', 'id_em_uso');
  end if;

  -- Uma troca por vez para cada motorista.
  perform 1 from public.motoristas m where m.id = p_motorista and m.empresa_id = p_empresa for update;
  if not found then
    perform public.erro('Motorista não encontrado.', 'motorista_inexistente');
  end if;

  select pg_catalog.min(u.inicio_em) into v_proximo from public.uso_caminhao u
  where u.motorista_id = p_motorista and u.apagado_em is null and u.inicio_em > p_inicio;

  select * into v_anterior from public.uso_caminhao u
  where u.motorista_id = p_motorista and u.apagado_em is null and u.inicio_em <= p_inicio
  order by u.inicio_em desc, u.criado_em desc
  limit 1;
  if v_anterior.id is not null and (v_anterior.fim_em is null or v_anterior.fim_em > p_inicio) then
    update public.uso_caminhao set fim_em = p_inicio where id = v_anterior.id;
  end if;

  insert into public.uso_caminhao (id, empresa_id, motorista_id, caminhao_id, inicio_em, fim_em, registrado_por)
  values (p_id, p_empresa, p_motorista, p_caminhao, p_inicio, v_proximo, p_por);
end;
$$;

-- O gestor define o caminhão atual de um motorista pelo painel.
create or replace function public.definir_caminhao_atual(
  p_motorista_id uuid, p_caminhao_id uuid, p_inicio timestamptz default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_empresa uuid := public.empresa_do_usuario();
  v_id uuid := pg_catalog.gen_random_uuid();
begin
  if not public.eh_gestor_ou_dono() then
    perform public.erro('Só o dono ou o gestor podem trocar o caminhão de um motorista.', 'sem_permissao', '42501');
  end if;
  if not exists (select 1 from public.caminhoes c where c.id = p_caminhao_id and c.empresa_id = v_empresa
                 and c.ativo and c.apagado_em is null) then
    perform public.erro('Caminhão não encontrado.', 'caminhao_inexistente');
  end if;
  perform public.registrar_uso_caminhao(v_id, v_empresa, p_motorista_id, p_caminhao_id,
    coalesce(p_inicio, pg_catalog.now()), (select auth.uid()));
  return pg_catalog.jsonb_build_object('ok', true, 'uso_id', v_id);
end;
$$;

-- ------------------------------------------------------------ sincronização

-- Grava um item do lote. Devolve null se aceitou ou um objeto com o motivo.
create or replace function public.sync_gravar_item(
  p_tabela text, p_dados jsonb, p_empresa uuid, p_motorista uuid, p_uid uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid := (p_dados ->> 'id')::uuid;
  v_dados jsonb := pg_catalog.jsonb_strip_nulls(p_dados);
  v_padroes jsonb := '{}';
  v_existente jsonb;
  v_novo jsonb;
  v_colunas text;
  v_apagar boolean := (p_dados ->> 'apagado_em') is not null;
  v_empresa public.empresas;
  v_frete uuid;
  v_placa text;
  v_outro public.caminhoes;
begin
  if v_id is null then
    return pg_catalog.jsonb_build_object('motivo', 'sem_id', 'mensagem', 'Registro sem identificação.');
  end if;
  if (v_dados ? 'motorista_id') and (v_dados ->> 'motorista_id')::uuid <> p_motorista then
    return pg_catalog.jsonb_build_object('motivo', 'outro_motorista',
      'mensagem', 'Este lançamento é de outro motorista.');
  end if;

  -- Caminhão que o motorista cadastrou (não achou na lista).
  if p_tabela = 'caminhoes' then
    if exists (select 1 from public.caminhoes c where c.id = v_id) then
      if exists (select 1 from public.caminhoes c where c.id = v_id and c.empresa_id = p_empresa) then
        return null;
      end if;
      return pg_catalog.jsonb_build_object('motivo', 'id_em_uso', 'mensagem', 'Caminhão repetido.');
    end if;
    v_placa := public.normalizar_placa(v_dados ->> 'placa');
    select * into v_outro from public.caminhoes c where c.empresa_id = p_empresa and c.placa = v_placa;
    if found then
      -- O gestor já tinha cadastrado esta placa: o app passa a usar o id dele.
      return pg_catalog.jsonb_build_object('motivo', 'substituido', 'substituido_por', v_outro.id,
        'atual', pg_catalog.to_jsonb(v_outro));
    end if;
    insert into public.caminhoes (id, empresa_id, placa, numero_frota, modelo, ativo, confirmado)
    values (v_id, p_empresa, v_placa, nullif(pg_catalog.btrim(v_dados ->> 'numero_frota'), ''),
            coalesce(v_dados ->> 'modelo', ''), true, false);
    return null;
  end if;

  if p_tabela = 'uso_caminhao' then
    perform public.registrar_uso_caminhao(v_id, p_empresa, p_motorista,
      (v_dados ->> 'caminhao_id')::uuid, (v_dados ->> 'inicio_em')::timestamptz, p_uid);
    return null;
  end if;

  if p_tabela not in ('fretes', 'abastecimentos', 'gastos_viagem', 'vales', 'ajustes_km') then
    return pg_catalog.jsonb_build_object('motivo', 'tabela_invalida', 'mensagem', 'Tipo de registro desconhecido.');
  end if;

  if p_tabela = 'fretes' then
    select * into v_empresa from public.empresas e where e.id = p_empresa;
    v_padroes := pg_catalog.jsonb_build_object(
      'embarcador', '', 'peso_carga_kg', 0, 'valor_tonelada_centavos', 0, 'adiantamento_centavos', 0,
      'saldo_centavos', 0, 'pedagio_centavos', 0, 'peso_descarga_kg', 0, 'desconto_quebra_centavos', 0,
      'percentual_comissao', v_empresa.percentual_comissao_padrao,
      'comissao_sobre_bruto', v_empresa.comissao_sobre_bruto_padrao);
  elsif p_tabela = 'abastecimentos' then
    v_padroes := '{"cidade": "", "posto": "", "litros": 0, "valor_centavos": 0, "tanque_cheio": true, "ponto_de_partida": false}';
  end if;

  -- Frete ligado precisa ser do próprio motorista.
  if p_tabela in ('abastecimentos', 'gastos_viagem') and v_dados ? 'frete_id' then
    select f.id into v_frete from public.fretes f
    where f.id = (v_dados ->> 'frete_id')::uuid and f.motorista_id = p_motorista and f.empresa_id = p_empresa;
    if v_frete is null then
      return pg_catalog.jsonb_build_object('motivo', 'frete_invalido', 'mensagem', 'O frete ligado não foi encontrado.');
    end if;
  end if;

  v_novo := v_padroes || (v_dados - 'apagado_em' - 'criado_em' - 'atualizado_em')
    || pg_catalog.jsonb_build_object('id', v_id, 'empresa_id', p_empresa, 'motorista_id', p_motorista);

  execute pg_catalog.format('select pg_catalog.to_jsonb(t) from public.%I t where t.id = $1 for update', p_tabela)
    into v_existente using v_id;

  if v_existente is null then
    if v_apagar then
      return null; -- criado e apagado antes de chegar: nada a gravar
    end if;
    execute pg_catalog.format(
      'insert into public.%I select * from pg_catalog.jsonb_populate_record(null::public.%I, $1)',
      p_tabela, p_tabela) using v_novo;
    return null;
  end if;

  if (v_existente ->> 'empresa_id')::uuid <> p_empresa or (v_existente ->> 'motorista_id')::uuid <> p_motorista then
    return pg_catalog.jsonb_build_object('motivo', 'id_em_uso', 'mensagem', 'Registro repetido.');
  end if;
  if v_existente ->> 'apagado_em' is not null then
    if v_apagar then return null; end if;
    return pg_catalog.jsonb_build_object('motivo', 'apagado', 'mensagem', 'Este lançamento já foi apagado.');
  end if;

  -- Mesmo conteúdo (reenvio): aceita sem mudar nada.
  execute pg_catalog.format(
    'select pg_catalog.to_jsonb(r) from pg_catalog.jsonb_populate_record(null::public.%I, $1) r', p_tabela)
    into v_novo using (v_existente || v_novo);
  if not v_apagar and (v_novo - 'criado_em' - 'atualizado_em') = (v_existente - 'criado_em' - 'atualizado_em') then
    return null;
  end if;

  if p_tabela in ('fretes', 'abastecimentos', 'gastos_viagem', 'vales') and exists (
    select 1 from public.ajustes_gestor ag
    where ag.tabela_alvo = p_tabela and ag.registro_id = v_id and ag.apagado_em is null
  ) then
    return pg_catalog.jsonb_build_object('motivo', 'ajustado',
      'mensagem', 'O seu patrão já corrigiu este lançamento. Para mudar de novo, fale com ele.',
      'atual', v_existente);
  end if;

  if v_apagar then
    execute pg_catalog.format('update public.%I set apagado_em = pg_catalog.clock_timestamp() where id = $1', p_tabela)
      using v_id;
    return null;
  end if;

  select pg_catalog.string_agg(pg_catalog.quote_ident(c.column_name), ', ' order by c.ordinal_position)
    into v_colunas
  from information_schema.columns c
  where c.table_schema = 'public' and c.table_name = p_tabela
    and c.column_name not in ('id', 'empresa_id', 'motorista_id', 'criado_em', 'atualizado_em', 'apagado_em');
  execute pg_catalog.format(
    'update public.%I t set (%s) = (select %s from pg_catalog.jsonb_populate_record(null::public.%I, $1)) where t.id = $2',
    p_tabela, v_colunas, v_colunas, p_tabela) using v_novo, v_id;
  return null;
end;
$$;

-- Recebe a fila do celular em lote. Reenviar o mesmo lote nunca duplica.
-- Formato: {"dispositivo_id": uuid, "apelido": texto, "itens": [{"tabela": t, "dados": {...}}]}
create or replace function public.sincronizar_lote(p_lote jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_motorista uuid := public.motorista_do_usuario();
  v_empresa uuid;
  v_status text;
  v_dispositivo uuid := nullif(p_lote ->> 'dispositivo_id', '')::uuid;
  v_item record;
  v_dados jsonb;
  v_resultado jsonb;
  v_aceitos jsonb := '[]';
  v_rejeitados jsonb := '[]';
  v_mapa jsonb := '{}';
  v_qtd integer := coalesce(pg_catalog.jsonb_array_length(p_lote -> 'itens'), 0);
begin
  if v_motorista is null then
    perform public.erro('Sua conta ainda não foi aprovada pela empresa ou foi desativada.', 'sem_vinculo', '42501');
  end if;
  if v_qtd > 500 then
    perform public.erro('Lote grande demais.', 'lote_grande');
  end if;
  select m.empresa_id, e.status into v_empresa, v_status
  from public.motoristas m join public.empresas e on e.id = m.empresa_id
  where m.id = v_motorista;

  if v_dispositivo is not null then
    if exists (select 1 from public.dispositivos d where d.id = v_dispositivo
               and (d.perfil_id <> v_uid or d.revogado_em is not null)) then
      perform public.erro('Este celular foi desligado da empresa. Fale com o seu patrão.', 'dispositivo_revogado', '42501');
    end if;
    insert into public.dispositivos (id, empresa_id, perfil_id, apelido, ultimo_sync_em)
    values (v_dispositivo, v_empresa, v_uid, coalesce(nullif(p_lote ->> 'apelido', ''), 'Celular'),
            pg_catalog.clock_timestamp())
    on conflict (id) do update set ultimo_sync_em = excluded.ultimo_sync_em;
  end if;

  if v_status = 'suspensa' then
    select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
             'tabela', i ->> 'tabela', 'id', i -> 'dados' ->> 'id', 'motivo', 'empresa_suspensa',
             'mensagem', 'A empresa está suspensa. Os seus dados estão guardados, mas não dá para enviar agora.')), '[]')
      into v_rejeitados
    from pg_catalog.jsonb_array_elements(coalesce(p_lote -> 'itens', '[]')) i;
    return pg_catalog.jsonb_build_object('aceitos', '[]'::jsonb, 'rejeitados', v_rejeitados,
      'suspensa', true, 'servidor_em', pg_catalog.clock_timestamp());
  end if;

  for v_item in
    select i.valor, i.ordem
    from pg_catalog.jsonb_array_elements(coalesce(p_lote -> 'itens', '[]')) with ordinality as i(valor, ordem)
    order by case i.valor ->> 'tabela'
      when 'caminhoes' then 1 when 'uso_caminhao' then 2 when 'fretes' then 3
      when 'abastecimentos' then 4 when 'gastos_viagem' then 5 when 'vales' then 6
      when 'ajustes_km' then 7 else 9 end, i.ordem
  loop
    v_dados := v_item.valor -> 'dados';
    -- Caminhão trocado pelo id do gestor dentro do mesmo lote.
    if v_dados ? 'caminhao_id' and v_mapa ? (v_dados ->> 'caminhao_id') then
      v_dados := v_dados || pg_catalog.jsonb_build_object('caminhao_id', v_mapa ->> (v_dados ->> 'caminhao_id'));
    end if;
    begin
      v_resultado := public.sync_gravar_item(v_item.valor ->> 'tabela', v_dados, v_empresa, v_motorista, v_uid);
      if v_resultado is null then
        v_aceitos := v_aceitos || pg_catalog.jsonb_build_object('tabela', v_item.valor ->> 'tabela', 'id', v_dados ->> 'id');
      elsif v_resultado ->> 'motivo' = 'substituido' then
        v_mapa := v_mapa || pg_catalog.jsonb_build_object(v_dados ->> 'id', v_resultado ->> 'substituido_por');
        v_aceitos := v_aceitos || (pg_catalog.jsonb_build_object('tabela', 'caminhoes', 'id', v_dados ->> 'id')
          || (v_resultado - 'motivo'));
      else
        v_rejeitados := v_rejeitados || (pg_catalog.jsonb_build_object('tabela', v_item.valor ->> 'tabela',
          'id', v_dados ->> 'id') || v_resultado);
      end if;
    exception when others then
      v_rejeitados := v_rejeitados || pg_catalog.jsonb_build_object('tabela', v_item.valor ->> 'tabela',
        'id', v_dados ->> 'id', 'motivo', 'invalido',
        'mensagem', 'Este registro tem um dado que não foi aceito.', 'detalhe', sqlerrm);
    end;
  end loop;

  return pg_catalog.jsonb_build_object('aceitos', v_aceitos, 'rejeitados', v_rejeitados,
    'suspensa', false, 'servidor_em', pg_catalog.clock_timestamp());
end;
$$;

-- Tudo que mudou para este motorista desde a última vez. Sem data, devolve
-- o histórico inteiro (celular novo ou app reinstalado). A margem de 2
-- minutos cobre gravações que terminaram enquanto a consulta rodava.
create or replace function public.baixar_alteracoes(p_desde timestamptz default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_agora timestamptz := pg_catalog.clock_timestamp();
  v_motorista uuid := public.motorista_do_usuario();
  v_empresa uuid;
  v_desde timestamptz := coalesce(p_desde - interval '2 minutes', '-infinity'::timestamptz);
begin
  if v_motorista is null then
    return pg_catalog.jsonb_build_object('servidor_em', v_agora, 'situacao', public.situacao_acesso());
  end if;
  select m.empresa_id into v_empresa from public.motoristas m where m.id = v_motorista;

  return pg_catalog.jsonb_build_object(
    'servidor_em', v_agora,
    'situacao', public.situacao_acesso(),
    'caminhoes', (select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'id', c.id, 'placa', c.placa, 'numero_frota', c.numero_frota, 'modelo', c.modelo,
        'ativo', c.ativo and c.apagado_em is null, 'confirmado', c.confirmado) order by c.placa), '[]')
      from public.caminhoes c where c.empresa_id = v_empresa and c.atualizado_em > v_desde),
    'categorias', (select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'id', g.id, 'nome', g.nome, 'ativa', g.ativa and g.apagado_em is null) order by g.nome), '[]')
      from public.categorias_gasto g where g.empresa_id = v_empresa and g.atualizado_em > v_desde),
    'fretes', (select coalesce(pg_catalog.jsonb_agg(pg_catalog.to_jsonb(f)), '[]')
      from public.fretes f where f.motorista_id = v_motorista and f.atualizado_em > v_desde),
    'abastecimentos', (select coalesce(pg_catalog.jsonb_agg(pg_catalog.to_jsonb(a)), '[]')
      from public.abastecimentos a where a.motorista_id = v_motorista and a.atualizado_em > v_desde),
    'gastos_viagem', (select coalesce(pg_catalog.jsonb_agg(pg_catalog.to_jsonb(g)), '[]')
      from public.gastos_viagem g where g.motorista_id = v_motorista and g.atualizado_em > v_desde),
    'vales', (select coalesce(pg_catalog.jsonb_agg(pg_catalog.to_jsonb(v)), '[]')
      from public.vales v where v.motorista_id = v_motorista and v.atualizado_em > v_desde),
    'ajustes_km', (select coalesce(pg_catalog.jsonb_agg(pg_catalog.to_jsonb(k)), '[]')
      from public.ajustes_km k where k.motorista_id = v_motorista and k.atualizado_em > v_desde),
    'uso_caminhao', (select coalesce(pg_catalog.jsonb_agg(pg_catalog.to_jsonb(u)), '[]')
      from public.uso_caminhao u where u.motorista_id = v_motorista and u.atualizado_em > v_desde),
    'ajustes', (select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'id', ag.id, 'tabela_alvo', ag.tabela_alvo, 'registro_id', ag.registro_id, 'campo', ag.campo,
        'valor_antigo', ag.valor_antigo, 'valor_novo', ag.valor_novo, 'motivo', ag.motivo,
        'criado_em', ag.criado_em, 'apagado', ag.apagado_em is not null) order by ag.criado_em), '[]')
      from public.ajustes_gestor ag
      where ag.empresa_id = v_empresa and ag.atualizado_em > v_desde and (
        (ag.tabela_alvo = 'fretes' and exists (select 1 from public.fretes f where f.id = ag.registro_id and f.motorista_id = v_motorista)) or
        (ag.tabela_alvo = 'abastecimentos' and exists (select 1 from public.abastecimentos a where a.id = ag.registro_id and a.motorista_id = v_motorista)) or
        (ag.tabela_alvo = 'gastos_viagem' and exists (select 1 from public.gastos_viagem g where g.id = ag.registro_id and g.motorista_id = v_motorista)) or
        (ag.tabela_alvo = 'vales' and exists (select 1 from public.vales v where v.id = ag.registro_id and v.motorista_id = v_motorista))))
  );
end;
$$;

-- ------------------------------------------- login por CPF (Edge Function)

-- Usadas só pela Edge Function entrar_com_cpf, com a chave do servidor.
-- Bloqueio: 5 erros seguidos em 15 minutos, por CPF e por aparelho.
create or replace function public.login_cpf_preparar(p_cpf text, p_aparelho text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_cpf text := public.so_digitos(p_cpf);
  v_chaves text[] := array['cpf:' || v_cpf, 'aparelho:' || coalesce(nullif(p_aparelho, ''), '-')];
  v_chave text;
  v_ultimo_ok timestamptz;
  v_erros integer;
  v_email text;
begin
  foreach v_chave in array v_chaves loop
    select pg_catalog.max(t.criado_em) into v_ultimo_ok from public.tentativas_acesso t
    where t.tipo = 'login_cpf' and t.chave = v_chave and t.sucesso;
    select count(*) into v_erros from public.tentativas_acesso t
    where t.tipo = 'login_cpf' and t.chave = v_chave and not t.sucesso
      and t.criado_em > greatest(pg_catalog.now() - interval '15 minutes',
                                 coalesce(v_ultimo_ok, '-infinity'::timestamptz));
    if v_erros >= 5 then
      return pg_catalog.jsonb_build_object('bloqueado', true);
    end if;
  end loop;
  select p.email into v_email from public.perfis p
  where p.cpf = v_cpf and p.ativo and p.apagado_em is null;
  return pg_catalog.jsonb_build_object('bloqueado', false, 'email', v_email);
end;
$$;

create or replace function public.login_cpf_registrar(p_cpf text, p_aparelho text, p_sucesso boolean)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.tentativas_acesso (tipo, chave, sucesso)
  values ('login_cpf', 'cpf:' || public.so_digitos(p_cpf), p_sucesso),
         ('login_cpf', 'aparelho:' || coalesce(nullif(p_aparelho, ''), '-'), p_sucesso);
$$;

-- ------------------------------------------------------------ privilégios

revoke all on function public.so_digitos(text) from public, anon;
revoke all on function public.cpf_valido(text) from public, anon;
revoke all on function public.normalizar_placa(text) from public, anon;
revoke all on function public.gerar_codigo_entrada() from public, anon, authenticated;
revoke all on function public.erro(text, text, text) from public, anon, authenticated;
revoke all on function public.situacao_acesso() from public, anon;
revoke all on function public.aplicar_acesso_autorizado() from public, anon, authenticated;
revoke all on function public.completar_cadastro(text, text) from public, anon;
revoke all on function public.pedir_entrada(text) from public, anon;
revoke all on function public.decidir_entrada(uuid, boolean) from public, anon;
revoke all on function public.gerar_novo_codigo_entrada() from public, anon;
revoke all on function public.perfil_para_redefinir(uuid) from public, anon;
revoke all on function public.criar_empresa(text, text, text, text, integer, text) from public, anon, authenticated;
revoke all on function public.registrar_uso_caminhao(uuid, uuid, uuid, uuid, timestamptz, uuid) from public, anon, authenticated;
revoke all on function public.definir_caminhao_atual(uuid, uuid, timestamptz) from public, anon;
revoke all on function public.sync_gravar_item(text, jsonb, uuid, uuid, uuid) from public, anon, authenticated;
revoke all on function public.sincronizar_lote(jsonb) from public, anon;
revoke all on function public.baixar_alteracoes(timestamptz) from public, anon;
revoke all on function public.login_cpf_preparar(text, text) from public, anon, authenticated;
revoke all on function public.login_cpf_registrar(text, text, boolean) from public, anon, authenticated;

grant execute on function public.so_digitos(text) to authenticated;
grant execute on function public.cpf_valido(text) to authenticated;
grant execute on function public.normalizar_placa(text) to authenticated;
grant execute on function public.situacao_acesso() to authenticated;
grant execute on function public.completar_cadastro(text, text) to authenticated;
grant execute on function public.pedir_entrada(text) to authenticated;
grant execute on function public.decidir_entrada(uuid, boolean) to authenticated;
grant execute on function public.gerar_novo_codigo_entrada() to authenticated;
grant execute on function public.perfil_para_redefinir(uuid) to authenticated;
grant execute on function public.definir_caminhao_atual(uuid, uuid, timestamptz) to authenticated;
grant execute on function public.sincronizar_lote(jsonb) to authenticated;
grant execute on function public.baixar_alteracoes(timestamptz) to authenticated;
grant execute on function public.criar_empresa(text, text, text, text, integer, text) to service_role;
grant execute on function public.login_cpf_preparar(text, text) to service_role;
grant execute on function public.login_cpf_registrar(text, text, boolean) to service_role;
