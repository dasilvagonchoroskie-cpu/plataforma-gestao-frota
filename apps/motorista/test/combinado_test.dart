// Combinado de pagamento (pedido de 05/11/2026): frete por tonelada ou cheio,
// comissão sobre o frete cheio ou o que caiu na conta, com ou sem pedágio, e
// o salário fixo do combinado dele no Resumo.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'apoio.dart';
import 'modalidades_test.dart' show abrirApp, celularDe, tocar;

/// A lista da tela (os campos de texto também rolam, mas para o lado).
final lista = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first;

Future<void> preencher(WidgetTester tester, String rotulo, String texto) async {
  final campo = find.widgetWithText(TextField, rotulo);
  await tester.scrollUntilVisible(campo, 200, scrollable: lista);
  await tester.enterText(campo, texto);
  await tester.pumpAndSettle();
}

Future<void> verNaTela(WidgetTester tester, Finder f) =>
    tester.scrollUntilVisible(f, 300, scrollable: lista);

Future<void> abrirNovoFrete(WidgetTester tester, ServidorFalso s) async {
  final a = await celularDe(s);
  await abrirApp(tester, a, s);
  await tocar(tester, find.text('Fretes'));
  await tocar(tester, find.text('Novo frete'));
}

void main() {
  testWidgets('frete cheio: o valor fechado é o contratado e a base da comissão', (tester) async {
    final s = servidorComCadastros();
    await abrirNovoFrete(tester, s);
    await preencher(tester, 'Origem (de onde saiu)', 'Santos');
    await preencher(tester, 'Destino (para onde vai)', 'Goiânia');
    await tocar(tester, find.text('Frete cheio').first);
    await preencher(tester, 'Valor do frete cheio', '500000');
    await preencher(tester, 'Adiantamento', '350000');
    await preencher(tester, 'Saldo', '150000');
    await verNaTela(tester, find.text('A comissão é sobre'));
    await tocar(tester, find.widgetWithText(SegmentedButton<bool>, 'Frete cheio').last);
    await verNaTela(tester, find.text('Sua parte (13%)'));
    expect(find.text('Frete cheio (valor fechado)'), findsOneWidget);
    expect(find.text('R\$ 650,00'), findsOneWidget);
  });

  testWidgets('pedágio na comissão: entra só quando o motorista marca', (tester) async {
    final s = servidorComCadastros();
    await abrirNovoFrete(tester, s);
    await preencher(tester, 'Peso na carga', '37000');
    await preencher(tester, 'Valor da tonelada', '18500');
    await preencher(tester, 'Adiantamento', '480000');
    await preencher(tester, 'Saldo', '195000');
    await preencher(tester, 'Pedágio no cartão ou tag', '50000');
    await verNaTela(tester, find.text('Sua parte (13%)'));
    expect(find.text('R\$ 877,50'), findsOneWidget, reason: 'sem pedágio: 13% de 6.750');
    await verNaTela(tester, find.text('Entra na comissão'));
    await tocar(tester, find.text('Entra na comissão'));
    await verNaTela(tester, find.text('Sua parte (13%)'));
    expect(find.text('R\$ 942,50'), findsOneWidget, reason: 'com pedágio: 13% de 7.250');
    expect(find.text('O que caiu na conta + pedágio'), findsOneWidget);
  });

  testWidgets('salário fixo: o resumo mostra o fixo e o frete não pede comissão', (tester) async {
    final s = servidorComCadastros()..combinado = {'percentual_comissao': 0, 'salario_fixo_centavos': 300000};
    final a = await celularDe(s);
    await abrirApp(tester, a, s);
    await tocar(tester, find.text('Resumo').last);
    expect(find.text('Salário fixo'), findsOneWidget);
    expect(find.text('+ R\$ 3.000,00'), findsOneWidget, reason: 'o mês inteiro');
    expect(find.text('Comissão'), findsNothing, reason: 'só fixo');

    await tocar(tester, find.text('Início').last);
    await tocar(tester, find.text('Fretes'));
    await tocar(tester, find.text('Novo frete'));
    await verNaTela(tester, find.textContaining('Você ganha salário fixo'));
    expect(find.text('Sua comissão'), findsNothing);
  });

  testWidgets('configurações mostram como ele ganha (fixo + %)', (tester) async {
    final s = servidorComCadastros()..combinado = {'percentual_comissao': 3, 'salario_fixo_centavos': 250000};
    final a = await celularDe(s);
    await abrirApp(tester, a, s);
    await tester.tap(find.byTooltip('Configurações'));
    await tester.pumpAndSettle();
    await verNaTela(tester, find.text('Como você ganha'));
    expect(find.text('Fixo + %'), findsOneWidget);
    expect(find.text('R\$ 2.500,00'), findsOneWidget);
    expect(find.text('3%'), findsOneWidget);
  });
}
