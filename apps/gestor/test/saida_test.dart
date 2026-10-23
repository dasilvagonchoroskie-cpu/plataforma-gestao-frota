// Motorista que sai da empresa (regra aprovada em 23/10/2026): desligar solta
// o login na hora; a empresa fica com o registro (nome, CPF e lançamentos);
// para voltar, o painel gera um código novo e ele começa um cadastro novo.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestor/servidor/servidor.dart';

import 'apoio.dart';

void main() {
  testWidgets('desligar avisa que o login fica livre e o registro fica na empresa', (tester) async {
    final s = servidorComAmostra();
    await abrirApp(tester, s);
    await tester.tap(find.text('Motoristas').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Pedro Henrique').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pedro Henrique').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Mais ações'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Desligar da empresa').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('o login dele fica livre para entrar em outra empresa'), findsOneWidget);
    expect(find.textContaining('nome, CPF e tudo o que já mandou'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Desligar'));
    await tester.pumpAndSettle();
    final pedro = s.t(Fontes.motoristas).firstWhere((m) => m['nome'] == 'Pedro Henrique');
    expect(pedro['perfil_id'], isNull, reason: 'o login sai do cadastro');
    expect(pedro['email'], isNull, reason: 'o e-mail sai do registro');
    expect(find.textContaining('Saiu da empresa em'), findsOneWidget);
    await tester.tap(find.byTooltip('Mais ações'));
    await tester.pumpAndSettle();
    expect(find.text('Gerar código para voltar'), findsOneWidget);
    expect(find.text('Desligar da empresa'), findsNothing);
  });

  testWidgets('quem saiu volta com um código novo, gerado no registro dele', (tester) async {
    final s = servidorComAmostra();
    await abrirApp(tester, s);
    await tester.tap(find.text('Motoristas').first);
    await tester.pumpAndSettle();
    expect(find.text('Saíram da empresa (1)'), findsOneWidget);
    expect(find.textContaining('só o registro'), findsOneWidget);
    await tester.ensureVisible(find.text('Carlos Souza').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Carlos Souza').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Mais ações'));
    await tester.pumpAndSettle();
    expect(find.text('Desligar da empresa'), findsNothing);
    expect(find.text('Redefinir o acesso'), findsNothing);
    await tester.tap(find.text('Gerar código para voltar').last);
    await tester.pumpAndSettle();
    expect(s.chamadas, contains('convite Carlos Souza 15350946056'));
    expect(find.textContaining('K7M2QX'), findsWidgets);
  });
}
