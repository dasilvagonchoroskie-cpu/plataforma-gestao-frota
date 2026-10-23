# Plataforma de Gestão de Frota: arquitetura e plano de construção

**Projeto novo, separado do app Meu Frete e da plataforma de gás e água. Versão 2, 14/10/2026. Nome provisório: Plataforma de Gestão de Frota.**

Quem trabalha neste documento: o Zapia adianta só a estrutura (seção 17), e o Claude Code revisa tudo e continua de onde o Zapia parou.

## 1. Instruções para o Claude Code

Leia este documento inteiro antes de qualquer ação. Se algo estiver ambíguo ou faltar, pergunte em vez de inventar.

- Quem pediu: é iniciante, não lê código nem inglês. Explique tudo em português simples, em poucas linhas, um passo de cada vez. Se precisar criar conta, instalar algo ou clicar em algum lugar, diga exatamente onde.
- Siga a ordem de fases da seção 12. Não pule fases e não crie nada fora do escopo da seção 3.
- Antes de mudar qualquer arquivo, diga em 3 a 5 linhas o que vai fazer e espere o OK. Faça commits pequenos, com mensagens em português.
- Nunca coloque senhas nem a chave `service_role` no código, nem peça para colá-las no chat. Só a chave pública (`anon`) vai na configuração dos apps.
- Nunca mexa no banco de produção. Toda mudança no banco passa por migrations.
- Antes de dizer que terminou algo, rode a análise e os testes e mostre o resultado.
- Ao fim de cada etapa, atualize `docs/PROGRESSO.md` com o que foi feito, o que falta e o próximo passo. O plano de uso é limitado e preciso retomar de onde parei.
- Nomes de tabelas e colunas em português, em `snake_case`. Classes em português, em `PascalCase`.
- O app Meu Frete é só referência de leitura. Nunca altere esse app (seção 2).
- Este projeto é separado da plataforma de gás e água. Não misture código, banco nem contas.

## 2. Contexto e relação com o Meu Frete

O negócio: empresas de transporte com várias carretas. Hoje cada motorista registra suas viagens e manda um PDF para o patrão. A plataforma muda isso: o dono ou gestor entra no painel a qualquer hora e vê o que cada motorista registrou, sem depender de PDF.

O Meu Frete é um app Flutter já existente, para o dono que trabalha por conta própria. Guarda tudo no celular (SQLite) e é vendido separado. Ele continua como está. A plataforma nova é feita do zero (app do motorista, app e painel do gestor, e a nuvem), mas reaproveita as regras de cálculo do Meu Frete:

- comissão do motorista (percentual, sobre o bruto ou não)
- adiantamento, saldo, pedágio e desconto por quebra de peso na descarga
- média de diesel (km por litro, com tanque cheio e ponto de partida)
- períodos, resumo e relatório em PDF

O usuário vai copiar a pasta do código-fonte do Meu Frete para `docs/referencia/meu_frete/` (somente leitura). As regras estão principalmente em `regras/` (`media_diesel`, `resumo`, `periodo`, `dados_relatorio`), `dados/modelos.dart` e `relatorio/gerador_pdf.dart`. Se a pasta não estiver lá, peça antes de começar a Fase 2. Cada regra portada precisa de teste automatizado com exemplos numéricos: as mesmas entradas devem dar os mesmos resultados do Meu Frete.

Não há migração de dados do Meu Frete para a plataforma.

## 3. Escopo

### Dentro da versão 1

- App do motorista (Android primeiro; iOS só quando um cliente pedir). Funciona sem internet. Registra fretes, abastecimentos, gastos de viagem e vales. Mostra resumo e gera o PDF do próprio motorista.
- App do gestor e do dono: um único código Flutter que roda como app de celular e como painel web no computador.
- Nuvem: empresas, motoristas, caminhões, sincronização, relatórios, ajustes e auditoria.
- Criação de empresa nova por função segura executada pelo dono da plataforma (tela própria fica para depois).

### Fora da versão 1 (já deixar o banco preparado quando for barato)

- cobrança online automática (campos de plano e limite já existem)
- notificações push
- localização e rastreamento
- fotos de comprovantes
- emissão de documentos fiscais (CT-e, MDF-e)
- fechamento de período (travar o mês)

## 4. Visão geral da arquitetura

Três peças ligadas pela nuvem:

