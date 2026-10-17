// O gestor (ou dono) cria uma senha provisória para um motorista da empresa
// dele que perdeu o e-mail ou a senha. A senha aparece só para o gestor, uma
// vez, e o motorista troca no primeiro login (user_metadata.trocar_senha).
import { clientePublico, clienteServidor, cors, resposta } from "../_compartilhado/apoio.ts";

const ALFABETO = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";

function senhaProvisoria(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(8));
  return Array.from(bytes, (b) => ALFABETO[b % ALFABETO.length]).join("");
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return resposta({ ok: false, mensagem: "Use POST." }, 405);

  const token = req.headers.get("Authorization") ?? "";
  if (!token.startsWith("Bearer ")) {
    return resposta({ ok: false, mensagem: "Entre na sua conta para continuar." }, 401);
  }

  try {
    const corpo = await req.json().catch(() => ({}));
    const motoristaId = String(corpo.motorista_id ?? "");
    const doGestor = clientePublico(token);

    const { data: usuario, error: erroUsuario } = await doGestor.auth.getUser(token.slice(7));
    if (erroUsuario || !usuario.user) {
      return resposta({ ok: false, mensagem: "Entre na sua conta para continuar." }, 401);
    }

    // A conferência de permissão é do banco, com o token do próprio gestor.
    const { data: alvo, error } = await doGestor.rpc("perfil_para_redefinir", { p_motorista_id: motoristaId });
    if (error || !alvo) {
      return resposta({ ok: false, mensagem: error?.message ?? "Motorista não encontrado." }, 403);
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
  } catch (_e) {
    return resposta({ ok: false, mensagem: "Não deu para redefinir agora. Tente de novo." }, 500);
  }
});
