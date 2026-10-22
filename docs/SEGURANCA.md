# Segurança — relatório da revisão de 22/10/2026

Revisão completa pedida pelo dono ("nível empresa"): segredos, backup, banco, Edge Functions, senhas e
sessões, apps, dependências e esteira, registro de auditoria, e-mail, textos legais e incidentes.
Gravidade: **Alta** (dá para explorar e causa dano real), **Média** (exige condição extra ou o dano é
limitado), **Baixa** (defesa em profundidade).

## Achados e correções

| # | Achado | Gravidade | O que foi feito | Situação |
|---|---|---|---|---|
| 1 | Chave de assinatura de teste (`chave-teste.jks`, senha "android") no repositório público e no histórico: qualquer pessoa podia assinar um APK falso que o celular aceitaria como atualização. | Alta | Chave aposentada. Nova chave RSA 3072 derivada da `CHAVE_MESTRA` só durante a compilação (`ferramentas/chaves/`). Arquivos apagados e histórico reescrito. APK só é publicado com a chave oficial e depois de abrir no emulador. | Feito; publica quando o segredo existir |
| 2 | Sem backup fora do Supabase (o plano grátis não tem backup). | Alta | Backup diário criptografado (AES-256) às 02:30, guardado 90 dias fora do Supabase, com teste de restauração diário num Supabase vazio e conferência das linhas de cada tabela. A Esteira testa backup + restauração a cada envio. | Feito; liga com os segredos |
| 3 | Login interno do motorista tirado do CPF (`m<CPF>@...`): dava para tentar senhas direto no Supabase Auth, sem o bloqueio de 5 tentativas. | Alta | Login interno sorteado; contas antigas trocam sozinhas no próximo login certo. Teste prova que o login pelo CPF não funciona mais. | Feito (Edge Functions na nuvem) |
| 3b | Login por CPF limitado só por CPF e por aparelho: dava para tentar uma senha comum em muitos CPFs, trocando o número do aparelho. | Média | 30 erros do mesmo IP verdadeiro em 15 minutos bloqueiam o IP (além dos 5 erros por CPF e por aparelho). Teste ponta a ponta confere. | Feito e publicado na nuvem |
| 4 | Código de entrada da empresa piloto nos documentos públicos e no histórico. | Média | Códigos de todas as empresas trocados no banco (migration `rotacionar_codigos_empresa`); removido dos documentos e do histórico. | Feito |
| 5 | Senha provisória do dono escrita no arquivo PROJETO (fora do repositório). | Média | O dono já tinha trocado; removida do PROJETO. Senhas não vão mais para nenhum documento. | Feito |
| 6 | IP do limite de cadastro e dos registros tirado do primeiro endereço de `x-forwarded-for`, que quem chama pode inventar. | Média | IP vem do `cf-connecting-ip` (Cloudflare) ou do último endereço da lista, nas funções e no banco. | Feito |
| 7 | Senha mínima de 6 caracteres, sem exigir letra e número. | Média | 8 a 72 caracteres, com letras e números, igual nos apps, Edge Functions, banco e Supabase Auth (`supabase/auth-nuvem.json`, aplicado pelo fluxo do banco). | Feito; Auth da nuvem com os segredos |
| 8 | CPF e e-mail do motorista guardados no celular. | Média | Não ficam mais; versões antigas limpam na primeira abertura. Teste confere. | Feito |
| 9 | Sem registro das ações da plataforma (bloquear, liberar, excluir, mudar configuração). | Média | Tabela `auditoria_plataforma` preenchida por gatilho (pega até o que for feito direto no SQL Editor), sem dado pessoal, que não aceita alteração nem exclusão. | Feito; vai para a nuvem com os segredos |
| 10 | Migration que apaga dados podia entrar sem aprovação do dono. | Média | `conferir_aprovacao.py` na Esteira, no fluxo de segurança e antes de aplicar na nuvem: exige `-- aprovado-por: ...`. | Feito |
| 11 | Ações do GitHub sem versão fixa e todos os jobs com permissão de escrita. | Média | Ações fixadas por SHA; permissão mínima por job; credenciais não ficam no checkout; Supabase CLI fixo (2.121.0); atualização automática só depois da Esteira verde de um envio direto no `main` deste repositório. | Feito |
| 12 | Sem varredura automática de segredos. | Média | gitleaks 8.30.1 (resumo SHA-256 conferido) em todo envio e toda segunda-feira, no histórico inteiro do `main`, com regras do projeto (`.gitleaks.toml`). | Feito |
| 13 | APK sem conferência de segredos. | Média | `conferir_apk.py` em todo APK: chave secreta, token service_role, arquivos de chave. | Feito |
| 14 | Textos legais sem o operador correto e sem informar o backup no exterior. | Média | Operador = Evandro, pessoa física (marca Fortaleza Digital Security), em `docs/legal/operador.json`; Política fala do backup criptografado, da transferência internacional e do canal do titular. Nova versão: todos aceitam de novo. | Feito; falta o nome completo |
| 15 | Sem plano de resposta a incidentes. | Média | `docs/INCIDENTES.md` (conter, avaliar, avisar em 3 dias úteis, corrigir, registrar). | Feito |
| 16 | Repositório público: código, documentos e artefatos (backup cifrado) visíveis; commits antigos (antes da limpeza) ainda abrem por quem souber o número. | Média | Decisão do dono (22/10): código privado e painel num repositório público só dele (`painel-frota`), publicado pela Esteira com o segredo `PAINEL_TOKEN` (`docs/REPOSITORIO-PRIVADO.md`). Varredura de 22/10 no histórico atual, nos commits antigos e nos registros públicos: nenhum segredo válido (só a chave de teste antiga, já aposentada). | Em andamento (passos do dono) |
| 17 | Backup do Android: Android 12+ copia dados de celular para celular mesmo com `allowBackup=false`. | Baixa | Regras de exclusão (`dataExtractionRules`), `fullBackupContent=false` e tráfego sem HTTPS proibido, nos dois apps. | Feito |
| 18 | R8 desligado e código Dart sem ofuscação. | Baixa | R8 e encolhimento de recursos ligados, com regras para as classes chamadas por JNI; Dart com `--obfuscate`. O emulador prova que os apps abrem. | Feito |
| 19 | Edge Functions: CORS aberto a qualquer site, sem limite de tamanho e com erro técnico repassado. | Baixa | CORS só para o painel (e localhost); pedido até 16 KB; erro técnico vira mensagem genérica; id validado; `Cache-Control: no-store`. | Feito |
| 20 | Senha provisória de 8 caracteres sem garantia de número. | Baixa | 10 caracteres, com letras e números garantidos, sem letras que se confundem. | Feito |
| 21 | Objetos novos no banco nasciam liberados para `anon` (padrão do Supabase); sequências com uso para `anon`. | Baixa | Permissões padrão fechadas e sequências revogadas. Teste 07 confere todas as tabelas, visões, sequências e funções, inclusive as futuras. | Feito |
| 22 | Pacotes Dart com versão `any`. | Baixa | Versões fixas (apps) e mínimas (pacotes) iguais aos `pubspec.lock`; Dependabot semanal para pacotes e ações. | Feito |
| 23 | "CPF já tem cadastro" permite saber se um CPF usa a plataforma. | Baixa | Mensagem neutra e limite de 5 cadastros por aparelho e 20 por IP verdadeiro por hora. Sem e-mail/SMS não dá para esconder de todo. | Risco aceito |
| 24 | Proteção contra senha vazada (HaveIBeenPwned) e limite de sessão desligados. | Baixa | Só existem no plano Pro; o fluxo tenta ligar e avisa. | Pendente (plano Pro) |
| 25 | Cadastro aberto no Supabase Auth (e-mail com código) ainda ligado por causa da tela antiga. | Baixa | Sem confirmar o e-mail não há sessão; RLS não deixa ver nada sem perfil. Desligar junto com o SMTP próprio. | Pendente |
| 26 | Aviso do Supabase: 19 funções `SECURITY DEFINER` chamáveis por usuário logado. | Info | São a API do app; cada uma confere quem chama. Testes 01 a 07 provam o isolamento. | Aceito |
| 28 | Recuperação dependia de um código anotado em papel (quem perdeu ficava sem acesso). | Média | Link por e-mail (`pedir_link_senha`): mesma resposta e mesmo tempo exista ou não a conta, 3 pedidos por hora por CPF/e-mail e 10 por IP, link de 1 hora e uso único, todas as sessões encerradas depois da senha nova. Sem guardar nada no celular. | Feito; chega a todos com o SMTP próprio |
| 29 | Troca de e-mail confirmada só no e-mail novo (necessária para o motorista, cujo login é interno): com a sessão roubada daria para trocar o e-mail do dono e depois a senha. | Média | O banco recusa o pedido de troca de e-mail de dono e gestor (gatilho `barrar_troca_email_gestor`); teste pgTAP e ponta a ponta. | Feito |
| 30 | Backup guardava sessões e tokens de login. | Baixa | Backup sem sessões, tokens de renovação, códigos e links em andamento e registro de entradas; depois de restaurar, cada um entra com a senha. | Feito |
| 31 | Cadastro de empresas só pelo SQL do Supabase (risco de erro manual e de abrir o Supabase para tarefas do dia a dia). | Média | Área Plataforma no app só para o super administrador (`admins_plataforma`); cada ação (`plataforma_*`) confere no banco quem chama; nenhuma apaga dados; auditoria com origem `plataforma_app`; senha provisória gerada pelo banco (10 caracteres). Testes pgTAP (08) e ponta a ponta. | Feito |
| 32 | Senha provisória do dono só era cobrada pelo app (alguém poderia usar a API sem trocar). | Média | O banco marca a senha provisória (resumo SHA-256 da senha cifrada) e as permissões de dono e gestor negam tudo até a troca. | Feito |
| 33 | Área Plataforma sem verificação em duas etapas. | Baixa | Decisão do dono (22/10/2026): sem Google Authenticator por enquanto. Melhoria futura anotada em `docs/PASSAGEM.md`. | Pendente (futuro) |
| 27 | As 4 etiquetas antigas dos Releases ainda apontam para o histórico de antes da limpeza (o GitHub não deixa mudar etiquetas por esta sessão). | Baixa | A Esteira move as etiquetas para a versão publicada assim que publicar o primeiro APK oficial. A chave antiga já não vale para APKs novos. | Automático com os segredos |

