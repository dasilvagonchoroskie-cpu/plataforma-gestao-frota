// Apoio comum das Edge Functions: respostas, CORS e chaves do servidor.
// As chaves vêm do ambiente do Supabase; nada de segredo fica no código.
import { createClient, type SupabaseClient } from "jsr:@supabase/supabase-js@2";

export const cors: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

export function resposta(corpo: unknown, status = 200): Response {
  return new Response(JSON.stringify(corpo), {
    status,
    headers: { ...cors, "Content-Type": "application/json; charset=utf-8" },
  });
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