- Apps dos motoristas (Flutter, banco local SQLite, funcionam offline)
- Supabase (Auth, Postgres com RLS, Storage, Edge Functions)
- App e painel do gestor (Flutter para celular e Flutter Web para computador, mesmo código)

Fluxo: o motorista registra no celular, o lançamento entra numa fila de envio, e quando há sinal o app envia em lote. A nuvem confere e grava. O gestor vê no painel. Se o gestor corrigir algo, a correção entra como ajuste e o app do motorista recebe na próxima sincronização.

Isolamento entre empresas: todas as tabelas têm `empresa_id` e as regras de acesso (RLS) garantem que uma empresa nunca enxerga os dados de outra. Um único projeto Supabase atende todas as empresas clientes.

## 5. Stack fechada

- Flutter (canal stable) com Riverpod, go_router e supabase_flutter
- Banco local do motorista: drift (SQLite)
- Backend: Supabase (Postgres com RLS, Auth, Storage, Edge Functions). Sem microsserviços.
- Painel web do gestor: Flutter Web publicado no Cloudflare Pages
- PDF: pacote pdf (o Meu Frete já usa). Planilhas: CSV.
- Monitoramento: Sentry. Integração contínua: GitHub Actions.
- As regras de cálculo existem em um único lugar, o pacote `packages/nucleo` (Dart). O banco guarda só os dados e não repete fórmulas. Se o painel ficar lento com muitos dados, resolver depois com resumos pré-calculados, sem duplicar regra.

Acesso: o cadastro confirma o e-mail por código e depois cria uma senha. O motorista entra com CPF e senha. Dono e gestor entram com e-mail e senha. Quem esquece a senha recebe um código no e-mail (todos os perfis). Tudo usa o Supabase Auth, e o login por CPF passa por uma Edge Function (seção 7). Telefone com SMS foi descartado porque tem custo por mensagem. O envio de e-mail padrão do Supabase tem limite baixo e serve só para testes. Em produção, usar um serviço próprio de envio de e-mail (SMTP, como Resend, Brevo ou Amazon SES). Conferir planos e limites atuais antes de escolher.

## 6. Perfis e permissões

- `dono`: tudo na própria empresa. Cadastros, usuários gestores, ajustes, relatórios e configurações.
- `gestor`: vê tudo da empresa, aprova a entrada de motoristas, cadastra caminhões, define o caminhão atual de um motorista, faz ajustes e relatórios. Não gerencia outros gestores nem os dados da empresa.
- `motorista`: só os próprios lançamentos e o próprio resumo. Vê a lista de caminhões ativos da empresa para trocar o próprio caminhão atual e escolher em qual está lançando.
- `admin_plataforma`: só por funções seguras no servidor, nunca por tela dos apps.

### Regras fixas

- Permissões aplicadas por RLS, com funções auxiliares como `empresa_do_usuario()`, `eh_dono()`, `eh_gestor_ou_dono()` e `motorista_do_usuario()`.
- Gestor e dono nunca apagam nem editam o lançamento original do motorista. Só criam ajuste, com autor e motivo.
- Nenhum registro é apagado de verdade. Usa-se `apagado_em`.
- A chave `service_role` nunca vai para os apps.
- Empresa suspensa: os dados ficam guardados e a leitura continua, mas novos envios são bloqueados com aviso claro.

## 7. Modelo de dados

Regras gerais: id uuid em todas as tabelas, gerado no celular quando o registro nasce no app do motorista. `empresa_id` em tudo. Valores em dinheiro em centavos (inteiro). Pesos em quilos com 2 casas. Datas em UTC. Colunas `criado_em`, `atualizado_em` (sempre preenchido pelo servidor) e `apagado_em`.

### Tabelas

