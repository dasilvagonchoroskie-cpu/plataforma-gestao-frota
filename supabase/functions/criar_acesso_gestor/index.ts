// O dono cria (ou renova) o acesso de um gestor: libera o e-mail na empresa
// e gera uma senha provisória, que aparece só para o dono. O gestor entra com
// e-mail e essa senha e o app pede para trocar. Não depende de envio de e-mail.
import { clientePublico, clienteServidor, emailValido, lerCorpo, resposta, senhaProvisoria, servir } from "../_compartilhado/apoio.ts";

const recusa = (status: number, mensagem: string) => resposta({ ok: false, mensagem }, status);

servir(async (req) => {
  const token = req.headers.get("Authorization") ?? "";
  if (!token.startsWith("Bearer ")) return recusa(401, "Entre na sua conta para continuar.");

  const corpo = await lerCorpo(req);
  const email = String(corpo.email ?? "").trim().toLowerCase();
  const nome = String(corpo.nome ?? "").trim().replace(/\s+/g, " ").slice(0, 120);

  const doDono = clientePublico(token);
  const { data: usuario, error: erroUsuario } = await doDono.auth.getUser(token.slice(7));
  if (erroUsuario || !usuario.user) return recusa(401, "Entre na sua conta para continuar.");
  const { data: ehDono } = await doDono.rpc("eh_dono");
  if (ehDono !== true) return recusa(403, "Só o dono da empresa cria acesso de gestor.");
  const { data: empresa } = await doDono.rpc("empresa_do_usuario");
  if (!empresa) return recusa(403, "Só o dono da empresa cria acesso de gestor.");

  if (!emailValido(email)) return recusa(400, "Este e-mail não parece certo. Confira.");
  if (email === (usuario.user.email ?? "").toLowerCase()) {
    return recusa(400, "Para trocar a sua própria senha use Configurações, Trocar a senha.");
  }

  const servidor = clienteServidor();
  const { data: perfil } = await servidor.from("perfis").select("id, papel, empresa_id, nome")
    .eq("email", email).maybeSingle();
  if (perfil && (perfil.papel === "motorista" || (perfil.empresa_id && perfil.empresa_id !== empresa))) {
    return recusa(409, "Este e-mail já é usado em outra conta. Use outro e-mail.");
  }
  if (!perfil && nome.length < 2) return recusa(400, "Escreva o nome da pessoa.");

  // Libera o e-mail na empresa (gestor), se ainda não estiver liberado.
  const { data: acesso } = await servidor.from("acessos_autorizados").select("id, papel, ativo")
    .eq("empresa_id", empresa).eq("email", email).is("apagado_em", null).maybeSingle();
  let papel = acesso?.papel ?? "gestor";
  if (!acesso) {
    const { error } = await servidor.from("acessos_autorizados")
      .insert({ id: crypto.randomUUID(), empresa_id: empresa, email, papel: "gestor" });
    if (error) throw error;
    papel = "gestor";
  } else if (!acesso.ativo) {
    const { error } = await servidor.from("acessos_autorizados").update({ ativo: true }).eq("id", acesso.id);
    if (error) throw error;
  }

  const senha = senhaProvisoria();
  let id: string;
  if (perfil) {
    id = perfil.id;
    const { error } = await servidor.auth.admin.updateUserById(id, {
      password: senha,
      email_confirm: true,
      user_metadata: { trocar_senha: true },
    });
    if (error) throw error;
    await servidor.from("perfis").update({ empresa_id: empresa, papel, ativo: true }).eq("id", id);
  } else {
    const { data: criado, error } = await servidor.auth.admin.createUser({
      email,
      password: senha,
      email_confirm: true,
      user_metadata: { trocar_senha: true },
    });
    if (error || !criado.user) {
      if (`${error?.message}`.toLowerCase().includes("already")) {
        return recusa(409, "Este e-mail já começou um cadastro pelo app. Peça para a pessoa terminar o cadastro.");
      }
      throw error;
    }
    id = criado.user.id;
    const { error: erroPerfil } = await servidor.from("perfis").insert({ id, empresa_id: empresa, papel, nome, email });
    if (erroPerfil) {
      await servidor.auth.admin.deleteUser(id);
      throw erroPerfil;
    }
  }

  await servidor.from("auditoria").insert({
    empresa_id: empresa,
    autor_id: usuario.user.id,
    acao: "criar_acesso_gestor",
    tabela: "perfis",
    registro_id: id,
    depois: { email, papel, trocar_senha: true },
  });

  return resposta({ ok: true, nome: perfil?.nome ?? nome, email, senha_provisoria: senha });
}, "Não deu para criar o acesso agora. Tente de novo.");
