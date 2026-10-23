import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestor/servidor/servidor.dart';
import 'package:nucleo/nucleo.dart';

import 'apoio.dart';

/// Empresa com Graneleiro e Baú: João no Baú (com viagens), Pedro no Graneleiro.
ServidorFalso servidorComBau({String usuario = euDono}) {
  final s = servidorComAmostra(usuario: usuario)..ligarModalidade('bau');
  for (final m in s.t(Fontes.motoristas)) {
    m['modalidade'] = m['id'] == joao ? 'bau' : 'graneleiro';
  }
  s.t(Fontes.viagens).addAll([
    Viagem(
      id: 'vg1',
      motoristaId: joao,
      caminhaoId: cam1,
      placaCarreta: 'ABC1D23',
      engateLocal: 'Cajamar SP',
      engateEm: dia(2),
      desengateLocal: 'Ribeirão Preto SP',
      desengateEm: dia(3),
      entregasQuantidade: 3,
      entregasCidades: const ['Campinas', 'Limeira', 'Araras'],
      extras: const {'lacre': '778'},
    ).paraMapa(),
    Viagem(
      id: 'vg2',
      motoristaId: joao,
      caminhaoId: cam1,
      placaCarreta: 'XYZ1234',
      engateLocal: 'Ribeirão Preto SP',
      engateEm: dia(4),
    ).paraMapa(),
  ]);
  return s;
}

