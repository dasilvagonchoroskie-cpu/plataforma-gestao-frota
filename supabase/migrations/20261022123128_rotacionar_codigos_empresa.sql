-- Troca o código de entrada de todas as empresas (17/10 o código da empresa
-- piloto apareceu nos documentos do repositório público). O código da empresa
-- não aparece mais nos apps (cada motorista recebe um código individual), então
-- trocar não atrapalha ninguém. O código novo não é mostrado em lugar nenhum.
update public.empresas
   set codigo_entrada = public.gerar_codigo_entrada()
 where excluida_em is null;
