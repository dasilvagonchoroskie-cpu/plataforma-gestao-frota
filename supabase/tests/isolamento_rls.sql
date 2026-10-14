-- Testes de isolamento. NÃO executar em produção; o usuário pediu que esta versão
-- fosse somente escrita, sem executar em banco.
--
-- Requisitos para futura execução em um banco Supabase local/de desenvolvimento:
--   1. pgTAP habilitado.
--   2. Fixtures de teste já criadas: motorista A e motorista B na empresa X;
--      um frete de B e um frete de X; gestor X; empresa Y com caminhão Y;
--      motorista A e caminhão Y devem ter empresas diferentes (X e Y).
--   3. Passar os UUIDs abaixo como variáveis do psql (-v nome=uuid).
-- Nunca preencher com dados de produção.
--
-- Variáveis exigidas:
--   motorista_a_auth_id, motorista_a_id, frete_b_id, empresa_y_id,
--   gestor_x_auth_id, frete_x_id, empresa_x_id, caminhao_y_id, test_frete_id

begin;
select plan(4);

-- Motorista A não enxerga o frete do motorista B, mesmo ambos na empresa X.
set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', :'motorista_a_auth_id', true);
select set_config(
  'request.jwt.claims',
  json_build_object('sub', :'motorista_a_auth_id', 'role', 'authenticated')::text,
  true
);
select is(
  (select count(*)::integer from public.fretes where id = :'frete_b_id'),
  0,
  'motorista A não vê o frete do motorista B'
);

-- Uma empresa não consegue ler a linha raiz de outra empresa.
select is(
  (select count(*)::integer from public.empresas where empresa_id = :'empresa_y_id'),
  0,
  'empresa X não vê a empresa Y'
);

-- Gestor não tem privilégio nem política para apagar o lançamento original.
select set_config('request.jwt.claim.sub', :'gestor_x_auth_id', true);
select set_config(
  'request.jwt.claims',
  json_build_object('sub', :'gestor_x_auth_id', 'role', 'authenticated')::text,
  true
);
select throws_ok(
  pg_catalog.format('delete from public.fretes where id = %L::uuid', :'frete_x_id'),
  '42501',
  null,
  'gestor não apaga lançamento original'
);

-- Verifica a constraint composta sem RLS mascarar a violação: empresa X tenta
-- gravar frete apontando para caminhão Y. O FK (empresa_id, caminhao_id) deve falhar.
reset role;
select throws_ok(
  pg_catalog.format(
    'insert into public.fretes (
       id, empresa_id, motorista_id, caminhao_id, origem, destino, embarcador,
       data_carga, peso_carga_kg, valor_tonelada_centavos, adiantamento_centavos,
       saldo_centavos, percentual_comissao, comissao_sobre_bruto, pedagio_centavos,
       peso_descarga_kg, desconto_quebra_centavos
     ) values (
       %L::uuid, %L::uuid, %L::uuid, %L::uuid, ''Origem teste'', ''Destino teste'',
       ''Teste de isolamento'', pg_catalog.now(), 1, 0, 0, 0, 0, true, 0, 1, 0
     )',
    :'test_frete_id', :'empresa_x_id', :'motorista_a_id', :'caminhao_y_id'
  ),
  '23503',
  null,
  'frete da empresa X não pode apontar para caminhão da empresa Y'
);

select * from finish();
rollback;
