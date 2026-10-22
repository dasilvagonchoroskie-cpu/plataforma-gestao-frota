// Cadastro do motorista sem e-mail: nome, CPF e senha.
//
// O piloto não depende de envio de e-mail. A conta nasce confirmada, com um
// login interno sorteado (nunca recebe mensagens); o motorista entra com CPF
// e senha (entrar_com_cpf) e depois pede entrada na empresa com o código
// individual que o gestor gerou para ele (entra na hora). O aceite dos termos
// marcado no cadastro fica registrado.
// Limite contra abuso: 5 cadastros por hora por aparelho e 20 por endereço IP
// (o IP verdadeiro, que quem chama não consegue inventar).
import {
  clienteServidor,
  cpfValido,
  emailInternoNovo,
  ipDoCliente,
  lerCorpo,
  MENSAGEM_SENHA,
  resposta,
  senhaAceita,
  servir,
} from "../_compartilhado/apoio.ts";

const recusa = (status: number, codigo: string, mensagem: string) => resposta({ ok: false, codigo, mensagem }, status);

servir(async (req) => {
  const corpo = await lerCorpo(req);
  const nome = String(corpo.nome ?? "").trim().replace(/\s+/g, " ");
  const cpf = String(corpo.cpf ?? "").replace(/\D/g, "");
  const senha = String(corpo.senha ?? "");
  const aparelho = String(corpo.aparelho ?? "").slice(0, 80) || "-";
  if (nome.length < 2 || nome.length > 120) return recusa(400, "nome_invalido", "Escreva o seu nome.");
  if (!cpfValido(cpf)) return recusa(400, "cpf_invalido", "O CPF não está certo. Confira os números.");
  if (!senhaAceita(senha)) return recusa(400, "senha_fraca", MENSAGEM_SENHA);

  const servidor = clienteServidor();
  const ip = ipDoCliente(req);
  const umaHora = new Date(Date.now() - 60 * 60 * 1000).toISOString();
  const contar = async (chave: string) => {
    const { count } = await servidor.from("tentativas_acesso").select("id", { count: "exact", head: true })
      .eq("tipo", "login_cpf").eq("chave", chave).gte("criado_em", umaHora);
    return count ?? 0;
  };
  const chaveAparelho = `cadastro:aparelho:${aparelho}`;
  const chaveIp = `cadastro:ip:${ip}`;
  if ((await contar(chaveAparelho)) >= 5 || (await contar(chaveIp)) >= 20) {
    return recusa(429, "muitas_tentativas", "Muitos cadastros seguidos. Espere uma hora e tente de novo.");
  }
  await servidor.from("tentativas_acesso").insert([
    { tipo: "login_cpf", chave: chaveAparelho, sucesso: true },
    { tipo: "login_cpf", chave: chaveIp, sucesso: true },
  ]);

  const emUso = () =>
    recusa(409, "cpf_em_uso",
      "Não deu para criar a conta com este CPF. Se você já tem conta, entre com CPF e senha ou use o código de recuperação.");
  const { data: existente } = await servidor.from("perfis").select("id").eq("cpf", cpf).maybeSingle();
  if (existente) return emUso();

  const email = emailInternoNovo();
  const { data: criado, error: erroCriar } = await servidor.auth.admin.createUser({
    email,
    password: senha,
    email_confirm: true,
    user_metadata: { nome },
  });
  if (erroCriar || !criado.user) throw erroCriar ?? new Error("sem usuário");

  const { error: erroPerfil } = await servidor.from("perfis").insert({
    id: criado.user.id,
    papel: "motorista",
    nome,
    cpf,
    email,
  });
  if (erroPerfil) {
    await servidor.auth.admin.deleteUser(criado.user.id);
    if (erroPerfil.code === "23505") return emUso();
    throw erroPerfil;
  }

  // Aceite dos Termos de Uso e da Política de Privacidade marcado na tela de
  // cadastro (versão, data e IP). Sem aceite aqui, o app pede depois de entrar.
  const termos = String(corpo.termos ?? "");
  if (/^\d{4}-\d{2}-\d{2}$/.test(termos)) {
    await servidor.from("aceites_termos").insert({ perfil_id: criado.user.id, versao: termos, ip: ip === "-" ? null : ip });
  }
  return resposta({ ok: true });
}, "Não deu para criar a conta agora. Tente de novo em instantes.");
