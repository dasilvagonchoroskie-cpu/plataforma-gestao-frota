// Recuperar o acesso sem e-mail: CPF (motorista) ou e-mail (dono e gestor),
// o código de recuperação que a pessoa guardou e uma senha nova.
//
// O banco confere o código (recuperacao_conferir: só o resumo cifrado fica
// guardado; 5 erros em 15 minutos bloqueiam). A resposta de erro é sempre a
// mesma e leva o mesmo tempo, exista ou não a conta. Deu certo: a senha muda
// e a pessoa recebe um código de recuperação novo (o antigo deixa de valer).
import {
  clienteServidor,
  espera,
  lerCorpo,
  MENSAGEM_SENHA,
  resposta,
  senhaAceita,
  servir,
} from "../_compartilhado/apoio.ts";

const ERRO = "CPF (ou e-mail) e código de recuperação não conferem.";

servir(async (req) => {
  const inicio = Date.now();
  const corpo = await lerCorpo(req);
  const identificador = String(corpo.identificador ?? "").trim().slice(0, 120);
  const codigo = String(corpo.codigo ?? "").slice(0, 40);
  const senha = String(corpo.senha_nova ?? "");
  const aparelho = String(corpo.aparelho ?? "").slice(0, 80) || "-";
  if (identificador.length < 5 || codigo.replace(/[^A-Za-z0-9]/g, "").length !== 12) {
    return resposta({ ok: false, codigo: "invalido", mensagem: ERRO }, 400);
  }
  if (!senhaAceita(senha)) {
    return resposta({ ok: false, codigo: "senha_fraca", mensagem: MENSAGEM_SENHA }, 400);
  }

  const servidor = clienteServidor();
  const { data: conferido, error } = await servidor.rpc("recuperacao_conferir", {
    p_identificador: identificador,
    p_codigo: codigo,
    p_aparelho: aparelho,
  });
  if (error) throw error;
  if (conferido?.bloqueado) {
    return resposta({ ok: false, codigo: "bloqueado", mensagem: "Muitas tentativas erradas. Espere 15 minutos e tente de novo." }, 429);
  }
  if (!conferido?.ok) {
    const passou = Date.now() - inicio;
    if (passou < 700) await espera(700 - passou);
    return resposta({ ok: false, codigo: "incorreto", mensagem: ERRO }, 401);
  }

  const { error: erroSenha } = await servidor.auth.admin.updateUserById(conferido.perfil_id, {
    password: senha,
    user_metadata: { trocar_senha: false },
  });
  if (erroSenha) throw erroSenha;

  const { data: novo, error: erroNovo } = await servidor.rpc("novo_codigo_recuperacao", { p_perfil: conferido.perfil_id });
  if (erroNovo) throw erroNovo;

  return resposta({ ok: true, papel: conferido.papel, email: conferido.email, codigo_novo: novo });
}, "Não deu para recuperar agora. Tente de novo em instantes.");
