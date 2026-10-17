-- Isolamento entre empresas e perfis (RLS) e o fluxo de cadastro e entrada.
begin;
\ir apoio/fixtures.psql

create or replace function pg_temp.erro_anon(p_sql text) returns text language plpgsql as $$
begin
  begin
    execute 'set local role anon';
    execute p_sql;
    execute 'reset role';
    return 'ok';
  exception when others then
    return sqlstate;
  end;
end;
$$;

select plan(44);

-- Preparação conferida
select is((select count(*)::int from public.motoristas where empresa_id = pg_temp.fx('empresa_x')), 2,
  'empresa X tem os motoristas A e B aprovados');
select is((select papel from public.perfis where id = pg_temp.fx('u_dono_x')), 'dono',
  'dono entra na empresa pelo e-mail autorizado (maiúsculas e espaços ignorados)');
select is((select empresa_id from public.perfis where id = pg_temp.fx('u_gestor_x')), pg_temp.fx('empresa_x'),
  'gestor autorizado pelo dono entra na empresa X');
select is((select count(*)::int from public.fretes), 3, 'três fretes gravados pela sincronização');

-- Motorista A x motorista B (mesma empresa)
select is(pg_temp.como(pg_temp.fx('u_a'), 'select to_jsonb(count(*)) from public.fretes'), '1'::jsonb,
  'motorista A vê só um frete');
select is(pg_temp.como(pg_temp.fx('u_a'), format('select to_jsonb(count(*)) from public.fretes where id = %L', pg_temp.fx('frete_b'))),
  '0'::jsonb, 'motorista A não vê o frete do motorista B');
select is(pg_temp.como(pg_temp.fx('u_a'), format('select to_jsonb(count(*)) from public.fretes_efetivos where id = %L', pg_temp.fx('frete_b'))),
  '0'::jsonb, 'motorista A também não vê o frete de B pela view de valores efetivos');
select is(pg_temp.como(pg_temp.fx('u_a'), 'select to_jsonb(count(*)) from public.motoristas'), '1'::jsonb,
  'motorista A vê só a própria linha de motorista');
select is(pg_temp.como(pg_temp.fx('u_a'), format('select to_jsonb(count(*)) from public.perfis where id = %L', pg_temp.fx('u_b'))),
  '0'::jsonb, 'motorista A não vê o perfil de B');
select is(pg_temp.como(pg_temp.fx('u_a'), 'select to_jsonb(count(*)) from public.acessos_autorizados'), '0'::jsonb,
  'motorista não vê a lista de acessos autorizados');
select is(pg_temp.como(pg_temp.fx('u_a'), 'select to_jsonb(count(*)) from public.auditoria'), '0'::jsonb,
  'motorista não vê a auditoria');
select is(pg_temp.como(pg_temp.fx('u_a'), $q$select public.situacao_acesso() -> 'empresa' -> 'codigo_entrada'$q$), 'null'::jsonb,
  'motorista não recebe o código de entrada da empresa');

-- Empresa X x empresa Y
select is(pg_temp.como(pg_temp.fx('u_gestor_x'), 'select to_jsonb(count(*)) from public.fretes'), '2'::jsonb,
  'gestor X vê os dois fretes da empresa X');
select is(pg_temp.como(pg_temp.fx('u_gestor_x'), format('select to_jsonb(count(*)) from public.fretes where id = %L', pg_temp.fx('frete_c'))),
  '0'::jsonb, 'gestor X não vê o frete da empresa Y');
select is(pg_temp.como(pg_temp.fx('u_gestor_x'), format('select to_jsonb(count(*)) from public.empresas where id = %L', pg_temp.fx('empresa_y'))),
  '0'::jsonb, 'empresa X não vê a empresa Y');
select is(pg_temp.como(pg_temp.fx('u_gestor_x'), format('select to_jsonb(count(*)) from public.caminhoes where id = %L', pg_temp.fx('cam_y1'))),
  '0'::jsonb, 'empresa X não vê caminhão da empresa Y');