- `empresas`: nome, documento (opcional), codigo_entrada (curto, único, o gestor pode gerar outro), plano, limite_caminhoes, status (`teste`, `ativa`, `suspensa`)
- `perfis`: id igual ao usuário do Auth, empresa_id (vazio até o motorista ser aprovado), papel (`dono`, `gestor`, `motorista`), nome, cpf (único), email, ativo
- `motoristas`: empresa_id, perfil_id, nome, cpf, email, telefone (opcional), ativo. A linha nasce quando o gestor aprova o pedido de entrada
- `acessos_autorizados`: empresa_id, email, papel (`dono` ou `gestor`), ativo. Quem se cadastra com um e-mail desta lista é ligado à empresa automaticamente
- `dispositivos`: empresa_id, perfil_id, apelido, ultimo_sync_em, revogado_em
- `caminhoes`: empresa_id, placa (guardada normalizada, maiúscula, sem hífen, única por empresa), numero_frota (opcional), modelo, ano, ativo, confirmado (falso quando o motorista cadastrou a placa e o gestor ainda não conferiu)
- `fretes`: empresa_id, motorista_id, caminhao_id, origem, destino, embarcador, data_carga, peso_carga_kg, valor_tonelada_centavos, adiantamento_centavos, saldo_centavos, percentual_comissao, comissao_sobre_bruto, pedagio_centavos, peso_descarga_kg, desconto_quebra_centavos
- `abastecimentos`: empresa_id, motorista_id, caminhao_id, frete_id (opcional), data, cidade, posto, litros, valor_centavos, km_odometro, tanque_cheio, ponto_de_partida
- `categorias_gasto`: empresa_id, nome, ativa (iniciar com as categorias do Meu Frete)
- `gastos_viagem`: empresa_id, motorista_id, caminhao_id, frete_id (opcional), data, categoria_id, valor_centavos, observacao
- `vales`: empresa_id, motorista_id, data, valor_centavos, observacao
- `ajustes_km`: empresa_id, caminhao_id, motorista_id, quando, km_anterior, km_novo, motivo
- `ajustes_gestor`: empresa_id, tabela_alvo, registro_id, campo, valor_antigo, valor_novo, motivo, autor_id, criado_em
- `auditoria`: empresa_id, autor_id, acao, tabela, registro_id, antes, depois, criado_em

### Tabelas da entrada na empresa e da troca de caminhão

- `pedidos_entrada`: empresa_id, perfil_id, status (`pendente`, `aprovado`, `recusado`), pedido_em, decidido_por, decidido_em
- `uso_caminhao`: empresa_id, motorista_id, caminhao_id, inicio_em, fim_em (vazio enquanto o caminhão está em uso), registrado_por (o próprio motorista ou um gestor). Só pode existir um registro aberto por motorista

Todo lançamento de frete, abastecimento e gasto guarda `motorista_id` e `caminhao_id`. O vale guarda só o motorista. Assim o relatório continua correto mesmo que o motorista troque de caminhão ou o caminhão tenha mais de um motorista.

### Modalidades de operação (pedido do dono em 22/10/2026)

- `modalidades` (catálogo da plataforma): codigo, nome, tipo (`frete` como o Graneleiro, ou `viagem` como o Baú), campos (lista: chave, rótulo, tipo, obrigatório, pode_ocultar, etapa, extra, desativado). Começa com Graneleiro, Grade baixa e Caçamba (por frete) e Baú e Sider (por viagem). A Plataforma cria modalidades e campos novos (campos novos ficam em `extras`).
- `empresas_modalidades`: empresa_id, modalidade, ativa, campos (ajustes do dono: rótulo, visível, obrigatório). Empresa nova começa com Graneleiro.
- `motoristas.modalidade` (vazia = o motorista escolhe no app; com uma só ligada, fica nela) e `convites_motorista.modalidade`.
- `fretes.modalidade` e `fretes.extras`.
- `viagens` (Baú, Sider): motorista_id, caminhao_id (o cavalo), modalidade, placa_carreta, engate_local, engate_em, desengate_local, desengate_em (vazio = em andamento), entregas_quantidade, entregas_cidades, observacao, extras. Uma viagem por carreta; sem dinheiro do frete.
- `acertos`: motorista_id, período (dias de Brasília), comissao_centavos e descontos lançados pelo gestor; vales, diesel e gastos somados pelo servidor no fechamento; para_receber = comissão − descontos − vales (se a regra manda) − diesel e gastos (se a regra manda). O motorista vê o acerto fechado.

### Registro de paradas (pedido do dono em 22/10/2026)

