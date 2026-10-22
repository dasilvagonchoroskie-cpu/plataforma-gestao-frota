# Plano: repositório privado e painel no Cloudflare Pages

## Por que

O repositório é **público** hoje porque o GitHub Pages grátis (onde está o painel) e a varredura de
segredos grátis do GitHub só funcionam em repositório público. Público tem custos de segurança:

- qualquer pessoa lê o código, as migrations e os documentos de operação;
- os **artefatos** das execuções (inclusive o backup criptografado) podem ser baixados por qualquer
  pessoa com conta no GitHub. O backup é cifrado com AES-256 e uma senha derivada da `CHAVE_MESTRA`
  (resistente a adivinhação), mas o ideal é que nem o arquivo cifrado fique exposto;
- os símbolos da ofuscação dos apps não podem ser guardados (desfariam a ofuscação).

## O que muda

| Hoje | Depois |
|---|---|
| Painel em `dasilvagonchoroskie-cpu.github.io` (GitHub Pages) | Painel no **Cloudflare Pages** (grátis, funciona com repositório privado), endereço `frota-gestor.pages.dev` ou domínio próprio (`painel.fortalezadigitalsecurity.com.br`) |
| Varredura de segredos do GitHub (grátis só em público) | A varredura **gitleaks** da Esteira continua igual (já roda em todo envio, em todo o histórico) |
| Artefatos públicos | Artefatos visíveis só para quem tem acesso ao repositório |
| APKs nos Releases públicos | Releases privados; o dono baixa e envia o APK (ou um link do Cloudflare) |

## Passo a passo (quando o dono decidir)

1. Criar conta grátis no Cloudflare e um projeto **Pages** ligado ao GitHub (Workers & Pages > Create >
   Pages > Connect to Git ("Conectar ao Git")), ou publicar pela Esteira com `wrangler pages deploy`
   (precisa de um token do Cloudflare como segredo do GitHub).
2. Na Esteira, trocar o passo "Publicar o painel web (ramo gh-pages)" pela publicação no Cloudflare e o
   `--base-href /plataforma-gestao-frota/` por `/`. O arquivo `apps/gestor/web/_headers` (já pronto) faz o
   Cloudflare mandar os cabeçalhos de segurança do painel.
3. Nas Edge Functions, liberar o endereço novo do painel: segredo `ORIGENS_PERMITIDAS` (Supabase > Edge
   Functions > Secrets) com o endereço novo.
4. No Supabase > Authentication > URL Configuration, trocar o Site URL para o endereço novo.
5. GitHub > Settings > General > Danger Zone > Change repository visibility > Private.
6. Desligar o GitHub Pages (Settings > Pages) e apagar o ramo `gh-pages`.
7. Avisar os donos do endereço novo do painel.

Custo: zero (Cloudflare Pages grátis e GitHub privado grátis). Tempo: cerca de 1 hora.
