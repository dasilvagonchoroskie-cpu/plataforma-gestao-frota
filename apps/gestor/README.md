# App e painel do gestor

Um código Flutter só: vira app de celular (Android) e painel web no computador.
No computador aparece o menu lateral; no celular, as abas embaixo.

## O que tem

- Entrar com e-mail e senha, criar a conta (código no e-mail) e esqueci a senha.
- Painel: faturamento, diesel, gastos, comissões, resultado, vales, o que falta
  pagar aos motoristas e saldo a receber; alertas (pedido de entrada, caminhão
  para conferir, dois motoristas no mesmo caminhão, motorista sem enviar).
- Motoristas: código da empresa, aprovar ou recusar pedidos, caminhão atual,
  desligar ou religar, redefinir o acesso (senha provisória) e "como ele vê"
  (o mesmo resumo do app do motorista, componente `CorpoResumo` do pacote visual).
- Caminhões: cadastro, confirmação dos cadastrados por motorista, km rodados,
  média de diesel, custo por km, resultado e quem dirigiu.
- Lançamentos: fretes, diesel, gastos e vales com filtro por período, motorista,
  caminhão e embarcador. Tocar num lançamento abre a correção (ajuste com motivo e
  histórico; o original do motorista nunca muda).
- Relatórios: PDF (mesmo modelo do app do motorista) e planilhas CSV da frota,
  de um motorista, de um caminhão ou de um embarcador.
- Configurações: dados e regras de acerto da empresa (só o dono), categorias de
  gasto, donos e gestores, celulares dos motoristas, trocar senha e sair.

As contas vêm do pacote `nucleo` (as mesmas do app do motorista).

## Testes

    flutter analyze
    flutter test --exclude-tags capturas
    flutter test --tags capturas --update-goldens   # imagens em test/capturas

## Publicação

A esteira (`.github/workflows/esteira.yml`, job `gestor`) testa, gera o APK no
Release `gestor-teste` e publica o painel web no ramo `gh-pages`.
