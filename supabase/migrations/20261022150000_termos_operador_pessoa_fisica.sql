-- Textos legais de 22/10/2026: quem oferece a Plataforma passa a aparecer
-- como pessoa física (Evandro, marca Fortaleza Digital Security) e a Política
-- conta das cópias de segurança criptografadas. Muda a versão: todos aceitam
-- de novo na próxima vez que abrirem o app ou o painel.
create or replace function public.versao_termos()
returns text
language sql
immutable
set search_path = ''
as $$
  select '2026-10-22'::text
$$;
