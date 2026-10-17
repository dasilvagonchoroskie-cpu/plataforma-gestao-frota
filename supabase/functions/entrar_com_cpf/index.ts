// Login do motorista com CPF e senha.
//
// Acha o e-mail ligado ao CPF, confere a senha no Supabase Auth e devolve a
// sessão. O erro é sempre o mesmo ("CPF ou senha incorretos"), exista ou não
// o CPF, e depois de 5 erros seguidos o CPF e o aparelho ficam bloqueados por
// 15 minutos (contagem no banco: login_cpf_preparar / login_cpf_registrar).
import { clientePublico, clienteServidor, cors, espera, resposta } from "../_compartilhado/apoio.ts";

const ERRO = "CPF ou senha incorretos.";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return resposta({ ok: false, mensagem: "Use POST." }, 405);

  const inicio = Date.now();
  try {
    const corpo = await req.json().catch(() => ({}));
    const cpf = String(corpo.cpf ?? "").replace(/\D/g, "");
    const senha = String(corpo.senha ?? "");
    const aparelho = String(corpo.aparelho ?? "").slice(0, 80);
    if (cpf.length !== 11 || senha.length === 0) {
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

    return resposta({
      ok: true,
      access_token: sessao.access_token,
      refresh_token: sessao.refresh_token,
      expires_in: sessao.expires_in,
      expires_at: sessao.expires_at,
      token_type: sessao.token_type,
      trocar_senha: sessao.user?.user_metadata?.trocar_senha === true,
    });
  } catch (_e) {
    return resposta({ ok: false, codigo: "falha", mensagem: "Não deu para entrar agora. Tente de novo em instantes." }, 500);
  }
});
