// O gestor (ou dono) cria uma senha provisória para um motorista da empresa
// dele que perdeu a senha. A senha aparece só para o gestor, uma vez, e o
// motorista troca no primeiro login (user_metadata.trocar_senha).
import { clientePublico, clienteServidor, lerCorpo, resposta, senhaProvisoria, servir } from "../_compartilhado/apoio.ts";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

servir(async (req) => {
  const token = req.headers.get("Authorization") ?? "";
  if (!token.startsWith("Bearer ")) {
    return resposta({ ok: false, mensagem: "Entre na sua conta para continuar." }, 401);
  }

  const corpo = await lerCorpo(req);
  const motoristaId = String(corpo.motorista_id ?? "");
  const doGestor = clientePublico(token);

  const { data: usuario, error: erroUsuario } = await doGestor.auth.getUser(token.slice(7));
  if (erroUsuario || !usuario.user) {
    return resposta({ ok: false, mensagem: "Entre na sua conta para continuar." }, 401);
  }
  if (!UUID.test(motoristaId)) return resposta({ ok: false, mensagem: "Motorista não encontrado." }, 403);

  // A conferência de permissão é do banco, com o token do próprio gestor.
  // Só repassa a mensagem dos erros escritos para o usuário (os que têm dica).
  const { data: alvo, error } = await doGestor.rpc("perfil_para_redefinir", { p_motorista_id: motoristaId });
  if (error || !alvo) {
    const mensagem = error?.hint ? error.message : "Motorista não encontrado.";
    return resposta({ ok: false, mensagem }, 403);
  }

  const senha = senhaProvisoria();
  const servidor = clienteServidor();
  const { error: erroSenha } = await servidor.auth.admin.updateUserById(alvo.perfil_id, {
    password: senha,
    user_metadata: { trocar_senha: true },
  });
  if (erroSenha) throw erroSenha;

  await servidor.from("auditoria").insert({
    empresa_id: alvo.empresa_id,
    autor_id: usuario.user.id,
    acao: "redefinir_acesso",
    tabela: "perfis",
    registro_id: alvo.perfil_id,
    depois: { trocar_senha: true },
  });

  return resposta({ ok: true, nome: alvo.nome, senha_provisoria: senha });
}, "Não deu para redefinir agora. Tente de novo.");
