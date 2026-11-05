// Forma de pagamento do gasto (pedido de 23/10/2026): o motorista escolhe
// toda vez se pagou em dinheiro (do vale) ou assinou a nota; o que foi em
// dinheiro abate do vale no Resumo.
import 'package:flutter_test/flutter_test.dart';
import 'package:nucleo/nucleo.dart';

import 'apoio.dart';
import 'modalidades_test.dart' show abrirApp, celularDe, preencher, tocar;

void main() {
  testWidgets('novo gasto: só salva depois de escolher como pagou; o dinheiro aparece na lista', (tester) async {
    final s = servidorComCadastros();
    final a = await celularDe(s, comAmostra: true);
    await abrirApp(tester, a, s);
    await tocar(tester, find.text('Gastos'));
    await tocar(tester, find.text('Novo gasto'));
    expect(find.text('Como você pagou?'), findsOneWidget);
    await preencher(tester, 'Valor', '12000');
    await tocar(tester, find.text('Borracharia'));
    await tocar(tester, find.text('Salvar gasto'));
    expect(find.text('Escolha como você pagou.'), findsOneWidget, reason: 'nada vem marcado');
    expect((await a.registros('gastos_viagem')).length, 2, reason: 'não salvou');

    await tocar(tester, find.text('Paguei em dinheiro'));
    await tocar(tester, find.text('Salvar gasto'));
    expect(find.text('Gasto salvo.'), findsOneWidget);
    final novo = (await a.registros('gastos_viagem')).firstWhere((g) => g['valor_centavos'] == 12000);
    expect(novo['forma_pagamento'], 'dinheiro');
    expect(find.text('Pago em dinheiro'), findsOneWidget);
    expect(find.text('Na nota'), findsNWidgets(2), reason: 'os gastos antigos contam como nota');
  });

  testWidgets('resumo: o gasto pago em dinheiro abate do vale e volta para o motorista', (tester) async {
    final s = servidorComCadastros();
    final a = await celularDe(s, comAmostra: true);
    await a.gravarRegistros('gastos_viagem', [
      Gasto(id: 'g3', motoristaId: motoristaA, caminhaoId: caminhao1, data: DateTime.now(), categoriaId: 'cat-Chapa',
          valorCentavos: 12000, formaPagamento: FormaPagamento.dinheiro).paraMapa(),
    ]);
    await abrirApp(tester, a, s);
    await tocar(tester, find.text('Resumo').last);
    expect(find.text('Gastos pagos em dinheiro'), findsOneWidget);
    expect(find.text('+ R\$ 120,00'), findsOneWidget);
    expect(find.text('Você pagou com o dinheiro do vale, então voltam para você'), findsOneWidget);
  });

  testWidgets('mudar gasto antigo: já vem como nota e dá para trocar para dinheiro', (tester) async {
    final s = servidorComCadastros();
    final a = await celularDe(s, comAmostra: true);
    await abrirApp(tester, a, s);
    await tocar(tester, find.text('Gastos'));
    await tocar(tester, find.text('Borracharia').first);
    expect(find.text('Mudar gasto'), findsOneWidget);
    await tocar(tester, find.text('Paguei em dinheiro'));
    await tocar(tester, find.text('Salvar alteração'));
    expect((await a.registro('gastos_viagem', 'g1'))!['forma_pagamento'], 'dinheiro');
  });
}
