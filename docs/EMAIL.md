# E-mail da plataforma (recuperar senha e avisos)

Hoje a plataforma **não depende de e-mail**: o motorista entra com CPF e senha, o dono cria os gestores
com senha provisória e todos recuperam o acesso com o **código de recuperação**. O e-mail serve para o
caminho antigo de "código por e-mail" (que ainda existe nos apps) e para avisos no futuro.

## O problema do e-mail padrão do Supabase

O envio que vem pronto no Supabase só entrega para **endereços da equipe do projeto** e no máximo
**2 e-mails por hora**, sem garantia (feito só para testes). Para donos e gestores de verdade receberem
e-mail, é preciso ligar um **SMTP próprio** (Supabase > Authentication > Emails > SMTP Settings ("Ajustes
de SMTP") > Enable custom SMTP ("Ligar SMTP próprio")). Com SMTP próprio, o limite passa a 30 por hora
(ajustável em Authentication > Rate Limits).

## Opções (preços de 2026; conferir na página de cada um antes de assinar)

| Serviço | Grátis | Pago | Observação |
|---|---|---|---|
| **Brevo** | 300 e-mails/dia, sem prazo | planos mensais | Painel em português, guia oficial para Supabase. **Recomendado para o piloto.** |
| Resend | 3.000/mês (100/dia) | a partir de ~US$ 20/mês | Muito simples; bom para desenvolvedor. |
| Amazon SES | crédito inicial só para conta nova | US$ 0,10 por 1.000 | Mais barato em volume; configuração mais técnica. |
| Zoho ZeptoMail | créditos iniciais | pago por pacote | Só e-mail transacional; boa entrega. |
| Postmark | 100/mês | US$ 15/mês | Excelente entrega; caro para o tamanho atual. |

A senha do SMTP é segredo: cola-se direto no Supabase, nunca no chat nem no repositório.

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

Depois de ligar o SMTP, teste "Esqueci a senha" com um e-mail de gestor de teste e confira se chega na
caixa de entrada (não no spam). Os modelos de e-mail ficam em `supabase/templates/`.