select is(pg_temp.como(pg_temp.fx('u_dono_y'), 'select to_jsonb(count(*)) from public.fretes'), '1'::jsonb,
  'dono Y vê só o frete da empresa Y');
select ok(pg_temp.como(pg_temp.fx('u_gestor_x'), $q$select public.situacao_acesso() -> 'empresa' -> 'codigo_entrada'$q$) <> 'null'::jsonb,
  'gestor recebe o código de entrada da empresa');

-- Conta sem vínculo não enxerga nada
select is(pg_temp.como(pg_temp.fx('u_d'), $q$select to_jsonb(
  (select count(*) from public.fretes) + (select count(*) from public.empresas) + (select count(*) from public.caminhoes)
  + (select count(*) from public.motoristas) + (select count(*) from public.categorias_gasto)
  + (select count(*) from public.vales) + (select count(*) from public.perfis where id <> auth.uid()))$q$), '0'::jsonb,
  'conta sem vínculo com empresa não vê nenhum dado');
select is(pg_temp.como(pg_temp.fx('u_d'), $q$select public.situacao_acesso() -> 'empresa'$q$), 'null'::jsonb,
  'conta sem vínculo não tem empresa');

-- Visitante sem login (anon) não lê nada
select is(pg_temp.erro_anon('select count(*) from public.fretes'), '42501', 'sem login não lê fretes');
select is(pg_temp.erro_anon('select public.situacao_acesso()'), '42501', 'sem login não chama as funções');

-- Ninguém apaga nem altera o lançamento original direto
select is(pg_temp.erro_como(pg_temp.fx('u_gestor_x'), format('delete from public.fretes where id = %L', pg_temp.fx('frete_a'))),
  '42501', 'gestor não apaga lançamento original');
select is(pg_temp.erro_como(pg_temp.fx('u_gestor_x'), format('update public.fretes set saldo_centavos = 1 where id = %L', pg_temp.fx('frete_a'))),
  '42501', 'gestor não altera lançamento original');
select is(pg_temp.erro_como(pg_temp.fx('u_a'), format('update public.fretes set saldo_centavos = 1 where id = %L', pg_temp.fx('frete_a'))),
  '42501', 'motorista não altera lançamento direto na tabela');
select is(pg_temp.erro_como(pg_temp.fx('u_a'), format($q$insert into public.vales (id, empresa_id, motorista_id, data, valor_centavos)
  values (gen_random_uuid(), %L, %L, now(), 100)$q$, pg_temp.fx('empresa_x'), pg_temp.fx('mot_a'))),
  '42501', 'motorista não grava direto na tabela (só pela sincronização)');
select is(pg_temp.erro_como(pg_temp.fx('u_a'), $q$update public.perfis set papel = 'dono' where id = auth.uid()$q$),
  '42501', 'motorista não muda o próprio papel');
select is(pg_temp.erro_como(pg_temp.fx('u_a'), format('delete from public.empresas where id = %L', pg_temp.fx('empresa_x'))),
  '42501', 'ninguém apaga empresa');

-- Chave composta: mesmo sem RLS, frete de X não aponta para caminhão de Y
select throws_ok(format($q$insert into public.fretes (id, empresa_id, motorista_id, caminhao_id, origem, destino,
  data_carga, percentual_comissao, comissao_sobre_bruto) values (gen_random_uuid(), %L, %L, %L, 'A', 'B', now(), 13, false)$q$,
  pg_temp.fx('empresa_x'), pg_temp.fx('mot_a'), pg_temp.fx('cam_y1')), '23503', null,
  'frete da empresa X não pode apontar para caminhão da empresa Y');

-- Cadastro: CPF e mensagens em português
select is(pg_temp.mensagem_como(pg_temp.fx('u_d'), $q$select public.completar_cadastro('Fulano', '123.456.789-00')$q$),
  'O CPF não está certo. Confira os números.', 'CPF com dígito errado é recusado');
select is(pg_temp.mensagem_como(pg_temp.fx('u_d'), $q$select public.completar_cadastro('Fulano', '52998224725')$q$),
  'Este CPF já tem cadastro. Use "Esqueci a senha" para entrar.', 'CPF repetido é recusado');

