# Passagem — decisões tomadas e pendências

Atualizado em 17/10/2026 pelo Claude Code. O usuário pediu para corrigir o que estava pronto e
terminar o resto. Onde a arquitetura deixava ponto em aberto, foi seguida a **proposta** escrita
nela (seção 14) e anotada aqui. Qualquer item pode ser mudado.

## Decisões provisórias (seguindo as propostas da arquitetura)

1. **Dono e gestor entram com e-mail e senha.** Motorista entra com CPF e senha (Edge Function).
2. **Motorista sem e-mail ou que perdeu o acesso:** o gestor redefine pelo painel (Edge Function
   `redefinir_acesso`); a senha provisória aparece só para o gestor e o motorista troca no primeiro login.
3. **Motorista pode editar ou apagar o próprio lançamento até o gestor corrigir.** Depois de corrigido,
   o servidor recusa mudanças do motorista (motivo `ajustado`) e o app mostra o aviso.
4. **Um gestor em uma empresa só** na versão 1.
5. **Código da empresa:** a função `situacao_acesso` só devolve o código para dono e gestor. A linha
   da empresa (com o código) continua legível por motorista já vinculado pelo RLS; risco baixo, porque
   quem usar o código ainda precisa da aprovação do gestor.
6. **Placa:** formatos brasileiros ABC1234 e ABC1D23, guardados sem hífen e em maiúsculas.
7. **Regras de acerto** (comissão padrão, base da comissão, gastos e vale) ficam na tabela `empresas` e
   só o dono muda. O motorista pode mudar a comissão em cada frete.
8. **Painel carrega todos os dados da empresa de uma vez** (piloto com até 5 caminhões). Se ficar
   lento, carregar por período (arquitetura, seção 5).
9. **Relatório por embarcador:** diesel e gastos entram só quando o motorista ligou ao frete; vale não
   entra em relatório de caminhão nem de embarcador (vale é do motorista).
10. **Km rodados do caminhão** = pelo odômetro das abastecidas (do último registro antes do período até
    o maior km do período). Média de diesel continua de tanque cheio a tanque cheio, por caminhão.
11. **Painel web no GitHub Pages** (ramo `gh-pages`) enquanto o repositório estiver público. A arquitetura
    previa Cloudflare Pages; ele precisa de conta e token que não dá para configurar daqui. Quando o
    repositório voltar a ser privado, o GitHub Pages gratuito para de servir: aí migrar para Cloudflare
    Pages (o build é o mesmo, `apps/gestor/build/web`).
12. **APKs assinados com chave de teste** guardada no repositório (`android/app/chave-teste.jks`), para
    atualizar sem desinstalar durante o piloto. Trocar pela chave definitiva antes do Google Play.
13. **R8 desligado na versão de entrega dos APKs.** O encolhedor R8 renomeava métodos que os plugins
    `shared_preferences` e `path_provider` chamam por JNI; os dois apps ficavam parados no logo
    (NoSuchMethodError, achado abrindo os APKs num emulador). Sem R8 o APK fica um pouco maior.
    A esteira agora abre os dois APKs num emulador Android a cada envio (job "aparelho").
14. **Sentry ainda não ligado** (precisa de conta; fica para a Fase 7).
15. **Empresa piloto:** "Empresa Teste (piloto)", dono gestaodefrota2027@gmail.com, código CODIGO-TROCADO,
    plano piloto com 5 caminhões, status teste. Para a empresa real do piloto, rodar `criar_empresa` com
    o nome e o e-mail do dono.
16. **Versões das migrations:** os arquivos foram renomeados para a versão que o Supabase gravou ao
    aplicar (20261017112902, 20261017113308, 20261017113838), para `supabase db push` não estranhar.

## Avisos do conselheiro do Supabase (conferidos, esperados)

- "Signed-in users can execute SECURITY DEFINER function": de propósito. Cada função confere quem
  chama (`auth.uid()`) e devolve erro claro; as de servidor (`criar_empresa`, login por CPF) não têm
  execução para `authenticated`.
- "RLS enabled no policy" em `tentativas_acesso`: de propósito, só o servidor lê e grava.
- "Multiple permissive policies" em `ajustes_gestor` (leitura): duas políticas (gestão e motorista).
  Juntar exige apagar e recriar política, o que a ferramenta da nuvem pede para confirmar; impacto
  pequeno no piloto. Fazer numa migration futura.
- "Unused index": banco novo, ainda sem uso.

## Pendências que dependem do usuário

1. **E-mail dos códigos (SMTP).** O envio padrão do Supabase só entrega para e-mails da equipe da conta
   (gestaodefrota2027@gmail.com) e tem limite muito baixo (poucos e-mails por hora). Para motoristas criarem conta, configurar um SMTP
   próprio em Authentication > Emails > SMTP Settings. Opções: Gmail da conta do projeto com senha de
   app (grátis, até ~500 e-mails por dia) ou um serviço como Brevo ou Resend (plano grátis). Decidir.
2. **Modelos de e-mail com o código.** Em Authentication > Emails > Templates, trocar o texto de
   "Confirm signup", "Magic Link" e "Reset Password" pelos modelos de `supabase/templates/` (eles têm
   `{{ .Token }}`, o código de 6 números que o app pede).
3. **GitHub Pages:** se o endereço do painel não abrir, em Settings > Pages escolher a fonte
   "Deploy from a branch", ramo `gh-pages`, pasta `/ (root)`.
4. Nome definitivo do produto.