- Opcional por empresa: `empresas.paradas_ativas` (desligado por padrão) e `empresas.limite_sem_descanso_minutos` (padrão do banco 330 = 5h30; o dono muda entre 0h30 e 24h). Só o dono altera.
- `motivos_parada` (catálogo): codigo, nome, conta_como_descanso, ordem, ativo. Começa com café ou pausa curta, refeição, descanso, pernoite, manutenção mecânica, abastecimento, carga, descarga, fiscalização e outro. Só refeição, descanso e pernoite contam como descanso, e isso fica no catálogo, não no código.
- `paradas`: motorista_id, caminhao_id, motivo, descricao (para "outro"), inicio_em, fim_em (vazio = parado agora), ajustado (o motorista informou o horário depois), criado_no_aparelho_em. Vai pela fila do celular como os outros lançamentos.
- Intervalo sem descanso: do fim de um descanso até o começo do próximo (e, no período que chega até hoje, desde o último descanso até agora). Acima do limite da empresa fica em destaque. Intervalo de mais de um dia sem descanso registrado (folga ou registro esquecido) não entra na conta: aparece como aviso.
- É registro interno do motorista; o relatório leva no rodapé "Registro interno feito pelo motorista; não substitui o tacógrafo."

O valor efetivo de um registro é o original mais o último ajuste. Criar views (por exemplo `fretes_efetivos`) que aplicam os ajustes, e marcar na tela quando o valor foi ajustado.

### Funções e Edge Functions

- `entrar_com_cpf(cpf, senha)`: Edge Function que acha o e-mail ligado ao CPF, confere a senha no Supabase Auth e devolve a sessão. O erro é sempre o mesmo (CPF ou senha incorretos), com limite de tentativas por CPF e por aparelho.
- `sincronizar_lote(lote)`: recebe vários registros, grava por upsert no id, valida empresa e motorista do dono do token, devolve o que foi aceito e o que foi rejeitado.
- `baixar_alteracoes(desde)`: devolve cadastros e ajustes alterados desde a última sincronização.
- `criar_empresa(...)`: só admin_plataforma.
- `completar_cadastro(nome, cpf)`: grava o perfil depois da verificação do e-mail, valida os dígitos e a unicidade do CPF, e liga a pessoa à empresa se o e-mail estiver em acessos_autorizados.
- `pedir_entrada(codigo_empresa)`: o motorista cria um pedido de entrada pendente.
- `decidir_entrada(pedido_id, aprovar)`: o gestor ou dono aprova ou recusa; ao aprovar, cria a linha em motoristas e liga o perfil à empresa.

## 8. Sincronização offline

Esta é a parte mais delicada do projeto. Fazer com calma e testar muito.

- O app grava primeiro no SQLite e põe o registro na fila de envio.
- Envio ao abrir o app, quando a internet volta, de tempos em tempos com o app aberto e pelo botão Sincronizar agora.
- Sempre mostrar o estado em linguagem simples: tudo enviado, ou quantos itens aguardam envio.
- Reenviar o mesmo lote nunca duplica, porque o id é um uuid e o servidor faz upsert.
- O motorista é dono do conteúdo dos próprios lançamentos. Correções do gestor ficam em `ajustes_gestor`, separadas, então não há briga de edição. Se o motorista alterar um lançamento depois de um ajuste, o gestor vê um aviso.
- O relógio do celular pode estar errado. O app guarda a data do lançamento escolhida pelo motorista e a data de criação no aparelho, mas quem manda no `atualizado_em` é o servidor.
- O app baixa cadastros (caminhões, categorias, o próprio nome) e os ajustes dos próprios lançamentos. Também guarda na nuvem o histórico do motorista, então reinstalar o app ou trocar de celular recupera tudo.
- Nunca perder dado local. A fila só é limpa depois da confirmação do servidor.
- Celular novo: o motorista entra com CPF e senha e baixa o histórico. O login exige internet só na primeira vez. Depois a sessão fica guardada e o app continua funcionando offline. Se a sessão vencer sem internet, o app segue abrindo os dados locais e só pede o login quando houver sinal.

### Testes obrigatórios de sincronização

- dois motoristas offline criando registros ao mesmo tempo, depois voltando online
- reenvio do mesmo lote duas vezes
- internet caindo no meio do lote
- app fechado durante o envio
- relógio do celular adiantado e atrasado

## 9. Telas e fluxos

### App do motorista

Letras grandes, poucos toques, linguagem simples, pensado para quem tem pouca escolaridade:

