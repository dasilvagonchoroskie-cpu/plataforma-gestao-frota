# E-mail da plataforma (link para criar senha nova e confirmar e-mail)

Desde 22/10/2026 quem esquece a senha recebe um **link no e-mail** (o código de recuperação saiu dos apps):

- **Dono e gestor:** "Esqueci a senha" > digitam o e-mail > chega o link > o link abre o painel web, onde
  criam a senha nova. Depois disso, todas as sessões abertas em outros aparelhos são encerradas.
- **Motorista:** cadastra um e-mail (no cadastro ou em Configurações > "E-mail para recuperar a senha") e
  confirma pelo link. Depois, em "Esqueci a senha", digita o **CPF**: o link vai para o e-mail confirmado.
  Sem e-mail confirmado, o patrão cria uma senha provisória no painel (Motoristas > o nome > Redefinir o
  acesso).
- Quem pede a função `pedir_link_senha`: resposta e tempo iguais exista ou não a conta; até 3 pedidos por
  hora para o mesmo CPF ou e-mail e 10 por hora do mesmo IP.
- Modelos dos e-mails: `supabase/templates/link_senha.html` e `confirmar_email.html`, aplicados na nuvem pelo
  fluxo do banco (`supabase/auth-nuvem.json`, campo `modelos`). O link vale 1 hora e só uma vez.
- Dono e gestor **não** trocam o próprio e-mail pelo app (o banco recusa; migration
  `barrar_troca_email_gestor`): isso impede que alguém com a sessão roubada troque o e-mail e depois a senha.

## SMTP próprio (Brevo)

O envio que vem pronto no Supabase só entrega para **endereços da equipe do projeto** e no máximo **2
e-mails por hora**. Para motoristas e gestores receberem o link é preciso o **SMTP próprio**. Escolhido:
**Brevo** (300 e-mails por dia grátis, painel em português).

O dono configura direto no painel do Supabase (a chave nunca passa pelo chat nem pelo repositório):
Authentication ("Autenticação") > Emails ("E-mails") > SMTP Settings ("Configurações de SMTP") > Enable
Custom SMTP ("Ativar SMTP personalizado"):

| Campo | Valor |
|---|---|
| Sender email ("E-mail do remetente") | o remetente verificado no Brevo |
| Sender name ("Nome do remetente") | Plataforma de Gestão de Frota |
| Host ("Servidor") | smtp-relay.brevo.com |
| Port number ("Porta") | 587 |
| Username ("Usuário") | o **Login** da aba SMTP do Brevo (SMTP & API), parecido com `xxxx@smtp-brevo.com` |
| Password ("Senha") | a chave SMTP do Brevo |

O fluxo "Banco - backup diário e atualização na nuvem" confere a cada execução se o SMTP está ligado (sem
mostrar senha nem usuário) e avisa no registro quando não está. Com SMTP próprio, o limite do Supabase
passa a 30 e-mails por hora (Authentication > Rate Limits ("Limites")).

## Domínio e DNS (para não cair no spam)

Use um **subdomínio só para os e-mails de login**, por exemplo `acesso.fortalezadigitalsecurity.com.br`,
e o remetente `nao-responda@acesso.fortalezadigitalsecurity.com.br`. No painel onde o domínio está
registrado (Registro.br ou o provedor de DNS), crie os registros que o serviço de e-mail mostrar:

| Registro | Tipo | Valor (exemplo) | Para quê |
|---|---|---|---|
| SPF | TXT em `acesso` | `v=spf1 include:<do serviço> ~all` | diz quais servidores podem mandar e-mail pelo domínio |
| DKIM | TXT ou CNAME (o serviço informa o nome) | chave pública dada pelo serviço | assinatura que prova que o e-mail não foi alterado |
| DMARC | TXT em `_dmarc.acesso` | `v=DMARC1; p=none; rua=mailto:gestaodefrota2027@gmail.com` | o que fazer com e-mail falso e relatório para você |

Passos do DMARC: comece com `p=none` (só observa) por 2 a 4 semanas, olhando os relatórios; depois
`p=quarantine` (falso vai para o spam) e, quando estiver tudo certo, `p=reject`.

Remetente com endereço do Gmail (ou outro e-mail gratuito) costuma cair no spam, porque o Gmail não autoriza
o Brevo a mandar em nome dele. Para entregar bem, o próximo passo é autenticar o domínio no Brevo (Senders,
Domains & Dedicated IPs ("Remetentes, domínios e IPs") > Domains ("Domínios")) e usar o remetente do
subdomínio acima.

Depois de ligar o SMTP, teste "Esqueci a senha" com um e-mail de teste e confira se chega na caixa de
entrada (não no spam).
