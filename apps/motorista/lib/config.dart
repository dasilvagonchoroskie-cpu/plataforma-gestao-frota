// Endereço do Supabase da plataforma e a chave PÚBLICA (publishable).
// A chave pública pode ficar no app: quem protege os dados são as regras do
// banco (RLS). A chave secreta (service_role) nunca entra aqui.
const supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://uinvhwhqhudniipobslu.supabase.co',
);
const supabaseChavePublica = String.fromEnvironment(
  'SUPABASE_CHAVE',
  defaultValue: 'sb_publishable_nM7GeKdmBtrk7VxUBk6s3A_e9Yc9Mdn',
);

const versaoApp = '0.7.0';
