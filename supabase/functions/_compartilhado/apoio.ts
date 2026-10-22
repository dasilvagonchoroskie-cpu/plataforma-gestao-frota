// Apoio comum das Edge Functions: entrada e saída, CORS, IP, senhas e chaves.
// As chaves vêm do ambiente do Supabase; nada de segredo fica no código.
import { createClient, type SupabaseClient } from "jsr:@supabase/supabase-js@2";

/** Maior pedido aceito (bytes). Os pedidos do app têm poucas centenas. */
const LIMITE_CORPO = 16 * 1024;

/**
 * Sites que podem chamar as funções pelo navegador (o painel web). Os apps de
 * celular não mandam Origin e não dependem disto. Para trocar sem mexer no
 * código: segredo ORIGENS_PERMITIDAS nas Edge Functions (lista com vírgulas).
 */
const ORIGENS = (Deno.env.get("ORIGENS_PERMITIDAS") ?? "https://dasilvagonchoroskie-cpu.github.io")
  .split(",").map((s) => s.trim()).filter(Boolean);

function cabecalhosCors(req: Request): Record<string, string> {
  const origem = req.headers.get("Origin") ?? "";
  const liberada = ORIGENS.includes(origem) || /^http:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(origem);
  return {
    ...(liberada ? { "Access-Control-Allow-Origin": origem } : {}),
    "Vary": "Origin",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Max-Age": "600",
  };
}

export function resposta(corpo: unknown, status = 200): Response {
  return new Response(JSON.stringify(corpo), {
    status,
    headers: { "Content-Type": "application/json; charset=utf-8" },
  });
}

/**
 * Atende só POST, recusa pedido grande demais e põe os cabeçalhos de CORS e
 * de segurança em toda resposta. Erro inesperado vira mensagem genérica (sem
 * detalhe técnico nem dado de ninguém).
 */
export function servir(tratar: (req: Request) => Promise<Response>, falha: string): void {
  Deno.serve(async (req) => {
    const cors = cabecalhosCors(req);
    let r: Response;
    if (req.method === "OPTIONS") {
      r = new Response("ok");
    } else if (req.method !== "POST") {
      r = resposta({ ok: false, codigo: "metodo", mensagem: "Use POST." }, 405);
    } else if (Number(req.headers.get("content-length") ?? "0") > LIMITE_CORPO) {
      r = resposta({ ok: false, codigo: "grande", mensagem: "Pedido grande demais." }, 413);
    } else {
      try {
        r = await tratar(req);
      } catch (_e) {
        r = resposta({ ok: false, codigo: "falha", mensagem: falha }, 500);
      }
    }
    for (const [k, v] of Object.entries(cors)) r.headers.set(k, v);
    r.headers.set("Cache-Control", "no-store");
    r.headers.set("X-Content-Type-Options", "nosniff");
    return r;
  });
}

/** Lê o JSON do pedido (até LIMITE_CORPO). Pedido inválido vira objeto vazio. */
export async function lerCorpo(req: Request): Promise<Record<string, unknown>> {
  const texto = await req.text().catch(() => "");
  if (texto.length > LIMITE_CORPO) return {};
  try {
    const v = JSON.parse(texto);
    return v && typeof v === "object" && !Array.isArray(v) ? v as Record<string, unknown> : {};
  } catch {
    return {};
  }
}

/**
 * IP de quem chamou. O cf-connecting-ip é escrito pela Cloudflare e o aparelho
 * não consegue mudar; no x-forwarded-for, o começo da lista pode ser inventado
 * por quem chama, e o último endereço é o que o servidor viu de verdade.
 */
export function ipDoCliente(req: Request): string {
  const cf = req.headers.get("cf-connecting-ip")?.trim();
  if (cf) return cf.slice(0, 64);
  const lista = (req.headers.get("x-forwarded-for") ?? "").split(",").map((s) => s.trim()).filter(Boolean);
  return (lista.at(-1) ?? req.headers.get("x-real-ip") ?? "-").slice(0, 64) || "-";
}

