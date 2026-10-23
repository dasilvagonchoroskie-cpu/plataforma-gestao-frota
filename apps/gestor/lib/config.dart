// Endereço do Supabase da plataforma e a chave PÚBLICA (publishable).
// A chave pública pode ficar no app e no painel web: quem protege os dados
// são as regras do banco (RLS). A chave secreta (service_role) nunca entra aqui.
const supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://uinvhwhqhudniipobslu.supabase.co');
const supabaseChavePublica = String.fromEnvironment(
  'SUPABASE_CHAVE',
  defaultValue: 'sb_publishable_nM7GeKdmBtrk7VxUBk6s3A_e9Yc9Mdn',
);

const versaoApp = '0.7.1';

/// Endereço do painel web (vai no recado para o dono de uma empresa nova).
/// A esteira passa o endereço certo na compilação (--dart-define=PAINEL_URL).
const enderecoPainel = String.fromEnvironment(
  'PAINEL_URL',
  defaultValue: 'https://dasilvagonchoroskie-cpu.github.io/plataforma-gestao-frota/',
);