## Como a segurança está montada

- **Isolamento:** RLS em todas as tabelas; funções de permissão negam tudo para empresa bloqueada, com
  teste vencido ou excluída; quem não entrou não tem permissão em nada. Provado pelo teste
  `supabase/tests/07_auditoria_seguranca.sql`, que percorre todas as tabelas e visões com `empresa_id`
  (dono, gestor e motorista de uma empresa não veem nenhuma linha de outra; motorista não vê lançamento de
  outro motorista; empresa suspensa não vê nada; sem login nenhuma tabela responde).
- **Segredos:** só dois, no GitHub (`SUPABASE_ACCESS_TOKEN` e `CHAVE_MESTRA`). A chave secreta do
  Supabase existe só dentro das Edge Functions. Os apps têm só a chave pública. Nada de senha ou chave no
  repositório, no chat ou nos registros (as senhas derivadas são mascaradas).
- **Senhas e sessões:** regra única (8–72, letras e números); bloqueio de 15 minutos depois de 5 erros no
  login por CPF; senha esquecida por link no e-mail (limite de pedidos, link de 1 hora e uso único, sessões
  antigas encerradas); mesma mensagem e mesmo tempo de resposta exista ou não a conta; token de 1 hora com
  rotação do token de renovação.
- **Mudanças no banco:** só por migration versionada, testada na Esteira, com backup antes e aprovação do
  dono para o que apaga dados.
- **Esteira:** testes do banco (pgTAP), das Edge Functions (ponta a ponta), backup e restauração, apps,
  varredura de segredos (código e APK) e abertura dos APKs num emulador antes de publicar.

## Comandos de conferência

    # banco (local, sem Docker)
    PGHOST=/tmp PGPORT=54329 PGUSER=postgres PGTAP_SQL=pgtap.sql bash supabase/tests/local/rodar.sh
    # segredos no histórico
    gitleaks git . --config .gitleaks.toml --log-opts="--full-history HEAD"
    # migrations que apagam dados
    python3 ferramentas/seguranca/conferir_aprovacao.py supabase/migrations
    # APK
    python3 ferramentas/seguranca/conferir_apk.py Frota-Motorista.apk
