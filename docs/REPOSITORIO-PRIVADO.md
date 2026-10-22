# Repositório privado e painel num repositório público só dele (opção A)

Decisão do dono em 22/10/2026: o código fica **privado**; o painel web fica num repositório **público**
separado, `painel-frota`, que só tem os arquivos prontos do painel (sem código, sem documentos).

## Por quê

- No plano grátis, o GitHub Pages só funciona com repositório **público** (com repositório privado, só nos
  planos pagos: Pro, Team ou Enterprise).
- O painel publicado não tem segredo: só a chave pública do Supabase, que fica em qualquer app.
- Com o código privado: ninguém de fora lê o código, as migrations, os documentos, os registros da esteira
  nem os artefatos (o backup, mesmo cifrado, deixa de ficar à vista).

## Como funciona

- A Esteira compila o painel e publica no repositório público `painel-frota` (ramo `main`) com o segredo
  `PAINEL_TOKEN`. Sem esse segredo, publica no ramo `gh-pages` deste repositório (como antes).
- Endereço do painel: `https://dasilvagonchoroskie-cpu.github.io/painel-frota/`.
- O fluxo do banco, vendo o `PAINEL_TOKEN`, troca no Supabase o Site URL (o endereço dos links dos
  e-mails) para o painel novo e mantém o endereço antigo aceito.
- O CORS das Edge Functions não muda (o site continua em `dasilvagonchoroskie-cpu.github.io`).
- A Esteira confere a cada envio se a versão nova do painel está no ar (registro `gestor.log`).

## Passo a passo do dono (uma vez)

1. **Criar o repositório do painel:** https://github.com/new
   - Repository name ("Nome do repositório"): `painel-frota`
   - **Public** ("Público")
   - Marque **Add a README file** ("Adicionar um arquivo README")
   - **Create repository** ("Criar repositório")
2. **Ligar o Pages nele:** no `painel-frota`, Settings ("Configurações") > Pages > Build and deployment
   ("Compilação e implantação") > Source ("Origem"): **Deploy from a branch** ("Implantar a partir de um
   ramo") > Branch ("Ramo"): **main** e **/ (root)** ("/ (raiz)") > **Save** ("Salvar").
3. **Criar o token que só grava no painel:** https://github.com/settings/personal-access-tokens/new
   - Token name ("Nome do token"): `esteira-painel-frota`
   - Expiration ("Validade"): a maior que aparecer (anote a data para renovar)
   - Repository access ("Acesso aos repositórios"): **Only select repositories** ("Somente repositórios
     selecionados") > `painel-frota`
   - Permissions ("Permissões") > Repository permissions ("Permissões do repositório") > **Contents**
     ("Conteúdo"): **Read and write** ("Leitura e escrita")
   - **Generate token** ("Gerar token") e copie (aparece uma vez só; não mande no chat)
4. **Guardar o token como segredo:** no `plataforma-gestao-frota`, Settings > Secrets and variables
   ("Segredos e variáveis") > Actions > **New repository secret** ("Novo segredo do repositório"):
   Name ("Nome") `PAINEL_TOKEN`, Secret ("Segredo"): o token > **Add secret** ("Adicionar segredo").
5. Esperar a Esteira do próximo envio publicar o painel novo e o fluxo do banco trocar o endereço dos
   e-mails (o registro mostra "ok: painel no ar").
6. **Só então** deixar o código privado: Settings > General ("Geral") > Danger Zone ("Zona de perigo") >
   **Change visibility** ("Alterar visibilidade") > **Make private** ("Tornar privado").
7. Depois: Settings > Pages deste repositório > desligar, e apagar o ramo `gh-pages`.

## O que muda com o código privado

- **Minutos da esteira:** repositório privado no plano grátis tem 2.000 minutos por mês (público é sem
  limite). Hoje: cerca de 34 minutos por envio (Esteira 26, segurança 2, banco 6) e 6 por dia do backup
  diário, ou seja, uns 50 envios por mês. Sem cartão cadastrado, passando do limite a esteira para até o
  mês seguinte (não cobra). Se apertar: rodar o emulador e os APKs só quando os apps mudarem.
- **APKs:** os Releases ficam privados. O dono baixa logado no GitHub (ou recebe pelo chat) e manda o
  arquivo pelo WhatsApp.
- **Varredura de segredos:** a do GitHub (grátis só em público) deixa de valer; a **gitleaks** da Esteira
  e do fluxo de segurança continua em todo envio e no histórico inteiro.
- **Commits antigos:** os de antes da limpeza de 22/10 ficam inacessíveis para quem é de fora.

## Renovar o token

Antes da data de validade: criar outro igual (passo 3) e trocar o valor do segredo `PAINEL_TOKEN`
(Settings > Secrets and variables > Actions > `PAINEL_TOKEN` > Update ("Atualizar")). Sem o token, a
Esteira volta a publicar no `gh-pages` (que, com o repositório privado, não fica no ar).
