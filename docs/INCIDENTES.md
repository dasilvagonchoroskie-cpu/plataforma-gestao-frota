# Plano de resposta a incidentes de segurança

Para quando algo der errado: vazamento de dados, conta invadida, chave exposta, banco apagado ou app
adulterado. Quem decide e executa é o dono da plataforma (Evandro). Em dúvida, siga a ordem abaixo:
**conter → avaliar → avisar → corrigir → registrar**.

Contato da plataforma: gestaodefrota2027@gmail.com. Autoridade: ANPD (www.gov.br/anpd).

## 1. Conter (primeiros 30 minutos)

Escolha o que se aplica. Tudo pelo celular, sem computador.

| Situação | O que fazer agora |
|---|---|
| Alguém de fora está mexendo numa empresa | SQL Editor do Supabase: `select public.bloquear_empresa('ID', 'Bloqueio de segurança.', null);` (fecha o acesso de todos dela na hora e não apaga nada). |
| Conta de dono, gestor ou motorista invadida | Dono: `select public.criar_login_dono('email', 'Nome', 'SenhaNova123');` troca a senha. Gestor: o dono gera senha nova em Configurações > Donos e gestores. Motorista: o gestor usa "Redefinir o acesso". No Supabase, Authentication > Users > o usuário > "Sign out user" ("Encerrar sessões") derruba as sessões abertas. |
| Chave do Supabase exposta (secret ou service_role) | Supabase > Project Settings ("Configurações do projeto") > API Keys ("Chaves de API"): crie uma chave secreta nova e apague ("Revoke") a exposta. As Edge Functions usam a chave do próprio ambiente e seguem funcionando. A chave pública (publishable) pode ficar nos apps: ela não abre nada sozinha. |
| Token de acesso do Supabase exposto | Supabase > Account preferences > Access Tokens: apague o token e crie outro; troque o segredo `SUPABASE_ACCESS_TOKEN` no GitHub. |
| `CHAVE_MESTRA` exposta | Crie uma frase nova e troque o segredo no GitHub. Consequências: os APKs ganham assinatura nova (todos reinstalam uma vez) e os backups antigos só abrem com a frase antiga (guarde a antiga em papel até os backups dela vencerem, 90 dias). |
| Conta do GitHub invadida | Troque a senha, ligue a verificação em duas etapas, revise Settings > Sessions e Settings > SSH and GPG keys, troque os dois segredos do repositório e o token do Supabase. Confira os últimos envios no ramo `main`. |
| Função com defeito sendo explorada | Supabase > Edge Functions > a função > publique uma versão que só responde "manutenção" (ou apague e publique de novo depois). Os apps mostram erro, mas os dados ficam protegidos. |
| Banco apagado ou dados corrompidos | Não mexa mais nele. Restaure o backup num projeto novo (`docs/OPERACAO.md`, "Restaurar de verdade"). |
| APK falso circulando | Avise as empresas: só instalar o APK enviado pelo dono da plataforma. A impressão digital do certificado oficial está no job "Publicar" da Esteira; APK com outra assinatura não é nosso. |

## 2. Avaliar (até 24 horas)

Anote as respostas (num documento só seu, sem senhas):

- O que aconteceu, quando começou e quando foi percebido?
- Que dados podem ter sido vistos ou copiados? (Só lançamentos? CPF e nome? Senhas não, elas ficam
  cifradas.) De quais empresas e quantas pessoas?
- Ainda está acontecendo? A contenção funcionou?
- Onde olhar: Supabase > Logs ("Registros": API, Auth e Edge Functions); `public.auditoria_plataforma`
  (ações sobre empresas); `public.registros_acesso` (quem entrou, quando e de qual IP);
  `public.auditoria` (correções nos lançamentos); `public.registro_exclusoes`; Actions do GitHub.

**Há risco ou dano relevante para as pessoas?** (Ex.: CPF e nome expostos, acesso indevido aos
lançamentos.) Se sim, a comunicação abaixo é obrigatória (LGPD, art. 48).

## 3. Avisar

- **Empresas afetadas** (são as controladoras dos dados dos motoristas): e-mail ao dono de cada uma no
  mesmo dia em que confirmar o incidente, dizendo o que houve, que dados, o que já foi feito e o que ela
  precisa fazer.
- **Titulares** (motoristas, gestores, donos) e **ANPD**: quando houver risco ou dano relevante, em até
  **3 dias úteis** depois de saber do incidente (Resolução CD/ANPD nº 15/2024). O prazo conta de quando
  soube do incidente, não de quando terminou de avaliar. Agente de pequeno porte tem o prazo em dobro, mas
  não conte com isso: avise o quanto antes. A comunicação à ANPD é
  feita pelo formulário de "Comunicação de Incidente de Segurança" no site gov.br/anpd. Ela pede: o que
  aconteceu, os dados e as pessoas afetadas, as medidas de segurança que existiam, os riscos, as medidas
  tomadas e um contato.
- Modelo curto para a empresa:

  > Assunto: Aviso de incidente de segurança na Plataforma de Gestão de Frota
  >
  > Em [data] identificamos [o que aconteceu]. Os dados possivelmente afetados são [quais], de [quantas]
  > pessoas da sua empresa. Já fizemos: [contenção]. Recomendamos: [trocar senhas / avisar motoristas].
  > Seguimos investigando e mandaremos novidades até [data]. Contato: gestaodefrota2027@gmail.com.

## 4. Corrigir

- Corrigir a causa no código (migration, Edge Function ou app), com teste que prove a correção, pela
  Esteira. Nunca mexer direto no banco de produção sem migration.
- Se houve chave exposta, conferir que a varredura de segredos (fluxo "Segurança") passa e limpar o
  histórico do repositório, se for o caso.
- Liberar as empresas bloqueadas (`liberar_empresa`) só depois da correção.

## 5. Registrar

Guarde por 5 anos um resumo do incidente (o que houve, datas, dados e pessoas afetadas, avisos feitos,
correções), mesmo quando não precisar avisar a ANPD (Resolução CD/ANPD nº 15/2024). Atualize
este plano com o que aprendeu.

## Contatos úteis

- Supabase (suporte): pelo painel, Help ("Ajuda") > Contact support.
- GitHub (conteúdo sensível em cache ou forks): https://support.github.com.
- ANPD: https://www.gov.br/anpd.
