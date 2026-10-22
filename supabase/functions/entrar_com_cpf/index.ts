// Login do motorista com CPF e senha.
//
// Acha o login interno ligado ao CPF, confere a senha no Supabase Auth e
// devolve a sessão. O erro é sempre o mesmo ("CPF ou senha incorretos"),
// exista ou não o CPF, com o mesmo tempo de resposta, e depois de 5 erros
// seguidos o CPF e o aparelho ficam bloqueados por 15 minutos (contagem no
// banco: login_cpf_preparar / login_cpf_registrar).
// Contas antigas, com o login interno tirado do CPF, trocam para um login
// sorteado aqui, no primeiro login certo (ninguém consegue mais adivinhar o
// login interno e tentar senhas direto no Supabase Auth).
import { type SupabaseClient } from "jsr:@supabase/supabase-js@2";
import {
  clientePublico,
  clienteServidor,
  emailInternoAntigo,
  emailInternoNovo,
  espera,
  lerCorpo,
  resposta,
  servir,
} from "../_compartilhado/apoio.ts";

const ERRO = "CPF ou senha incorretos.";

async function trocarLoginInterno(servidor: SupabaseClient, id: string, antigo: string): Promise<void> {
  const novo = emailInternoNovo();
  const { error } = await servidor.auth.admin.updateUserById(id, { email: novo, email_confirm: true });
  if (error) return;
  const { error: erroPerfil } = await servidor.from("perfis").update({ email: novo }).eq("id", id).eq("email", antigo);
  if (erroPerfil) {
    // Volta como estava: o perfil e o login precisam ter o mesmo e-mail.
    await servidor.auth.admin.updateUserById(id, { email: antigo, email_confirm: true });
    return;
  }
  await servidor.from("motoristas").update({ email: novo }).eq("perfil_id", id).eq("email", antigo);
}

servir(async (req) => {
  const inicio = Date.now();
  const corpo = await lerCorpo(req);
  const cpf = String(corpo.cpf ?? "").replace(/\D/g, "");
  const senha = String(corpo.senha ?? "");
  const aparelho = String(corpo.aparelho ?? "").slice(0, 80);
  if (cpf.length !== 11 || senha.length === 0 || senha.length > 72) {
    return resposta({ ok: false, codigo: "invalido", mensagem: ERRO }, 401);
  }

  const servidor = clienteServidor();
  const { data: preparo, error: erroPreparo } = await servidor.rpc("login_cpf_preparar", {
    p_cpf: cpf,
    p_aparelho: aparelho,
  });
  if (erroPreparo) throw erroPreparo;
  if (preparo?.bloqueado) {
    return resposta({
      ok: false,
      codigo: "bloqueado",
      mensagem: "Muitas tentativas erradas. Espere 15 minutos e tente de novo.",
    }, 429);
  }

  let sessao = null;
  if (preparo?.email) {
    const { data, error } = await clientePublico().auth.signInWithPassword({
      email: preparo.email,
      password: senha,
    });
    if (!error && data.session) sessao = data.session;
  }

  await servidor.rpc("login_cpf_registrar", { p_cpf: cpf, p_aparelho: aparelho, p_sucesso: !!sessao });

  if (!sessao) {
    // Mesmo tempo de resposta com ou sem CPF cadastrado.
    const passou = Date.now() - inicio;
    if (passou < 700) await espera(700 - passou);
    return resposta({ ok: false, codigo: "incorreto", mensagem: ERRO }, 401);
  }

  if (emailInternoAntigo(preparo.email)) {
    await trocarLoginInterno(servidor, sessao.user.id, preparo.email).catch(() => {});
  }

  return resposta({
    ok: true,
    access_token: sessao.access_token,
    refresh_token: sessao.refresh_token,
    expires_in: sessao.expires_in,
    expires_at: sessao.expires_at,
    token_type: sessao.token_type,
    trocar_senha: sessao.user?.user_metadata?.trocar_senha === true,
  });
}, "Não deu para entrar agora. Tente de novo em instantes.");
