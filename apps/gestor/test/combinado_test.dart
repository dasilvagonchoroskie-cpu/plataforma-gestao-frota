// Combinado de pagamento no painel (pedido de 05/11/2026): o dono define o
// padrão da empresa e o gestor muda só para um motorista; o resumo dele leva
// o salário fixo.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestor/servidor/servidor.dart';

import 'apoio.dart';
import 'modalidades_test.dart' show abrirMotorista, tocar;

Future<void> preencher(WidgetTester tester, String rotulo, String texto) async {
  final campo = find.widgetWithText(TextField, rotulo);
  await tester.ensureVisible(campo);
  await tester.enterText(campo, texto);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('o dono muda o padrão da empresa: fixo + % do frete cheio com pedágio', (tester) async {
    final s = servidorComAmostra();
    await abrirApp(tester, s);
    await tester.tap(find.text('Configurações').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Comissão de 13% do que caiu na conta, sem pedágio'), findsOneWidget);
    await tocar(tester, find.text('Regras de acerto com o motorista'));
    await tocar(tester, find.text('Fixo + %'));
    await preencher(tester, 'Salário fixo por mês', '300000');
    await preencher(tester, 'Porcentagem dos fretes dele', '3');
    await tocar(tester, find.text('O frete cheio'));
    await tocar(tester, find.text('Entra na conta da porcentagem'));
    await tocar(tester, find.text('Salvar regras'));
    final e = s.empresa;
    expect(e['salario_fixo_centavos'], 300000);
    expect(e['percentual_comissao_padrao'], 3);
    expect(e['comissao_sobre_bruto_padrao'], isTrue);
    expect(e['comissao_com_pedagio_padrao'], isTrue);
    expect(find.textContaining(r'Fixo de R$ 3.000,00 por mês + 3% do frete cheio, com pedágio'), findsOneWidget);
  });

  testWidgets('fixo sem valor não salva', (tester) async {
    final s = servidorComAmostra();
    await abrirApp(tester, s);
    await tester.tap(find.text('Configurações').first);
    await tester.pumpAndSettle();
    await tocar(tester, find.text('Regras de acerto com o motorista'));
    await tocar(tester, find.text('Salário fixo'));
    await tocar(tester, find.text('Salvar regras'));
    expect(find.text('Informe o salário fixo por mês.'), findsOneWidget);
    expect(s.chamadas.where((c) => c.startsWith('alterar empresas')), isEmpty);
  });

  testWidgets('combinado só de um motorista: salário fixo no resumo dele; depois volta ao padrão', (tester) async {
    final s = servidorComAmostra();
    await abrirApp(tester, s);
    await abrirMotorista(tester, 'João Batista');
    await tocar(tester, find.widgetWithText(Tab, 'Cadastro'));
    expect(find.text('Padrão da empresa'), findsOneWidget);
    await tocar(tester, find.widgetWithText(OutlinedButton, 'Mudar').first);
    await tocar(tester, find.text('Um combinado só para ele'));
    await tocar(tester, find.text('Salário fixo'));
    await preencher(tester, 'Salário fixo por mês', '250000');
    await tocar(tester, find.text('Salvar'));
    final joao = s.t(Fontes.motoristas).firstWhere((m) => m['nome'] == 'João Batista');
    expect(joao['salario_fixo_centavos'], 250000);
    expect(joao['percentual_comissao'], 0);
    expect(find.text('Combinado só dele'), findsOneWidget);
    expect(find.textContaining(r'Salário fixo de R$ 2.500,00 por mês'), findsOneWidget);

    await tocar(tester, find.widgetWithText(Tab, 'Como ele vê'));
    await tester.scrollUntilVisible(find.text('Salário fixo'), 200, scrollable: find.byType(Scrollable).last);
    expect(find.text(r'+ R$ 2.500,00'), findsOneWidget, reason: 'o mês inteiro');

    await tocar(tester, find.widgetWithText(Tab, 'Cadastro'));
    await tocar(tester, find.widgetWithText(OutlinedButton, 'Mudar').first);
    await tocar(tester, find.text('O padrão da empresa'));
    await tocar(tester, find.text('Salvar'));
    expect(joao['salario_fixo_centavos'], isNull, reason: 'volta a seguir a empresa');
    expect(find.text('Padrão da empresa'), findsOneWidget);
  });
}