function primeiraChave(lista: string | undefined): string | undefined {
  if (!lista) return undefined;
  try {
    const obj = JSON.parse(lista) as Record<string, string>;
    return obj["default"] ?? Object.values(obj)[0];
  } catch {
    return undefined;
  }
}

export const url = Deno.env.get("SUPABASE_URL")!;

/** Chave do servidor (service_role ou secret). Só existe dentro da função. */
export const chaveServidor = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
  primeiraChave(Deno.env.get("SUPABASE_SECRET_KEYS"))!;

/** Chave pública (anon ou publishable). */
export const chavePublica = Deno.env.get("SUPABASE_ANON_KEY") ??
  primeiraChave(Deno.env.get("SUPABASE_PUBLISHABLE_KEYS"))!;

export function clienteServidor(): SupabaseClient {
  return createClient(url, chaveServidor, { auth: { persistSession: false, autoRefreshToken: false } });
}

export function clientePublico(token?: string): SupabaseClient {
  return createClient(url, chavePublica, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: token ? { headers: { Authorization: token } } : undefined,
  });
}

export const espera = (ms: number) => new Promise((r) => setTimeout(r, ms));

/** Mensagem da regra de senha (a mesma no app, nas funções e no banco). */
export const MENSAGEM_SENHA = "A senha precisa ter pelo menos 8 caracteres, com letras e números.";

/** Regra de senha: de 8 a 72 caracteres, com pelo menos uma letra e um número. */
export function senhaAceita(senha: string): boolean {
  return senha.length >= 8 && senha.length <= 72 && /[A-Za-z]/.test(senha) && /[0-9]/.test(senha);
}

const ALFABETO_SENHA = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; // 32 símbolos: sem viés no sorteio

/** Senha provisória de 10 caracteres, com letras e números, sem 0/O e 1/I. */
export function senhaProvisoria(): string {
  for (;;) {
    const bytes = crypto.getRandomValues(new Uint8Array(10));
    const s = Array.from(bytes, (b) => ALFABETO_SENHA[b % ALFABETO_SENHA.length]).join("");
    if (senhaAceita(s)) return s;
  }
}

/** Confere os dois dígitos verificadores do CPF (só números). */
export function cpfValido(cpf: string): boolean {
  if (!/^\d{11}$/.test(cpf) || /^(\d)\1{10}$/.test(cpf)) return false;
  const d = cpf.split("").map(Number);
  const dv = (n: number) => {
    let soma = 0;
    for (let i = 0; i < n; i++) soma += d[i] * (n + 1 - i);
    const r = (soma * 10) % 11;
    return r === 10 ? 0 : r;
  };
  return dv(9) === d[9] && dv(10) === d[10];
}

const DOMINIO_MOTORISTA = "motorista.fortalezadigitalsecurity.com.br";

/**
 * Login interno do motorista (ele entra com CPF; este e-mail nunca recebe
 * nada). É sorteado, e não tirado do CPF: assim ninguém consegue tentar senhas
 * direto no Supabase Auth sem passar pelo bloqueio de tentativas daqui.
 */
export const emailInternoNovo = () => `m${crypto.randomUUID().replaceAll("-", "")}@${DOMINIO_MOTORISTA}`;

/** Login interno (não recebe e-mail): o motorista ainda não cadastrou um e-mail dele. */
export const emailInterno = (email: string) => email.toLowerCase().endsWith(`@${DOMINIO_MOTORISTA}`);

/** Contas antigas usavam m<CPF>@...; elas trocam para o sorteado no próximo login. */
export const emailInternoAntigo = (email: string) =>
  new RegExp(`^m\\d{11}@${DOMINIO_MOTORISTA.replaceAll(".", "\\.")}$`).test(email);

export const emailValido = (e: string) => e.length <= 254 && /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(e);
