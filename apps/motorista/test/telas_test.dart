import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motorista/app.dart';
import 'package:motorista/dados/armazenamento.dart';
import 'package:motorista/dados/dados.dart';
import 'package:motorista/telas/casca.dart';

import 'amostra.dart';
import 'apoio.dart';

Future<ArmazenamentoMemoria> abrir(WidgetTester tester, {ArmazenamentoMemoria? a, ServidorFalso? s}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  final armazenamento = a ?? await celularComAmostra();
  final servidor = s ?? servidorComCadastros();
  servidor.online = false;
  await tester.pumpWidget(ProviderScope(
    overrides: [
      armazenamentoProvider.overrideWithValue(armazenamento),
      servidorProvider.overrideWithValue(servidor),
      sincronizarSozinhoProvider.overrideWithValue(false),
    ],
    child: const AplicativoMotorista(),
  ));
  await tester.pumpAndSettle();
  return armazenamento;
}

void main() {
  testWidgets('celular já aprovado abre direto no resumo, mesmo sem internet', (tester) async {
    await abrir(tester);
    expect(find.text('Você tem para receber'), findsOneWidget);
    expect(find.text('Lançando neste caminhão'), findsOneWidget);
    expect(find.textContaining('aguardando internet'), findsOneWidget);
  });

  testWidgets('lançar um vale pelo botão grande', (tester) async {
    final a = await abrir(tester);
    await tester.tap(find.text('Lançar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vale'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '12345');
    await tester.pumpAndSettle();
    expect(find.text('123,45'), findsOneWidget);
    await tester.tap(find.text('Salvar vale'));
    await tester.pumpAndSettle();
    expect(find.text('Vale salvo.'), findsOneWidget);
    final vales = await a.registros('vales');
    expect(vales.map((v) => v['valor_centavos']), containsAll([50000, 12345]));
    expect((await a.fila()).where((i) => i.tabela == 'vales').length, 1);
  });

  testWidgets('frete corrigido pelo gestor não pode ser mudado', (tester) async {
    await abrir(tester);
    await tester.tap(find.text('Fretes'));
    await tester.pumpAndSettle();
    expect(find.text('Corrigido pelo gestor'), findsOneWidget);
    await tester.tap(find.text('Rio Verde (GO)').first);
    await tester.pumpAndSettle();
    expect(find.text('O seu patrão corrigiu este lançamento'), findsOneWidget);
    expect(find.byTooltip('Mudar'), findsNothing);
    expect(find.text('Enviar acerto da viagem'), findsOneWidget);
  });

  testWidgets('trocar de caminhão explica que o que foi lançado fica no antigo', (tester) async {
    final a = await abrir(tester);
    await tester.tap(find.text('Trocar').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Frota 12'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Você vai lançar no caminhão DEF-4567'), findsOneWidget);
    expect(find.textContaining('continua no caminhão RVG2C47'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Trocar'));
    await tester.pumpAndSettle();
    final usos = await a.registros('uso_caminhao');
    expect(usos.length, 2);
    expect(find.textContaining('Agora você está no DEF-4567'), findsOneWidget);
  });

  testWidgets('sem conta: tela de boas-vindas e login por CPF confere o número', (tester) async {
    final s = servidorComCadastros()..sessao = false;
    await abrir(tester, a: ArmazenamentoMemoria(), s: s);
    expect(find.text('Entrar com CPF e senha'), findsOneWidget);
    await tester.tap(find.text('Entrar com CPF e senha'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '12345678900');
    await tester.tap(find.text('Entrar').last);
    await tester.pumpAndSettle();
    expect(find.text('Confira o CPF: tem 11 números.'), findsOneWidget);
  });

  testWidgets('novo frete: a conferência mostra a sua parte na hora', (tester) async {
    await abrir(tester);
    await tester.tap(find.text('Fretes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Novo frete'));
    await tester.pumpAndSettle();
    Future<void> preencher(String rotulo, String texto) async {
      final campo = find.widgetWithText(TextField, rotulo);
      await tester.scrollUntilVisible(campo, 200, scrollable: find.byType(Scrollable).last);
      await tester.enterText(campo, texto);
      await tester.pumpAndSettle();
    }

    await preencher('Origem (de onde saiu)', 'Goiatuba');
    await preencher('Destino (para onde vai)', 'Santos');
    await preencher('Peso na carga', '37000');
    await preencher('Valor da tonelada', '18500');
    await preencher('Adiantamento', '480000');
    await preencher('Saldo', '195000');
    await tester.scrollUntilVisible(find.text('Sua parte (13%)'), 300, scrollable: find.byType(Scrollable).last);
    expect(find.text('R\$ 877,50'), findsOneWidget);
  });

  testWidgets('criar conta sem e-mail: nome, CPF e senha, e já pede o código da empresa', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final s = ServidorFalso()
      ..sessao = false
      ..situacaoFixa = {
        'logado': true,
        'perfil': {'id': 'u-novo', 'nome': 'Novo Motorista', 'papel': 'motorista', 'ativo': true},
        'empresa': null,
        'motorista': null,
        'pedido': null,
      };
    await tester.pumpWidget(ProviderScope(
      overrides: [
        armazenamentoProvider.overrideWithValue(ArmazenamentoMemoria()),
        servidorProvider.overrideWithValue(s),
        sincronizarSozinhoProvider.overrideWithValue(false),
      ],
      child: const AplicativoMotorista(),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Criar minha conta'));
    await tester.pumpAndSettle();
    expect(find.text('Criar conta'), findsOneWidget);
    expect(find.textContaining('E-mail'), findsNothing, reason: 'o cadastro não pede e-mail');

    final campos = find.byType(TextField);
    await tester.enterText(campos.at(0), 'Novo Motorista');
    await tester.enterText(campos.at(1), '12345678900');
    await tester.enterText(campos.at(2), 'senha1');
    await tester.tap(find.text('Criar minha conta'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Confira o CPF'), findsOneWidget);

    await tester.enterText(campos.at(1), '52998224725');
    await tester.tap(find.text('Criar minha conta'));
    await tester.pumpAndSettle();
    expect(s.cadastros, ['52998224725']);
    expect(find.text('Código da empresa'), findsOneWidget);
  });
}
