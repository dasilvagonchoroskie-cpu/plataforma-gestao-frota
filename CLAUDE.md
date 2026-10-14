# Regras de trabalho

Leia `docs/ARQUITETURA.md` inteiro antes de qualquer ação. Siga as fases da seção 12 e os limites da seção 17. Não crie escopo novo.

- Explique em português simples, em poucas linhas e um passo por vez.
- Antes de alterar arquivos, apresente um plano de 3 a 5 linhas e espere o OK. Faça commits pequenos em português.
- Nunca coloque senhas ou `service_role` no código nem peça para colá-las no chat. Só a chave pública `anon` pode ficar na configuração dos apps.
- Nunca altere o banco de produção diretamente. Toda mudança de banco deve estar em migration versionada.
- Antes de declarar uma etapa pronta, rode análise e testes e mostre o comando e o resultado. Não chame de testado o que não rodou.
- Ao fim de cada etapa, atualize `docs/PROGRESSO.md`.
- Nomes de tabelas e colunas em português e `snake_case`; classes em português e `PascalCase`.
- O Meu Frete é somente referência de leitura. Nunca altere esse app; não comece a Fase 2 sem o usuário disponibilizar a pasta de referência.
- Este projeto é independente da plataforma de gás e água. Não misture código, banco ou contas.
- Se algo estiver ambíguo, anote em `docs/PASSAGEM.md` em vez de decidir sozinho.
