# Passagem — revisão da migration da Plataforma de Gestão de Frota

## Escopo e situação

Revisão crítica **somente** de `supabase/migrations/20261014110000_esquema_inicial.sql`, sem criar outra migration nem alterar o escopo do produto. Foi criado `supabase/tests/isolamento_rls.sql` como rascunho de testes, por solicitação. Nenhum banco foi acessado ou alterado.

**Status: revisado por leitura; não testado em banco.** O arquivo de testes foi escrito, mas não executado. Não há confirmação de sintaxe SQL, execução, comportamento de triggers ou isolamento real. A execução futura requer banco local/de desenvolvimento, pgTAP habilitado e fixtures dedicadas; nunca usar dados de produção.

## Registro das nove áreas revisadas

1. **Isolamento de tenant nas relações:** chaves únicas compostas `(empresa_id, id)` e FKs compostas foram adicionadas às relações entre empresa, perfil, motorista, caminhão, frete, categoria, pedido e demais registros relacionados. Motivo: impedir que uma linha de uma empresa aponte para entidade de outra empresa mesmo se a política de aplicação falhar. A raiz `empresas` mantém `empresa_id = id` e FK autorreferente diferida.
2. **Exceções que não aceitam FK composta direta:** `pedidos_entrada.perfil_id` aceita perfil motorista ainda sem empresa; trigger valida perfil ativo, papel motorista e empresa nula ou coincidente, mantendo bloqueio `FOR KEY SHARE` durante a transação para evitar corrida de vinculação. `ajustes_gestor.registro_id` é polimórfico; trigger com allowlist valida existência do alvo na mesma empresa, bloqueia campos de identidade/tenant/sistema e valida valores de centavos, percentual e UUIDs relacionados. Essas exceções exigem os testes de concorrência e integridade ainda pendentes.
3. **RLS e privilégios:** RLS é habilitado nas 16 tabelas, com políticas por tabela e privilégios separados. `authenticated` não recebe `DELETE` físico; `anon` não recebe acesso às tabelas. As permissões efetivas estão detalhadas na matriz abaixo. RLS e privilégios não foram exercitados em banco.
4. **Escrita do motorista e lançamentos originais:** inserções do motorista em `fretes`, `abastecimentos`, `gastos_viagem`, `vales`, `ajustes_km` e `uso_caminhao` exigem empresa do perfil e motorista próprio, além dos vínculos compostos; novos lançamentos operacionais do motorista também são bloqueados se a empresa estiver suspensa. Dono/gestor não recebem `UPDATE` nem `DELETE` nos lançamentos originais. Ajustes ficam em tabela separada.
5. **Proteção do perfil:** não há grant/policy de escrita direta em `perfis`, impedindo que a pessoa altere seu próprio `papel` ou `empresa_id`. Criação, vínculo, aprovação e decisão dependem das funções seguras planejadas, que ainda não foram implementadas nesta migration.
6. **Código de entrada:** a política de `empresas` deixa ler a linha somente a perfil autenticado ativo vinculado àquela empresa; portanto `codigo_entrada` não é legível por contas sem vínculo ou de outro tenant. A política atual expõe o campo a **todos os membros ativos da empresa**, inclusive motorista; confirmar se o requisito futuro deve restringir a leitura a dono/gestor.
7. **Funções auxiliares e triggers:** quatro helpers de autorização usam `SECURITY DEFINER` e `search_path = ''`, têm execução concedida apenas a `authenticated` e revogada de `PUBLIC`/`anon`. Funções de trigger também usam caminho vazio e não recebem execução direta por clientes. Os helpers consultam perfis sem recursão de RLS; a validação de pedido usa bloqueio de linha. A propriedade e os privilégios do papel que aplicará a migration precisam ser conferidos no ambiente de desenvolvimento.
8. **Views de valores efetivos:** as quatro views usam `security_invoker = true`; o chamador depende do RLS e dos grants das tabelas subjacentes. O ajuste mais recente é projetado em `valores_efetivos`, sem alterar o lançamento original. A forma do JSON e a compatibilidade com a versão-alvo do Postgres ainda precisam ser testadas.
9. **Dados e timestamps:** não há default em coluna `id`; `atualizado_em` é sempre sobrescrito pelo trigger em INSERT e UPDATE. Foram incluídas verificações de centavos não negativos e inteiros nos ajustes, comissão entre 0 e 100, CPF com 11 dígitos e uso aberto único por motorista. A placa exige exatamente sete caracteres maiúsculos alfanuméricos, compatível com placa normalizada sem hífen, mas a regra exata continua como premissa a confirmar.

## Matriz de permissões RLS e grants

“Servidor/função segura” significa sem escrita direta pelo cliente autenticado prevista nesta migration. Nenhum papel tem `DELETE` físico. Dono e gestor são diferenciados onde as políticas realmente o fazem.