- Cadastro (e-mail, código, nome, CPF e senha), entrar com CPF e senha, esqueci a senha e pedido de entrada na empresa.
- Abas de baixo: Início, Lançamentos e Resumo (visual do cartaz, 23/10/2026). O Início tem botões grandes com
  ícone colorido e uma linha do mês: Fretes (ou Viagens), Diesel, Gastos, Vales, Paradas, Acertos e Resumo.
  Lançamentos junta tudo numa lista só, com filtro por tipo. O botão "Lançar" está nas três.
- Fretes (lista, novo, detalhe), Diesel, Gastos, Vales (abrem pelo Início).
- Resumo e relatório em PDF para compartilhar.
- Configurações: trocar de caminhão, sincronizar, sobre.
- Ao lançar, o app mostra o caminhão atual no topo, com botão para trocar (seção 16).
- Paradas (só se a empresa liga): aba Paradas com "Registrar parada" (motivo; "Parei antes e esqueci de registrar" pede a hora) e "Retomar viagem" (ou "Esqueci de retomar", que pede a hora e marca a parada como ajustada). Parado agora, o cartão aparece também no Resumo. Funciona sem internet.
- Modalidades: se a empresa tem mais de uma e o motorista não tem, o app pergunta uma vez. No Baú e no Sider a aba Fretes vira Viagens (engatar e desengatar carreta, entregas), o cavalo é fixo (só o gestor troca) e os acertos fechados aparecem no Resumo. Os campos seguem o que o dono ajustou.

### App e painel do gestor

Mesmo código, layout se adapta:

- Login com e-mail e senha, e esqueci a senha.
- Painel: faturamento, gastos, diesel, comissões e resultado do período, e lista de motoristas com data do último envio.
- Motoristas: lista, detalhe com abas (fretes, diesel, gastos, vales, resumo), pedidos de entrada (aprovar ou recusar), código da empresa, caminhão atual, ativar ou desativar.
- Caminhões: lista, detalhe com custo por km, média de diesel e histórico.
- Lançamentos: todas as listas com filtro por período, motorista, caminhão e embarcador.
- Ajustes: corrigir um valor com motivo, com histórico.
- Relatórios: PDF e CSV por motorista, caminhão, embarcador e período.
- Configurações: categorias de gasto, gestores, dados da empresa, modalidades de operação (o dono liga e ajusta os campos).
- Motorista do Baú ou do Sider: abas Viagens e Acertos (fazer o acerto: período, comissão em reais, descontos, PDF).
- Plataforma: modalidades e campos novos.
- Paradas (só se a empresa liga): seção Paradas no menu do computador (no celular, pelo cartão do Painel) com cada motorista no período e o maior intervalo sem descanso; aba Paradas na tela do motorista; PDF e planilha por motorista e período. Configurações > Registro de paradas: o dono liga e define o limite.
- Ver como o motorista vê: o resumo e o relatório iguais ao do app dele.

No computador: menu lateral e tabelas. No celular: navegação inferior e cartões. A lógica é a mesma.

Visual (23/10/2026, igual ao cartaz da plataforma): azul-marinho com verde-limão, ícones coloridos por parte
(fretes, diesel, gastos, vales, paradas...), cartões com números grandes. Os dois apps abrem no tema escuro; o
claro (melhor no sol forte) e o "igual ao celular" ficam em Configurações > Aparência. Ícones dos apps: quadrado
verde com o caminhão (motorista) e quadrado quase preto com o gráfico e o caminhão (gestor).

## 10. Segurança, qualidade e operação

- RLS em todas as tabelas, com testes automatizados provando que o motorista A não vê o B, a empresa X não vê a Y e o gestor não consegue apagar lançamento.
- Acesso: o CPF identifica e a senha protege, então o login por CPF tem limite de tentativas (sugestão: bloqueio de 15 minutos após 5 erros) e mensagem de erro sempre igual. Códigos de e-mail são de uso único e valem pouco tempo (sugestão: 10 minutos). Conta sem vínculo com empresa não enxerga nenhum dado. Desativar um motorista corta o acesso dele na próxima conexão.
- LGPD: coletar o mínimo (nome e telefone; CPF só se a empresa exigir), sem localização na versão 1, termo de uso e política de privacidade, exportação e exclusão de dados sob pedido. Orientar o usuário a conversar com contador ou advogado sobre contrato e papel da plataforma no tratamento dos dados.
- Migrations versionadas. Backup diário (Supabase Pro) e exportação semanal para fora. Sentry nos apps. Guia de operação em `docs/OPERACAO.md`.
- Testes unitários do núcleo, de RLS e de sincronização, rodando no GitHub Actions a cada commit.
- Piloto com canal de suporte direto (WhatsApp) aberto desde o primeiro dia.

