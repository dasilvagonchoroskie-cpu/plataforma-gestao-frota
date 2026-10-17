import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestor/servidor/servidor.dart';
import 'package:gestor/telas/lancamentos/detalhe_lancamento.dart';

import 'apoio.dart';

void main() {
  testWidgets('entrar com e-mail e senha abre o painel da empresa', (tester) async {
    final s = servidorComAmostra()..sessao = false;
    await abrirApp(tester, s);
    expect(find.text('Criar minha conta'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'dono@teste.com');
    await tester.enterText(find.byType(TextField).at(1), 'errada');
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();
    expect(find.text('E-mail ou senha incorretos.'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(1), 'segredo1');
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();
    expect(find.text('Faturamento'), findsWidgets);
    expect(find.text('Transportes Goiatuba'), findsWidgets);
    expect(find.byType(NavigationRail), findsOneWidget, reason: 'no computador o menu fica do lado');
  });

  testWidgets('no celular as partes ficam nas abas de baixo', (tester) async {
    await abrirApp(tester, servidorComAmostra(), tela: celular, densidade: 2.75);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.text('Faturamento'), findsWidgets);
  });

  testWidgets('aprovar o motorista que pediu para entrar', (tester) async {
    final s = servidorComAmostra();
    await abrirApp(tester, s);
    expect(find.text('1 motorista quer entrar'), findsOneWidget);
    await tester.tap(find.text('1 motorista quer entrar'));
    await tester.pumpAndSettle();

    expect(find.text('Marcos Vinícius'), findsOneWidget);
    expect(find.textContaining('529.982.247-25'), findsOneWidget, reason: 'o gestor confere o CPF antes de aprovar');
    await tester.tap(find.text('Aprovar'));
    await tester.pumpAndSettle();

    expect(s.chamadas, contains('decidir ped-1 true'));
    expect(find.text('Marcos Vinícius entrou na empresa.'), findsOneWidget);
    expect(find.text('Pedidos para entrar'), findsNothing);
    expect(find.text('Marcos Vinícius'), findsOneWidget, reason: 'agora aparece na lista da empresa');
  });

  testWidgets('corrigir o saldo de um frete com motivo (o original fica)', (tester) async {
    final s = servidorComAmostra();
    await abrirApp(tester, s);
    await tester.tap(find.text('Lançamentos'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Paranaguá (PR)  –  Rio Verde (GO)'));
    await tester.pumpAndSettle();

    final lista = find.descendant(of: find.byType(TelaDetalheLancamento), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(find.text('Saldo'), 200, scrollable: lista);
    await tester.tap(find.text('Saldo'));
    await tester.pumpAndSettle();
    expect(find.text('Corrigir saldo'), findsOneWidget);
    final campos = find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField));
    await tester.enterText(campos.at(0), '150000');
    await tester.tap(find.text('Salvar correção'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Escreva o motivo'), findsOneWidget, reason: 'sem motivo não salva');

    await tester.enterText(campos.at(1), 'Conferido no extrato');
    await tester.tap(find.text('Salvar correção'));
    await tester.pumpAndSettle();

    final ajuste = s.t('ajustes_gestor').single;
    expect(ajuste['campo'], 'saldo_centavos');
    expect(ajuste['valor_novo'], 150000);
    expect(ajuste['valor_novo'], isA<int>());
    expect(ajuste['motivo'], 'Conferido no extrato');
    expect(ajuste['autor_id'], euDono);
    await tester.scrollUntilVisible(find.textContaining('"Conferido no extrato"'), 200, scrollable: lista);
    expect(find.textContaining('"Conferido no extrato"'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Corrigido pela gestão'), -200, scrollable: lista);
    expect(find.text('Corrigido pela gestão'), findsOneWidget);
  });

  testWidgets('ver o resumo como o motorista vê no app dele', (tester) async {
    await abrirApp(tester, servidorComAmostra());
    await tester.tap(find.text('Motoristas').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('João Batista'));
    await tester.pumpAndSettle();
    expect(find.text('Você tem para receber'), findsOneWidget);
    expect(find.text('Conta do caminhão'), findsOneWidget);
    expect(find.textContaining('mesma tela que João vê'), findsOneWidget);
  });

  testWidgets('trocar o caminhão de um motorista pelo painel', (tester) async {
    final s = servidorComAmostra();
    await abrirApp(tester, s);
    await tester.tap(find.text('Motoristas').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pedro Henrique'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Mais ações'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trocar o caminhão dele'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Frota 07  ·  Scania R450'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trocar'));
    await tester.pumpAndSettle();
    expect(s.chamadas, contains('caminhao $pedro $cam1'));
    expect(find.text('Caminhão trocado.'), findsOneWidget);
  });

  testWidgets('cadastrar caminhão: placa errada e placa repetida não passam', (tester) async {
    final s = servidorComAmostra();
    await abrirApp(tester, s);
    await tester.tap(find.text('Caminhões').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Novo caminhão'));
    await tester.pumpAndSettle();
    final campos = find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField));

    await tester.enterText(campos.at(0), 'AB12');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Placa inválida'), findsOneWidget);

    await tester.enterText(campos.at(0), 'def4567');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Já existe um caminhão'), findsOneWidget);

    await tester.enterText(campos.at(0), 'GHI2J34');
    await tester.enterText(campos.at(1), '15');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    final novo = s.t('caminhoes').last;
    expect(novo['placa'], 'GHI2J34');
    expect(novo['numero_frota'], '15');
    expect(novo['confirmado'], true);
    expect(novo['empresa_id'], empresaId);
  });

  testWidgets('gestor vê as regras mas só o dono muda', (tester) async {
    await abrirApp(tester, servidorComAmostra(usuario: euGestor));
    await tester.tap(find.text('Configurações'));
    await tester.pumpAndSettle();
    expect(find.text('Só o dono muda os dados e as regras da empresa.'), findsOneWidget);
    await tester.tap(find.text('Donos e gestores'));
    await tester.pumpAndSettle();
    expect(find.text('Liberar gestor'), findsNothing);
  });

  testWidgets('dono libera um gestor pelo e-mail', (tester) async {
    final s = servidorComAmostra();
    await abrirApp(tester, s);
    await tester.tap(find.text('Configurações'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Donos e gestores'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Liberar gestor'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)),
      'Nova.Gestora@Teste.com',
    );
    await tester.tap(find.text('Liberar'));
    await tester.pumpAndSettle();
    final a = s.t('acessos_autorizados').last;
    expect(a['email'], 'nova.gestora@teste.com');
    expect(a['papel'], 'gestor');
  });

  testWidgets('sem internet ao abrir: mostra o aviso e deixa tentar de novo', (tester) async {
    final s = servidorComAmostra()..online = false;
    await abrirApp(tester, s);
    expect(find.text('Não deu para abrir'), findsOneWidget);
    expect(find.text(erroSemInternet.mensagem), findsOneWidget);
    s.online = true;
    await tester.tap(find.text('Tentar de novo'));
    await tester.pumpAndSettle();
    expect(find.text('Faturamento'), findsWidgets);
  });
}