Future<void> tocar(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Future<void> abrirMotorista(WidgetTester tester, String nome) async {
  await tester.tap(find.text('Motoristas').first);
  await tester.pumpAndSettle();
  await tocar(tester, find.text(nome).first);
}

void main() {
  testWidgets('o dono liga o Baú e ajusta os campos do Graneleiro', (tester) async {
    final s = servidorComAmostra();
    await abrirApp(tester, s);
    await tester.tap(find.text('Configurações').first);
    await tester.pumpAndSettle();
    await tocar(tester, find.text('Modalidades de operação'));
    expect(find.text('Baú'), findsOneWidget);

    final switchBau = find.descendant(of: find.widgetWithText(ListTile, 'Baú'), matching: find.byType(Switch));
    await tocar(tester, switchBau);
    expect(s.chamadas, contains('modalidade bau true'));

    await tocar(tester, find.text('Graneleiro'));
    expect(find.text('Campos: Graneleiro'), findsOneWidget);
    final cartaoEmbarcador = find.ancestor(of: find.text('Embarcador ou cliente'), matching: find.byType(Card));
    await tester.enterText(
      find.descendant(of: cartaoEmbarcador, matching: find.byType(TextField)),
      'Cliente',
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -2000));
    await tester.pumpAndSettle();
    final cartaoSaldo = find.ancestor(of: find.text('Saldo').first, matching: find.byType(Card));
    await tocar(tester, find.descendant(of: cartaoSaldo, matching: find.widgetWithText(SwitchListTile, 'Obrigatório')));
    await tocar(tester, find.text('Salvar campos'));
    final salvo = s.chamadas.lastWhere((c) => c.startsWith('modalidade graneleiro true '));
    final campos = jsonDecode(salvo.substring('modalidade graneleiro true '.length)) as Map;
    expect(campos['embarcador'], {'rotulo': 'Cliente', 'visivel': true, 'obrigatorio': false});
    expect(campos['saldo_centavos'], {'visivel': true, 'obrigatorio': true});
    expect(campos['origem'], isEmpty, reason: 'campo que não pode sumir só aceita nome');
  });

  testWidgets('o gestor vê as modalidades mas não liga nem muda', (tester) async {
    final s = servidorComAmostra(usuario: euGestor);
    await abrirApp(tester, s);
    await tester.tap(find.text('Configurações').first);
    await tester.pumpAndSettle();
    await tocar(tester, find.text('Modalidades de operação'));
    final switchBau = tester.widget<Switch>(
      find.descendant(of: find.widgetWithText(ListTile, 'Baú'), matching: find.byType(Switch)),
    );
    expect(switchBau.onChanged, isNull);
    await tocar(tester, find.text('Graneleiro'));
    expect(find.text('Salvar campos'), findsNothing);
  });

  testWidgets('com duas modalidades, o cadastro do motorista pede a modalidade', (tester) async {
    final s = servidorComBau();
    await abrirApp(tester, s);
    await tester.tap(find.text('Motoristas').first);
    await tester.pumpAndSettle();
    await tocar(tester, find.text('Cadastrar motorista'));
    final campos = find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField));
    await tester.enterText(campos.at(0), 'Novo Motorista');
    await tester.enterText(campos.at(1), '52998224725');
    await tocar(tester, find.text('Gerar código'));
    expect(find.text('Escolha a modalidade.'), findsOneWidget);
    await tocar(tester, find.text('Modalidade'));
    await tocar(tester, find.text('Baú  (por viagem)').last);
    await tocar(tester, find.text('Gerar código'));
    expect(s.chamadas, contains('convite Novo Motorista 52998224725 bau'));
    expect(find.text('K7M2QX'), findsOneWidget);
  });

  testWidgets('motorista do Baú: viagens, acerto fechado pelo gestor e troca de modalidade', (tester) async {
    final s = servidorComBau();
    await abrirApp(tester, s);
    await abrirMotorista(tester, 'João Batista');
    expect(find.text('Viagens'), findsWidgets);
    expect(find.text('Acertos'), findsOneWidget);
    expect(find.text('Fretes'), findsNothing);

    await tocar(tester, find.widgetWithText(Tab, 'Viagens'));
    expect(find.text('Cajamar SP  –  Ribeirão Preto SP'), findsOneWidget);
    expect(find.text('Em andamento'), findsOneWidget);
    await tocar(tester, find.text('Cajamar SP  –  Ribeirão Preto SP'));
    expect(find.text('Campinas, Limeira, Araras'), findsOneWidget);
    expect(find.text('lacre'), findsOneWidget, reason: 'campo novo sem nome no catálogo aparece pela chave');
    tester.state<NavigatorState>(find.byType(Navigator).last).pop();
    await tester.pumpAndSettle();

    await tocar(tester, find.widgetWithText(Tab, 'Acertos'));
    await tocar(tester, find.text('Fazer acerto'));
    expect(find.text('Viagens (2)'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Comissão do período'), '150000');
    await tocar(tester, find.text('Pôr um desconto'));
    await tester.enterText(find.widgetWithText(TextField, 'Motivo do desconto'), 'Multa');
    await tester.enterText(find.widgetWithText(TextField, 'Valor'), '10000');
    await tester.pumpAndSettle();
    // 1.500 - 100 de multa - 500 de vale (o vale desconta; diesel e gastos a empresa paga).
    expect(find.text('R\$ 900,00'), findsOneWidget);
    await tocar(tester, find.text('Fechar acerto').last);
    await tocar(
      tester,
      find.descendant(of: find.byType(AlertDialog), matching: find.widgetWithText(FilledButton, 'Fechar acerto')),
    );
    expect(s.chamadas.where((c) => c.startsWith('acerto $joao ')), hasLength(1));
    expect(s.chamadas.last, contains(' 150000'));
    expect(find.text('Acerto fechado.'), findsOneWidget);
    expect(find.text('R\$ 900,00'), findsOneWidget, reason: 'o acerto aparece na lista');

    await tester.tap(find.byTooltip('Mais ações'));
    await tester.pumpAndSettle();
    await tocar(tester, find.text('Trocar a modalidade dele'));
    await tocar(tester, find.text('Graneleiro').last);
    expect(find.textContaining('O jeito de lançar muda'), findsOneWidget);
    await tocar(tester, find.widgetWithText(FilledButton, 'Trocar'));
    expect(s.chamadas, contains('modalidade do motorista $joao graneleiro'));
  });

  testWidgets('a Plataforma cria uma modalidade nova e um campo novo', (tester) async {
    final s = servidorComAmostra()..admin = true;
    await abrirApp(tester, s);
    await tester.tap(find.text('Configurações').first);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Área da Plataforma'), 300, scrollable: find.byType(Scrollable).first);
    await tocar(tester, find.text('Área da Plataforma'));
    await tocar(tester, find.byTooltip('Modalidades e campos'));
    await tocar(tester, find.text('Nova modalidade'));
    await tester.enterText(find.widgetWithText(TextField, 'Nome'), 'Porta-contêiner');
    await tocar(tester, find.text('Por viagem (como o Baú)'));
    await tocar(tester, find.text('Criar'));
    expect(s.acoesPlataforma, contains('modalidade porta_conteiner Porta-contêiner viagem true'));

    await tocar(tester, find.text('Porta-contêiner'));
    await tocar(tester, find.text('Novo campo'));
    await tester.enterText(find.widgetWithText(TextField, 'Nome que o motorista vê'), 'Número do lacre');
    await tocar(tester, find.text('Criar'));
    final campo = s.acoesPlataforma.last;
    expect(campo, startsWith('campo porta_conteiner '));
    expect(jsonDecode(campo.substring('campo porta_conteiner '.length)), {
      'chave': 'numero_do_lacre',
      'rotulo': 'Número do lacre',
      'tipo': 'texto',
      'obrigatorio': false,
      'desativado': false,
      'etapa': 'engate',
    });
    expect(find.text('Número do lacre'), findsOneWidget);
  });
}