## 11. Estrutura do repositório

Monorepo com:

- `CLAUDE.md` na raiz (regras da seção 1)
- `docs/` com `ARQUITETURA.md`, `PROGRESSO.md`, `OPERACAO.md` e `referencia/meu_frete/` (somente leitura)
- `supabase/` com `migrations`, `functions` e `tests`
- `packages/nucleo`: modelos, regras de cálculo, formatos e gerador de relatório
- `apps/motorista`: app do motorista
- `apps/gestor`: app de celular e painel web do gestor

## 12. Ordem de construção

Ao fim de cada fase, parar, explicar o que foi feito e pedir OK para a próxima.

- **Fase 0, preparação:** checar ambiente (Flutter, Git, Supabase CLI), criar estrutura de pastas, salvar documentos, criar `PROGRESSO.md`.
- **Fase 1, banco e segurança:** migrations, RLS, funções e testes de isolamento entre empresas e perfis.
- **Fase 2, núcleo de regras:** portar as regras do Meu Frete para `packages/nucleo`, com testes numéricos.
- **Fase 3, app do motorista offline:** banco local, telas, resumo e PDF, ainda sem nuvem. Gerar APK de teste.
- **Fase 4, acesso e sincronização:** cadastro por e-mail com código, login por CPF, esqueci a senha, entrada na empresa, troca de caminhão, envio de e-mail (SMTP), fila de envio e todos os testes das seções 8 e 16.
- **Fase 5, app e painel do gestor:** login, aprovação de entrada de motoristas, cadastro de caminhão e telas de leitura.
- **Fase 6, relatórios e ajustes:** PDF e CSV, ajustes com histórico e auditoria.
- **Fase 7, acabamento e piloto:** revisão de segurança, APK assinado, teste fechado no Google Play, piloto com uma empresa e 2 a 3 motoristas.

## 13. Contas e custos recorrentes

Como um único Supabase atende todas as empresas, as contas ficam no nome de quem opera a plataforma (o usuário, ou a empresa dele quando for aberta). Valores de referência, conferir antes de contratar:

- Supabase Pro: cerca de US$25 por mês.
- Google Play: cerca de US$25, pagamento único.
- Apple Developer: cerca de US$99 por ano, só quando houver cliente que precise de iPhone.
- Domínio: cerca de R$40 por ano.
- Cloudflare Pages e Sentry: planos gratuitos no começo.

Para cobrança por caminhão, a tabela `empresas` já guarda `plano`, `limite_caminhoes` e `status`. Sem gateway de pagamento na versão 1.

O serviço de envio de e-mail dos códigos de login também entra nos custos recorrentes. Muitos têm plano gratuito para poucos envios por mês, mas é preciso conferir limites e preços atuais antes de escolher.

## 14. Decisões em aberto

O Claude Code deve perguntar ao usuário antes da fase indicada:

- **Acesso (decidido):** cadastro com e-mail verificado por código, depois senha. O motorista entra com CPF e senha, e a recuperação de senha é por código no e-mail, para todos os perfis. A entrada do motorista na empresa por código da empresa, com aprovação do gestor, também está decidida (seção 16). Falta confirmar, antes da Fase 4: (1) se dono e gestor entram por e-mail e senha; (2) qual serviço de envio de e-mail (SMTP) será usado; (3) o que fazer com motorista sem e-mail ou que perdeu o acesso (proposta: o gestor redefine o acesso pelo painel).
- O motorista pode editar ou apagar um lançamento depois de enviado? (antes da Fase 3): proposta é permitir até o gestor ajustar o registro, tudo anotado na auditoria.
- O mesmo gestor em mais de uma empresa? Proposta: não na versão 1.
- Nome definitivo do produto.
- Fechamento de período (travar o mês): avaliar depois do piloto.

## 15. Glossário