-- Entrada na empresa
select is(pg_temp.como(pg_temp.fx('u_d'), $q$select public.pedir_entrada('ZZZZZZ') -> 'codigo'$q$), '"codigo_invalido"'::jsonb,
  'código errado não cria pedido');
select is(pg_temp.como(pg_temp.fx('u_d'), format('select public.pedir_entrada(%L) -> %L',
  (select codigo_entrada from public.empresas where id = pg_temp.fx('empresa_x')), 'status')), '"pendente"'::jsonb,
  'código certo cria pedido pendente');
select is(pg_temp.como(pg_temp.fx('u_d'), 'select to_jsonb(count(*)) from public.fretes'), '0'::jsonb,
  'motorista aguardando aprovação continua sem ver dados');
select is(pg_temp.erro_como(pg_temp.fx('u_a'), format('select public.decidir_entrada(%L, true)',
  (select id from public.pedidos_entrada where perfil_id = pg_temp.fx('u_d')))), '42501', 'motorista não aprova pedido');
select is(pg_temp.mensagem_como(pg_temp.fx('u_dono_y'), format('select public.decidir_entrada(%L, true)',
  (select id from public.pedidos_entrada where perfil_id = pg_temp.fx('u_d')))), 'Pedido não encontrado.',
  'dono de outra empresa não decide o pedido');
select is(pg_temp.como(pg_temp.fx('u_gestor_x'), format('select public.decidir_entrada(%L, false) -> %L',
  (select id from public.pedidos_entrada where perfil_id = pg_temp.fx('u_d')), 'status')), '"recusado"'::jsonb,
  'gestor recusa o pedido');
select is(pg_temp.como(pg_temp.fx('u_d'), $q$select public.situacao_acesso() -> 'pedido' -> 'status'$q$), '"recusado"'::jsonb,
  'o motorista vê que o pedido foi recusado');

-- Código novo: o anterior deixa de valer
insert into fx select 'codigo_antigo_x', gen_random_uuid();
create temp table codigo_antigo as select codigo_entrada from public.empresas where id = pg_temp.fx('empresa_x');
select ok(pg_temp.como(pg_temp.fx('u_gestor_x'), 'select to_jsonb(public.gerar_novo_codigo_entrada())') is not null,
  'gestor gera outro código');
select is(pg_temp.como(pg_temp.fx('u_d'), format('select public.pedir_entrada(%L) -> %L',
  (select codigo_entrada from codigo_antigo), 'codigo')), '"codigo_invalido"'::jsonb, 'o código antigo deixa de valer');

-- Desativar motorista corta o acesso
select pg_temp.como(pg_temp.fx('u_gestor_x'), format($q$update public.motoristas set ativo = false where id = %L returning '{}'::jsonb$q$,
  pg_temp.fx('mot_b')));
select is(pg_temp.como(pg_temp.fx('u_b'), 'select to_jsonb(count(*)) from public.fretes'), '0'::jsonb,
  'motorista desativado não vê mais nada');
select is(pg_temp.erro_como(pg_temp.fx('u_b'), $q$select public.sincronizar_lote('{"itens": []}')$q$), '42501',
  'motorista desativado não envia mais');

-- Gestão de gestores: só o dono
select is(pg_temp.erro_como(pg_temp.fx('u_gestor_x'), $q$insert into public.acessos_autorizados (id, empresa_id, email, papel)
  values (gen_random_uuid(), public.empresa_do_usuario(), 'novo@teste.com', 'gestor')$q$), '42501',
  'gestor não autoriza outros gestores');
select pg_temp.como(pg_temp.fx('u_dono_x'), $q$update public.acessos_autorizados set ativo = false
  where email = 'gestor.x@teste.com' returning '{}'::jsonb$q$);
select is(pg_temp.como(pg_temp.fx('u_gestor_x'), 'select to_jsonb(count(*)) from public.fretes'), '0'::jsonb,
  'gestor com acesso retirado pelo dono deixa de ver os dados');

select * from finish();
rollback;
