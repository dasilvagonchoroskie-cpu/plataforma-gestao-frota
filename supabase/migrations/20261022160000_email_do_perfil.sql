-- E-mail para recuperar a senha (22/10/2026, pedido do Evandro).
--
-- A recuperação de senha passa a ser por link no e-mail. O motorista, que
-- entra com CPF, cadastra um e-mail de verdade no app e confirma pelo link;
-- quando o Supabase Auth troca o e-mail do login, este gatilho leva o e-mail
-- novo para o perfil e para o cadastro de motorista (o login por CPF procura
-- o e-mail no perfil). Não apaga nada.

create or replace function public.sincronizar_email_perfil()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.perfis p set email = new.email
   where p.id = new.id and p.email is distinct from new.email;
  update public.motoristas m set email = new.email
   where m.perfil_id = new.id and m.email is distinct from new.email;
  return new;
end;
$$;

revoke all on function public.sincronizar_email_perfil() from public, anon, authenticated;

drop trigger if exists sincronizar_email_perfil on auth.users;
create trigger sincronizar_email_perfil
after update of email on auth.users
for each row
when (old.email is distinct from new.email and new.email is not null)
execute function public.sincronizar_email_perfil();
