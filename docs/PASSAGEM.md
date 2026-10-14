# Passagem — Plataforma de Gestão de Frota

## Arquivos principais criados

- **feito mas não testado** — `supabase/migrations/20261014110000_esquema_inicial.sql`: definição inicial das 16 tabelas da seção 7, índices, RLS, as quatro funções auxiliares da seção 6, trigger para `atualizado_em` e views `fretes_efetivos`, `abastecimentos_efetivos`, `gastos_viagem_efetivos` e `vales_efetivos`. A migration não foi aplicada a nenhum banco.
- **feito mas não testado** — `packages/nucleo/lib/src/modelos.dart`: acrescentadas classes simples para as entidades ausentes no esqueleto inicial (acessos autorizados, dispositivos, ajustes, auditoria, pedido de entrada e uso de caminhão); sem cálculos.
- **feito mas não testado** — `docs/PROGRESSO.md`: status e próximos passos.
- **feito mas não testado** — `apps/motorista` e `apps/gestor` têm `pubspec.yaml`, `lib/main.dart`, navegação simples, tema Material 3 e dados demonstrativos fixos; sem login ou backend. O bootstrap das plataformas Android e Web não foi gerado.
- **feito mas não testado** — Estrutura e demais documentos previamente criados permanecem, incluindo `CLAUDE.md`, `README.md`, `docs/ARQUITETURA.md`, `docs/OPERACAO.md`, `docs/referencia/meu_frete/README.md` e arquivos README/placeholders do Supabase e dos pacotes/apps.
- **não feito** — Nenhum repositório GitHub foi criado ou enviado. O usuário não definiu nome nem destino do repositório; perguntar antes de qualquer ação remota.

## O que foi testado e como

- **feito e testado** — Executado um comando Python de verificação textual. Resultado: confirmou 16 tabelas, 29 políticas RLS, quatro funções auxiliares, quatro views de efetivos, as duas cascas Flutter e 16 classes de dados simples; também conferiu que tabelas de lançamentos e pedidos de entrada não têm escrita direta por cliente. Passou (`OK`).
- **feito e testado** — Consultada disponibilidade das ferramentas com `command -v`: `flutter`, `dart`, `supabase`, `psql` e `git` não estão disponíveis neste ambiente.
- **não feito** — Não foi possível rodar análise/compilação Flutter/Dart, testes automatizados, parser/aplicação SQL ou testes RLS. O teste textual não prova sintaxe ou comportamento.

## O que não foi testado ou deu erro

- **não feito** — A migration permanece não aplicada. Não usar produção; revisar e rodar do zero apenas em Supabase/Postgres de desenvolvimento.
- **não feito** — Não houve teste de isolamento entre empresas/perfis, nem de consultas pelas views, nem validação de triggers/constraints.
- **não feito** — Não houve `flutter analyze`, `dart analyze`, `flutter test`, geração de lockfiles, bootstrap das plataformas Android/Web ou build.
- **não feito** — O código-fonte do Meu Frete não foi copiado nem alterado; a Fase 2 não começou.

## Decisões tomadas que não estavam neste documento

- **feito mas não testado** — `empresas.empresa_id` foi modelado como não nulo, único e igual ao `id` da própria empresa para acomodar literalmente a regra geral de `empresa_id` em todas as tabelas. A criação de empresa segue sem escrita direta e dependerá da futura função segura; confirmar se esse campo deve existir na tabela raiz ou se `empresas` é exceção.
- **feito mas não testado** — `perfis.cpf` ficou anulável e globalmente único: a arquitetura lista CPF único, mas a seção 10 diz coletar CPF apenas se a empresa exigir. Confirmar a decisão antes do cadastro/login.
- **feito mas não testado** — Campos sem nulabilidade explícita foram em geral tratados como obrigatórios; apenas campos explicitamente opcionais (por exemplo, documento, telefone e frete vinculado) foram anuláveis. Tipos escolhidos incluem `timestamptz` para datas/horários, `numeric` para pesos/litros/km/percentuais, `bigint` para centavos, texto para status e JSONB para valores de auditoria/ajustes.
- **feito mas não testado** — IDs têm default UUID do servidor para facilitar registros não originados no aparelho, embora o cliente possa fornecer o UUID offline. `codigo_entrada` foi tornado globalmente único; placa única por empresa. Unicidade não é parcial por `apagado_em`, de modo que valor de registro apagado logicamente não pode ser reutilizado.
- **feito mas não testado** — A RLS não concede `DELETE` físico. Lançamentos originais permitem leitura ao gestor/dono e ao motorista dono do registro, sem política de escrita direta para o motorista; `sincronizar_lote` deve validar e gravar os dados pelo servidor. Isso evita decidir agora se o motorista pode editar/apagar lançamento já enviado, decisão em aberto na seção 14. Motoristas leem apenas ajustes referentes aos próprios lançamentos.
- **feito mas não testado** — `perfis`, `motoristas`, `empresas` e `pedidos_entrada` não permitem escrita direta por cliente autenticado nos fluxos de cadastro/aprovação. As futuras funções seguras `criar_empresa`, `pedir_entrada` e `decidir_entrada` devem validar vínculo e aprovação. Administradores da plataforma não têm política de tela no banco.
- **feito mas não testado** — Views de valores efetivos apresentam os dados ajustados num campo JSONB `valores_efetivos`, por chave, sobrescrevendo pelo ajuste mais recente, e usam `security_invoker = true` para manter RLS. Confirmar se o formato atende às telas/consultas e à versão do Postgres.
- **feito mas não testado** — Acesso a `acessos_autorizados` ficou restrito ao dono. Escritas de lançamentos e caminhão informado pelo motorista ficam reservadas à futura `sincronizar_lote`; decisões de entrada ficam reservadas às funções seguras futuras. A migration concede `SELECT`, `INSERT` e `UPDATE` ao papel `authenticated`, mas não concede `DELETE`; a RLS continua limitando cada operação. Essas políticas não foram validadas por teste de RLS.

## Dúvidas em aberto

- **não feito** — Confirmar tratamento de `empresa_id` na tabela `empresas` e mecanismo seguro de criação/vínculo inicial; hoje ainda não há fluxo de bootstrap nem função `criar_empresa`.
- **não feito** — Confirmar CPF obrigatório ou opcional, considerando cadastro/login por CPF versus minimização LGPD.
- **não feito** — Confirmar tipos, precisão, limites e nulabilidade dos campos que a arquitetura não detalha; confirmar unicidade e reaproveitamento de códigos/placas/CPF depois de exclusão lógica.
- **não feito** — Confirmar a matriz de escrita: o rascunho reserva gravação dos lançamentos e do caminhão informado pelo motorista à futura `sincronizar_lote`, e entrada/aprovação às funções seguras; definir quais gravações do gestor serão diretas. Confirmar também quais papéis podem editar caminhões, dispositivos, categorias e dados de motorista, como validar que IDs relacionados pertencem à mesma empresa, e se motorista pode corrigir lançamento sincronizado. A seção 14 já marca esta última escolha como pendente.
- **não feito** — Confirmar formato das views efetivas, quais campos podem ser ajustados e política completa de leitura dos ajustes; conferir compatibilidade com Postgres/Supabase alvo.
- **não feito** — Resolver as demais decisões explícitas da seção 14 antes das fases correspondentes: gestor em mais de uma empresa, nome definitivo do produto, fechamento de período e escolhas de autenticação/e-mail indicadas naquela seção.
- **não feito** — Definir nome e destino do repositório antes de criar ou enviar qualquer GitHub.
