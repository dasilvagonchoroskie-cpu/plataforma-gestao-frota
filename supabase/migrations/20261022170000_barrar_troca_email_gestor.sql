-- Troca de e-mail pelo próprio usuário: só o motorista.
--
-- Por quê: para o motorista cadastrar o e-mail dele (o login dele é interno,
-- não recebe nada), a confirmação vai só para o e-mail novo
-- (mailer_secure_email_change_enabled = false). Para dono e gestor isso seria
-- um risco: quem roubasse a sessão trocaria o e-mail e depois a senha. Então o
-- banco recusa o pedido de troca de e-mail (coluna email_change do Supabase
-- Auth) de quem é dono ou gestor. O e-mail de dono e gestor só muda pela
-- plataforma (API de administração, que grava o e-mail direto).

create or replace function public.barrar_troca_email_gestor()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if coalesce(new.email_change, '') <> ''
     and new.email_change is distinct from old.email_change
     and exists (select 1 from public.perfis p where p.id = new.id and p.papel in ('dono', 'gestor')) then
    raise exception 'O e-mail de dono ou gestor só muda pela plataforma.' using errcode = '42501';
  end if;
  return new;
end;
$$;

revoke all on function public.barrar_troca_email_gestor() from public, anon, authenticated;

drop trigger if exists barrar_troca_email_gestor on auth.users;
create trigger barrar_troca_email_gestor
  before update of email_change on auth.users
  for each row
  execute function public.barrar_troca_email_gestor();
