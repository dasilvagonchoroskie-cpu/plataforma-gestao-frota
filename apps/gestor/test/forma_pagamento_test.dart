// Forma de pagamento do gasto no painel (pedido de 23/10/2026): o gestor vê o
// que foi pago em dinheiro (do vale), corrige se preciso e o acerto devolve
// esse dinheiro ao motorista.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestor/servidor/servidor.dart';
import 'package:gestor/telas/lancamentos/detalhe_lancamento.dart';

import 'apoio.dart';
import 'modalidades_test.dart' show abrirMotorista, servidorComBau, tocar;

void pagoEmDinheiro(ServidorFalso s, String id) =>
    s.t(Fontes.gastos).firstWhere((g) => g['id'] == id)['forma_pagamento'] = 'dinheiro';

void main() {
  testWidgets('o gasto pago em dinheiro aparece marcado e o resumo devolve ao motorista', (tester) async {
    final s = servidorComAmostra();
    pagoEmDinheiro(s, 'g1');
    await abrirApp(tester, s);
    await abrirMotorista(tester, 'João Batista');
    await tocar(tester, find.widgetWithText(Tab, 'Gastos'));
    expect(find.text('Pago em dinheiro'), findsOneWidget);
    await tocar(tester, find.widgetWithText(Tab, 'Como ele vê'));
    await tester.scrollUntilVisible(find.text('Gastos pagos em dinheiro'), 200, scrollable: find.byType(Scrollable).last);
    expect(find.text('Gastos pagos em dinheiro'), findsOneWidget);
    expect(find.text('+ R\$ 80,00'), findsOneWidget);
  });

  testWidgets('o gestor corrige a forma de pagamento com motivo', (tester) async {
    final s = servidorComAmostra();
    await abrirApp(tester, s);
    await abrirMotorista(tester, 'João Batista');
    await tocar(tester, find.widgetWithText(Tab, 'Gastos'));
    await tocar(tester, find.text('Borracharia').first);
    final lista = find.descendant(of: find.byType(TelaDetalheLancamento), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(find.text('Forma de pagamento'), 200, scrollable: lista);
    expect(find.text('Nota assinada'), findsOneWidget, reason: 'gasto antigo conta como nota');
    await tocar(tester, find.text('Forma de pagamento'));
    expect(find.text('Corrigir forma de pagamento'), findsOneWidget);
    await tocar(tester, find.text('Nota assinada (a empresa paga)'));
    await tocar(tester, find.text('Pago em dinheiro (do vale)').last);
    final campos = find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField));
    await tester.enterText(campos.last, 'Conferido com o motorista');
    await tocar(tester, find.text('Salvar correção'));
    final ajuste = s.t('ajustes_gestor').single;
    expect(ajuste['campo'], 'forma_pagamento');
    expect(ajuste['valor_novo'], 'dinheiro');
  });

  testWidgets('acerto do Baú: o gasto pago em dinheiro abate do vale', (tester) async {
    final s = servidorComBau();
    pagoEmDinheiro(s, 'g1');
    await abrirApp(tester, s);
    await abrirMotorista(tester, 'João Batista');
    await tocar(tester, find.widgetWithText(Tab, 'Acertos'));
    await tocar(tester, find.text('Fazer acerto'));
    await tester.enterText(find.widgetWithText(TextField, 'Comissão do período'), '150000');
    await tester.pumpAndSettle();
    expect(find.text('Gastos pagos em dinheiro'), findsOneWidget);
    // 1.500 de comissão - 500 de vale + 80 do gasto pago em dinheiro.
    expect(find.text('R\$ 1.080,00'), findsOneWidget);
    await tocar(tester, find.text('Fechar acerto').last);
    await tocar(
      tester,
      find.descendant(of: find.byType(AlertDialog), matching: find.widgetWithText(FilledButton, 'Fechar acerto')),
    );
    final acerto = s.t(Fontes.acertos).single;
    expect(acerto['gastos_dinheiro_centavos'], 8000);
    expect(acerto['para_receber_centavos'], 108000);
  });
}
