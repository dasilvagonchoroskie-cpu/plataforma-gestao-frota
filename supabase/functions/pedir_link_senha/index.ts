// Pedir o link para criar uma senha nova, por e-mail.
//
// Dono e gestor informam o e-mail. O motorista informa o CPF: o link vai para
// o e-mail que ele cadastrou e confirmou no app (sem e-mail confirmado, nada é
// enviado e ele pede uma senha provisória ao patrão). O Supabase Auth manda o
// e-mail com o link (modelo supabase/templates/link_senha.html), que abre a
// página do painel onde a pessoa cria a senha nova.
// A resposta é sempre a mesma e leva o mesmo tempo, exista ou não a conta.
// Limites: 3 pedidos por hora para o mesmo CPF ou e-mail e 10 por hora por IP.
import {
  clientePublico,
  clienteServidor,
  cpfValido,
  emailInterno,
  emailValido,
  espera,
  ipDoCliente,
  lerCorpo,
  resposta,
  servir,
} from "../_compartilhado/apoio.ts";

const TEMPO_FIXO = 1200;

servir(async (req) => {
  const inicio = Date.now();
  const corpo = await lerCorpo(req);
  const bruto = String(corpo.identificador ?? "").trim().toLowerCase().slice(0, 254);
  const porCpf = !bruto.includes("@");
  const cpf = bruto.replace(/\D/g, "");
  if (porCpf ? !cpfValido(cpf) : !emailValido(bruto)) {
    return resposta({
      ok: false,
      codigo: "invalido",
      mensagem: porCpf ? "O CPF não está certo. Confira os números." : "Este e-mail não parece certo. Confira.",
    }, 400);
  }

  const servidor = clienteServidor();
  const ip = ipDoCliente(req);
  const umaHora = new Date(Date.now() - 60 * 60 * 1000).toISOString();
  const contar = async (chave: string) => {
    const { count } = await servidor.from("tentativas_acesso").select("id", { count: "exact", head: true })
      .eq("tipo", "login_cpf").eq("chave", chave).gte("criado_em", umaHora);
    return count ?? 0;
  };
  const chaveId = `link:${porCpf ? cpf : bruto}`;
  const chaveIp = ip === "-" ? null : `link:ip:${ip}`;
  if ((await contar(chaveId)) >= 3 || (chaveIp && (await contar(chaveIp)) >= 10)) {
    return resposta({
      ok: false,
      codigo: "muitos_pedidos",
      mensagem: "Muitos pedidos seguidos. Espere uma hora e tente de novo.",
    }, 429);
  }
  await servidor.from("tentativas_acesso").insert([
    { tipo: "login_cpf", chave: chaveId, sucesso: true },
    ...(chaveIp ? [{ tipo: "login_cpf", chave: chaveIp, sucesso: true }] : []),
  ]);

  let email: string | null = porCpf ? null : bruto;
  if (porCpf) {
    const { data: perfil } = await servidor.from("perfis").select("email")
      .eq("cpf", cpf).eq("ativo", true).is("apagado_em", null).maybeSingle();
    if (perfil?.email && !emailInterno(perfil.email)) email = perfil.email;
  }
  // Erros do Supabase Auth (conta que não existe, limite) não mudam a resposta.
  if (email) await clientePublico().auth.resetPasswordForEmail(email).catch(() => {});

  const passou = Date.now() - inicio;
  if (passou < TEMPO_FIXO) await espera(TEMPO_FIXO - passou);
  return resposta({
    ok: true,
    mensagem: porCpf
      ? "Se este CPF tiver um e-mail confirmado, mandamos um link para ele. Abra o e-mail e toque em Criar senha nova."
      : "Se este e-mail tiver conta, mandamos um link para ele. Abra o e-mail e toque em Criar senha nova.",
  });
}, "Não deu para pedir o link agora. Tente de novo em instantes.");
