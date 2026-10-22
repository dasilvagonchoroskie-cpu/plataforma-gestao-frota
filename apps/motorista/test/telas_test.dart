import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motorista/app.dart';
import 'package:motorista/dados/armazenamento.dart';
import 'package:motorista/dados/dados.dart';
import 'package:motorista/telas/casca.dart';
import 'package:visual/visual.dart';

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
    await tester.enterText(campos.at(2), 'senha123');
    await tester.tap(find.text('Criar minha conta'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Confira o CPF'), findsOneWidget);

    await tester.enterText(campos.at(1), '52998224725');
    await tester.tap(find.text('Criar minha conta'));
    await tester.pumpAndSettle();
    expect(s.cadastros, isEmpty, reason: 'sem marcar o aceite dos termos não cria a conta');
    expect(find.textContaining('marque que leu e aceita'), findsOneWidget);

    await tester.tap(find.text('Li e aceito os Termos de Uso e a Política de Privacidade.'));
    await tester.tap(find.text('Criar minha conta'));
    await tester.pumpAndSettle();
    expect(s.cadastros, ['52998224725']);
    expect(s.termosAceitos, versaoTermos);
    expect(find.text('Código de entrada'), findsOneWidget);
  });

  Future<ServidorFalso> abrirSemDados(WidgetTester tester, Map<String, Object?> situacao) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final s = ServidorFalso()..situacaoFixa = situacao;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        armazenamentoProvider.overrideWithValue(ArmazenamentoMemoria()),
        servidorProvider.overrideWithValue(s),
        sincronizarSozinhoProvider.overrideWithValue(false),
      ],
      child: const AplicativoMotorista(),
    ));
    await tester.pumpAndSettle();
    return s;
  }

  Map<String, Object?> semEmpresa({bool termos = true, bool recuperacao = true}) => {
        'logado': true,
        'perfil': {'id': 'u-novo', 'nome': 'Novo Motorista', 'papel': 'motorista', 'ativo': true},
        'empresa': null,
        'motorista': null,
        'pedido': null,
        'termos': {'versao': versaoTermos, 'aceito': termos},
        'recuperacao': recuperacao,
      };

  testWidgets('primeiro acesso: aceitar os termos e guardar o código de recuperação', (tester) async {
    final s = await abrirSemDados(tester, semEmpresa(termos: false, recuperacao: false));
    expect(find.text('Termos de Uso e Privacidade'), findsOneWidget);
    await tester.tap(find.text('Aceitar e continuar'));
    await tester.pumpAndSettle();
    expect(s.termosAceitos, isNull, reason: 'precisa marcar que leu');
    await tester.tap(find.text('Li e aceito os Termos de Uso e a Política de Privacidade.'));
    await tester.tap(find.text('Aceitar e continuar'));
    await tester.pumpAndSettle();
    expect(s.termosAceitos, versaoTermos);

    expect(find.text('Código de recuperação'), findsOneWidget);
    await tester.tap(find.text('Gerar o meu código'));
    await tester.pumpAndSettle();
    expect(find.text('ABCD-EFGH-JK11'), findsOneWidget);
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Código de recuperação'), findsOneWidget, reason: 'precisa marcar que anotou');
    await tester.tap(find.text('Já anotei o código em lugar seguro.'));
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Código de entrada'), findsOneWidget);
  });

  testWidgets('os termos abrem para ler', (tester) async {
    await abrirSemDados(tester, semEmpresa(termos: false));
    await tester.tap(find.text('Política de Privacidade'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Lei Geral de Proteção de Dados Pessoais'), findsWidgets);
  });

  testWidgets('esqueci a senha: CPF, código de recuperação e senha nova', (tester) async {
    final s = await abrirSemDados(tester, semEmpresa());
    s.sessao = false;
    await tester.tap(find.text('Sair desta conta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Esqueci a senha'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tenho o código de recuperação'));
    await tester.pumpAndSettle();
    final campos = find.byType(TextField);
    await tester.enterText(campos.at(0), '52998224725');
    await tester.enterText(campos.at(1), 'abcd efgh jk22');
    await tester.enterText(campos.at(2), 'nova1234');
    await tester.pumpAndSettle();
    expect(find.text('ABCD-EFGH-JK22'), findsOneWidget, reason: 'o código entra formatado');
    await tester.tap(find.text('Criar a senha nova'));
    await tester.pumpAndSettle();
    expect(s.recuperacoes, ['52998224725:nova1234']);
    expect(find.text('NOVO-CODI-GO23'), findsOneWidget, reason: 'mostra o código novo');
    await tester.tap(find.text('Já anotei o código em lugar seguro.'));
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(s.sessao, isTrue);
    expect(find.text('Código de entrada'), findsOneWidget);
  });

  testWidgets('empresa com o acesso encerrado: o app fecha e mostra o motivo', (tester) async {
    final armazenamento = await celularComAmostra();
    final situacao = situacaoDe(motoristaA);
    await armazenamento.gravarEstado('situacao', jsonEncode({
      ...situacao,
      'empresa': {...situacao['empresa']! as Map, 'bloqueada': true, 'motivo_bloqueio': 'O período de teste terminou.'},
    }));
    final s = servidorComCadastros()
      ..situacaoFixa = {
        ...situacao,
        'empresa': {...situacao['empresa']! as Map, 'bloqueada': true, 'motivo_bloqueio': 'O período de teste terminou.'},
      };
    await abrir(tester, a: armazenamento, s: s);
    expect(find.text('Acesso encerrado'), findsOneWidget);
    expect(find.text('Motivo: O período de teste terminou.'), findsOneWidget);
    expect(find.text('Você tem para receber'), findsNothing);
  });

  testWidgets('excluir a minha conta pede para digitar EXCLUIR', (tester) async {
    final s = await abrirSemDados(tester, semEmpresa());
    await tester.tap(find.text('Excluir minha conta'));
    await tester.pumpAndSettle();
    final botao = find.widgetWithText(FilledButton, 'Excluir a conta');
    expect(tester.widget<FilledButton>(botao).onPressed, isNull);
    await tester.enterText(find.byType(TextField).last, 'excluir');
    await tester.pumpAndSettle();
    await tester.tap(botao);
    await tester.pumpAndSettle();
    expect(s.contaExcluida, isTrue);
    expect(find.text('Entrar com CPF e senha'), findsOneWidget);
  });
}