| Tabela | Leitura | Inserção | Atualização | Exclusão |
|---|---|---|---|---|
| `empresas` | Membros autenticados da própria empresa | Servidor/função segura | Servidor/função segura | Negada |
| `perfis` | Próprio perfil; dono/gestor leem perfis da empresa | Servidor/função segura | Servidor/função segura | Negada |
| `motoristas` | Próprio registro; dono/gestor leem a empresa | Servidor/função segura | Dono/gestor, somente coluna `ativo` | Negada |
| `acessos_autorizados` | Dono e gestor da empresa | Somente dono | Somente dono; colunas permitidas no grant | Negada |
| `dispositivos` | Dono/gestor da empresa e usuário do próprio dispositivo | Usuário cria o próprio dispositivo | Usuário altera apenas o próprio; colunas permitidas no grant | Negada |
| `caminhoes` | Dono/gestor; motorista vê os ativos não apagados da empresa | Dono/gestor; motorista pode sugerir caminhão não confirmado | Dono/gestor | Negada |
| `fretes` | Dono/gestor da empresa; motorista vê os próprios não apagados | Motorista somente para si, na própria empresa não suspensa | Negada diretamente; ajuste separado | Negada |
| `abastecimentos` | Dono/gestor da empresa; motorista vê os próprios não apagados | Motorista somente para si, na própria empresa não suspensa | Negada diretamente; ajuste separado | Negada |
| `categorias_gasto` | Membros veem ativas; dono/gestor também veem inativas | Dono/gestor | Dono/gestor | Negada |
| `gastos_viagem` | Dono/gestor da empresa; motorista vê os próprios não apagados | Motorista somente para si, na própria empresa não suspensa | Negada diretamente; ajuste separado | Negada |
| `vales` | Dono/gestor da empresa; motorista vê os próprios não apagados | Motorista somente para si, na própria empresa não suspensa | Negada diretamente; ajuste separado | Negada |
| `ajustes_km` | Dono/gestor da empresa; motorista vê os próprios não apagados | Motorista para si na empresa não suspensa; dono/gestor na própria empresa | Negada | Negada |
| `ajustes_gestor` | Dono/gestor veem a empresa; motorista vê ajustes dos próprios fretes, abastecimentos, gastos e vales | Dono/gestor, com `autor_id` igual ao usuário | Negada | Negada |
| `auditoria` | Dono/gestor da empresa, linhas não apagadas | Servidor/trigger | Negada | Negada |
| `pedidos_entrada` | Solicitante vê os próprios; dono/gestor veem os da empresa | Função segura planejada, sem grant direto | Função segura planejada, sem grant direto | Negada |
| `uso_caminhao` | Dono/gestor da empresa; motorista vê o próprio uso não apagado | Motorista para si ou dono/gestor na própria empresa | Motorista ou dono/gestor só fecha uso aberto, alterando somente `fim_em` | Negada |

As views `fretes_efetivos`, `abastecimentos_efetivos`, `gastos_viagem_efetivos` e `vales_efetivos` usam as mesmas regras de leitura das tabelas de origem por serem invoker. Não há rota direta para modificar nelas.

## Testes preparados, não executados

`supabase/tests/isolamento_rls.sql` contém quatro verificações: motorista A não lê frete de B; empresa X não lê empresa Y; gestor não apaga frete; FK composta impede frete de X referenciar caminhão de Y. O script usa variáveis UUID do `psql` e precisa de fixtures previamente semeadas para empresas X/Y, motoristas, gestor, fretes e caminhão. Requer `pgTAP` e role `authenticated` no banco de teste. **Não foi executado.** Não foram acessados nem alterados banco local, de desenvolvimento ou de produção.

## Dúvidas e limitações remanescentes

- Confirmar se `empresas.empresa_id` deve ser igual ao próprio `id` e como a primeira empresa será criada com segurança.
- Confirmar se o código de entrada deve ser visível também para motoristas já vinculados ou só para dono/gestor.
- Confirmar regra de placa: a constraint atual pressupõe exatamente sete caracteres em maiúsculas, sem hífen; não valida modelo/estrutura de placa além disso.
- O trigger de ajuste valida valores de centavos, percentual e os UUIDs relacionados explicitamente listados. Outros tipos de `valor_novo` ainda não têm validação genérica contra tipo, precisão e nulabilidade da coluna; manter o uso restrito até especificar e testar uma allowlist de campos ajustáveis.
- Confirmar se alterações de configuração por dono/gestor devem continuar possíveis quando empresa está suspensa. As políticas de novos registros operacionais do motorista bloqueiam empresa suspensa.
- Rever a política de leitura dos ajustes e o formato das views com consultas reais e testes RLS.
- A migration não implementa `criar_empresa`, `pedir_entrada`, `decidir_entrada`, `sincronizar_lote` nem escrita de auditoria; dependem de funções futuras e não devem ser presumidas existentes.

## Próximos passos

1. Claude Code deve revisar as dúvidas acima e este SQL antes de aplicar qualquer coisa.
2. Primeiro executar validação sintática e testes em banco Supabase local/de desenvolvimento isolado, com fixtures descartáveis; nunca tocar produção.
3. Corrigir e repetir testes se necessário; só depois considerar aprovação para outra etapa.