- **Offline:** funciona sem internet.
- **Sincronizar:** enviar e receber dados da nuvem.
- **UUID:** código único que nunca se repete.
- **RLS:** regra no banco que decide quem pode ver ou mudar cada linha.
- **Migration:** arquivo versionado que descreve uma mudança no banco.
- **Multiempresa:** vários clientes no mesmo sistema, com dados separados.
- **Ajuste:** correção do gestor, registrada à parte do lançamento original.
- **APK:** instalador de teste do Android.
- **Edge Function:** pequeno programa que roda na nuvem do Supabase.

## 16. Cadastro, login, entrada na empresa e troca de caminhão

O acesso tem três etapas: cadastro com e-mail verificado, entrada na empresa e login do dia a dia. A troca de caminhão é feita pelo próprio motorista e nunca altera o que já foi lançado.

Regra de ouro: muitos motoristas são leigos em tecnologia, então cada passo precisa ser curto e claro. A segurança vem de limites e de regras no servidor, não de burocracia na tela:

- Senha com no mínimo 6 caracteres, sem exigir símbolo, maiúscula ou número. A proteção vem do limite de tentativas.
- Botão para mostrar a senha enquanto digita, e senha pedida uma vez só.
- CPF com máscara automática e teclado numérico.
- Mensagens de erro em português simples, dizendo o que fazer. Nunca códigos técnicos.
- Sessão guardada: o motorista não precisa entrar de novo no dia a dia.
- Código da empresa curto (6 caracteres), sem letras e números que se confundem (0, O, 1, I).
- Aguardando aprovação: o app confere sozinho ao abrir e tem um botão Já fui aprovado, verificar.
- Quem perdeu o e-mail ou a senha tem saída: o gestor redefine o acesso pelo painel (Edge Function `redefinir_acesso`). A senha provisória aparece só para o gestor, e o motorista troca no primeiro login.
- Uma ação principal por tela, botão grande e letra grande.

### Cadastro (todos os perfis)

1. A pessoa informa o e-mail e recebe um código de 6 dígitos (Supabase Auth, código por e-mail).
2. Digita o código, o que confirma que o e-mail é dela.
3. Preenche nome, CPF e senha. O app valida os dígitos do CPF.
4. A pessoa fica logada e continua logada até sair.

### Login de volta, depois de sair

- Motorista: CPF e senha, pela Edge Function `entrar_com_cpf`.
- Dono e gestor: e-mail e senha (proposta, a confirmar).
- A mensagem de erro é sempre a mesma: CPF ou senha incorretos. Depois de 5 erros, bloqueio temporário (sugestão: 15 minutos). O CPF não é segredo, quem protege a conta é a senha.

### Esqueci a senha (todos os perfis)

A pessoa digita o e-mail, recebe um código de 6 dígitos, digita o código e cria uma nova senha. Usar código em vez de link, porque funciona melhor dentro do app (o texto do e-mail do Supabase precisa ser configurado para enviar o código). A tela responde sempre a mesma coisa, exista ou não o e-mail.

### Entrada na empresa

- Dono: a plataforma cria a empresa (`criar_empresa`) e coloca o e-mail do dono em `acessos_autorizados`. Quando o dono se cadastra com esse e-mail, já entra na empresa.
- Gestor: o dono coloca o e-mail do gestor em `acessos_autorizados`, com o mesmo vínculo automático.
- Motorista: depois do cadastro, digita o código da empresa (`empresas.codigo_entrada`), que o dono ou gestor passa por WhatsApp. Isso cria um pedido de entrada pendente. O gestor confere nome e CPF e aprova ou recusa no painel. Enquanto espera, o app mostra Aguardando aprovação do seu patrão. O gestor pode gerar outro código quando quiser, e o anterior deixa de valer. (Atualizado em 17/10/2026, a pedido do usuário: o gestor cadastra o motorista com nome e CPF e o painel gera um código individual, de uso único, válido por 7 dias e preso ao CPF; com ele o motorista entra na hora. Ver docs/PASSAGEM.md.)
- Conta sem vínculo com empresa não enxerga nenhum dado (RLS). Como o cadastro é aberto, limitar pedidos de código por e-mail e por aparelho e usar captcha se aparecer abuso.

### Trocar de caminhão (motorista)

- O app mostra sempre no topo o caminhão atual, com placa e número da frota.
- O botão Trocar de caminhão lista os caminhões ativos da empresa e o motorista escolhe. Não se digita placa à mão.
- Se a placa não está na lista, o botão Não achei meu caminhão deixa digitar a placa. O caminhão entra como não confirmado, e o gestor confirma ou corrige no painel. Os lançamentos já ficam ligados a ele.
- A troca grava um registro em `uso_caminhao`: fecha o anterior (`fim_em`) e abre o novo (`inicio_em`).
- Antes de confirmar, o app explica em palavras simples: Você vai lançar no caminhão ABC1D23. O que você já lançou continua no caminhão antigo.
- Nada do que já foi lançado muda. Cada lançamento guarda o `caminhao_id` do momento em que foi feito.
- Lançou no caminhão errado: o motorista corrige o caminhão do lançamento (se a regra da seção 14 permitir) ou o gestor faz um ajuste em `ajustes_gestor`, no campo `caminhao_id`.
- O gestor também pode definir o caminhão atual de um motorista pelo painel, com autoria registrada.
- Dois motoristas no mesmo caminhão ao mesmo tempo é permitido (turnos), mas o painel mostra um alerta ao gestor.
- Troca feita sem internet entra na fila e sincroniza como qualquer lançamento.
- Diesel: a média de km por litro é calculada por caminhão, nunca misturando caminhões, porque o odômetro pertence ao caminhão. O primeiro abastecimento num caminhão é um ponto de partida, e a média só vale a partir do próximo tanque cheio. Conferir essa regra no código do Meu Frete.

### Testes obrigatórios desta seção

- cadastro completo, login por CPF, bloqueio após 5 erros e recuperação de senha
- motorista sem aprovação não vê nenhum dado, e o aprovado só vê os próprios lançamentos
- troca de caminhão no meio do mês, com relatório por caminhão e por motorista batendo
- troca feita offline e sincronizada depois
- média de diesel sem misturar caminhões

## 17. Adiantamento pelo Zapia e passagem para o Claude Code

O Zapia só levanta as paredes (estrutura, banco e esqueleto dos apps). O Claude Code revisa tudo, testa e constrói o resto.

### O que o Zapia pode fazer, e só isto

- **Fase 0:** estrutura de pastas da seção 11, `CLAUDE.md`, `docs/ARQUITETURA.md` (cópia deste documento) e `docs/PROGRESSO.md`.
- **Fase 1:** arquivos de migration do banco com as tabelas da seção 7, índices, regras de acesso (RLS) e funções auxiliares da seção 6. Só como arquivos no repositório, sem aplicar em produção.
- **Esqueleto dos apps:** projetos Flutter em `apps/motorista` e `apps/gestor`, com tema, navegação e telas vazias usando dados de exemplo fixos (sem banco, sem nuvem, sem login).
- **`packages/nucleo`:** só a estrutura de pastas e as classes simples de dados, sem regras de cálculo.

### O que o Zapia não pode fazer

- Regras de cálculo (comissão, quebra de peso, média de diesel, PDF). Dependem do código do Meu Frete e de testes com números, e ficam para a Fase 2, com o Claude Code.
- Cadastro, login, sincronização, Edge Functions e fila offline (Fase 4).
- Conectar em Supabase de produção, ou colocar senha, chave secreta ou `service_role` no repositório.
- Mudar stack, nomes ou escopo deste documento. Se tiver dúvida, anotar em `docs/PASSAGEM.md` em vez de decidir sozinho.
- Copiar ou alterar o app Meu Frete.

### Honestidade no progresso

Cada item de `docs/PROGRESSO.md` recebe um destes estados: **feito e testado**, **feito mas não testado**, **não feito**. Só vale como testado o que rodou de verdade, com o comando e o resultado anotados.

Ao parar, o Zapia cria `docs/PASSAGEM.md` com cinco partes: arquivos principais criados, o que foi testado e como, o que não foi testado ou deu erro, decisões tomadas que não estavam neste documento, e dúvidas em aberto.

### Quando o Claude Code retomar

1. Ler `docs/PASSAGEM.md` e `docs/PROGRESSO.md`.
2. Conferir o repositório contra este documento, fase por fase, rodando as migrations do zero em um Supabase de desenvolvimento e os testes de RLS.
3. Explicar ao usuário, em português simples, o que está certo, o que está errado e o que falta, antes de mudar qualquer coisa.
4. Depois do OK, corrigir o necessário e continuar da primeira fase que não esteja feita e testada.

Nada que o Zapia marcou como feito vale como pronto antes de passar pelos testes do Claude Code.
