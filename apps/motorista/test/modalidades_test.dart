import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motorista/acesso/acesso.dart' show chaveTermosAparelho;
import 'package:motorista/app.dart';
import 'package:motorista/dados/armazenamento.dart';
import 'package:motorista/dados/dados.dart';
import 'package:motorista/dados/sincronizador.dart';
import 'package:motorista/telas/casca.dart';
import 'package:nucleo/nucleo.dart';
import 'package:visual/visual.dart';

import 'amostra.dart';
import 'apoio.dart';

/// Celular de um motorista com a situação que o servidor mandou (modalidades).
Future<ArmazenamentoMemoria> celularDe(ServidorFalso s, {bool comAmostra = false, bool comCavalo = true}) async {
  final a = comAmostra ? await celularComAmostra() : ArmazenamentoMemoria();
  await a.gravarEstado(chaveTermosAparelho, versaoTermos);
  await a.gravarEstado('situacao', jsonEncode(s.situacaoAtual()));
  await a.gravarEstado('pronto', '1');
  if (!comAmostra) {
    await a.gravarRegistros('caminhoes', [
      const Caminhao(id: caminhao1, placa: 'RVG2C47', numeroFrota: '07').paraMapa(),
      const Caminhao(id: caminhao2, placa: 'DEF4567', numeroFrota: '12').paraMapa(),
    ]);
    if (comCavalo) {
      await a.gravarRegistros('uso_caminhao', [
        UsoCaminhao(
          id: 'uso-1',
          motoristaId: motoristaA,
          caminhaoId: caminhao1,
          inicioEm: dia(1, mesesAtras: 1),
        ).paraMapa(),
      ]);
    }
  }
  return a;
}

Future<void> abrirApp(WidgetTester tester, ArmazenamentoMemoria a, ServidorFalso s, {bool online = false}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  s.online = online;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        armazenamentoProvider.overrideWithValue(a),
        servidorProvider.overrideWithValue(s),
        sincronizarSozinhoProvider.overrideWithValue(false),
      ],
      child: const AplicativoMotorista(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> preencher(WidgetTester tester, String rotulo, String texto) async {
  final campo = find.widgetWithText(TextField, rotulo);
  await tester.scrollUntilVisible(campo, 200, scrollable: find.byType(Scrollable).last);
  await tester.enterText(campo, texto);
  await tester.pumpAndSettle();
}

Future<void> tocar(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('empresa com duas modalidades: o motorista escolhe a dele uma vez', (tester) async {
    final s = servidorComCadastros()
      ..modalidades = [graneleiroTeste, bauTeste]
      ..modalidadeDoMotorista = null;
    final a = await celularDe(s);
    await abrirApp(tester, a, s);
    expect(find.text('Como você trabalha?'), findsOneWidget);
    expect(find.textContaining('Por viagem'), findsOneWidget);

    await tester.tap(find.text('Baú'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();
    expect(find.text('Não deu certo'), findsOneWidget, reason: 'sem internet não dá para escolher');

    s.online = true;
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();
    expect(s.modalidadesEscolhidas, ['bau']);
    expect(find.text('Viagens'), findsWidgets);
    expect(find.text('Fretes'), findsNothing);
  });

  testWidgets('empresa só com Graneleiro: nada muda para o motorista', (tester) async {
    final s = servidorComCadastros()
      ..modalidades = [graneleiroTeste]
      ..modalidadeDoMotorista = null;
    await abrirApp(tester, await celularDe(s, comAmostra: true), s);
    expect(find.text('Como você trabalha?'), findsNothing);
    expect(find.text('Fretes'), findsOneWidget);
    expect(find.text('Você tem para receber'), findsOneWidget);
  });

  testWidgets('Baú: engata e desengata a carreta, e o cavalo é fixo', (tester) async {
    final s = servidorBau();
    final a = await celularDe(s);
    await abrirApp(tester, a, s);
    expect(find.text('Seu cavalo'), findsOneWidget);
    expect(find.text('Trocar'), findsNothing, reason: 'no Baú só o patrão troca o cavalo');
    expect(find.text('Fretes'), findsNothing);

    await tester.tap(find.widgetWithText(NavigationDestination, 'Viagens'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Engatar carreta'));
    await tester.pumpAndSettle();
    await preencher(tester, 'Placa da carreta', 'XY12');
    await preencher(tester, 'Onde engatou', 'Cajamar SP');
    await tocar(tester, find.text('Engatar'));
    expect(find.text('Placa errada. Exemplos: ABC1D23 ou ABC-1234.'), findsOneWidget);
    await preencher(tester, 'Placa da carreta', 'abc1d23');
    await tocar(tester, find.text('Engatar'));
    expect(find.text('Carreta ABC1D23 engatada.'), findsOneWidget);
    expect(find.text('Em andamento'), findsOneWidget);
    expect(find.text('Carreta engatada'), findsOneWidget);

    var viagens = await a.registros('viagens');
    expect(viagens.single['placa_carreta'], 'ABC1D23');
    expect(viagens.single['caminhao_id'], caminhao1);
    expect(viagens.single['modalidade'], 'bau');
    expect(viagens.single.containsKey('desengate_em'), isFalse);
    expect((await a.fila()).where((i) => i.tabela == 'viagens'), hasLength(1));

    // Engatar outra antes de desengatar: o app manda desengatar primeiro.
    await tester.tap(find.text('Desengatar').first);
    await tester.pumpAndSettle();
    expect(find.text('Desengatar carreta'), findsOneWidget);
    await preencher(tester, 'Até onde levou', 'Ribeirão Preto SP');
    await preencher(tester, 'Cidades das entregas', 'Campinas');
    await tocar(tester, find.text('Pôr'));
    await preencher(tester, 'Cidades das entregas', 'Limeira');
    await tocar(tester, find.text('Pôr'));
    expect(find.text('Campinas'), findsOneWidget);
    await tocar(tester, find.text('Desengatar e fechar a viagem'));
    expect(find.text('Viagem fechada.'), findsOneWidget);

    viagens = await a.registros('viagens');
    expect(viagens.single['desengate_local'], 'Ribeirão Preto SP');
    expect(viagens.single['entregas_cidades'], ['Campinas', 'Limeira']);
    expect(viagens.single['entregas_quantidade'], 2, reason: 'sem número digitado, conta uma entrega por cidade');
    expect(viagens.single['desengate_em'], isNotNull);
    expect(find.text('Engatar carreta'), findsOneWidget, reason: 'sem carreta engatada, o botão volta a ser engatar');
  });

  testWidgets('Baú: o resumo mostra viagens e o acerto fechado pelo patrão', (tester) async {
    final s = servidorBau();
    final a = await celularDe(s);
    final hoje = DateTime.now();
    await a.gravarRegistros('viagens', [
      Viagem(
        id: 'v1',
        motoristaId: motoristaA,
        caminhaoId: caminhao1,
        placaCarreta: 'ABC1D23',
        engateLocal: 'Cajamar SP',
        engateEm: dia(2),
        desengateLocal: 'Ribeirão Preto SP',
        desengateEm: dia(3),
        entregasQuantidade: 3,
        entregasCidades: const ['Campinas', 'Limeira', 'Araras'],
      ).paraMapa(),
    ]);
    await a.gravarRegistros('vales', [
      Vale(id: 'x', motoristaId: motoristaA, data: dia(2), valorCentavos: 20000).paraMapa(),
    ]);
    await a.gravarRegistros('acertos', [
      Acerto(
        id: 'ac1',
        motoristaId: motoristaA,
        periodoInicio: DateTime(hoje.year, hoje.month, 1),
        periodoFim: DateTime(hoje.year, hoje.month, 15),
        comissaoCentavos: 150000,
        descontos: const [DescontoAcerto(descricao: 'Multa de trânsito', valorCentavos: 10000)],
        totalDescontosCentavos: 10000,
        valesCentavos: 20000,
        paraReceberCentavos: 120000,
        quantidadeViagens: 1,
        fechadoEm: hoje,
      ).paraMapa(),
    ]);
    await abrirApp(tester, a, s);
    expect(find.text('Entregas'), findsOneWidget);
    expect(find.text('Acertos fechados'), findsOneWidget);
    await tocar(tester, find.text('R\$ 1.200,00'));
    expect(find.text('Você tem para receber'), findsOneWidget);
    expect(find.text('Multa de trânsito'), findsOneWidget);
    expect(find.text('Enviar PDF do acerto'), findsOneWidget);
    expect(find.text('Viagens do período (1)'), findsOneWidget);
  });

  testWidgets('frete com os campos que o dono ajustou e um campo novo da Plataforma', (tester) async {
    final s = servidorComCadastros()
      ..modalidades = [
        modalidadeTeste(
          'graneleiro',
          'Graneleiro',
          'frete',
          campos: [
            {'chave': 'embarcador', 'rotulo': 'Embarcador ou cliente', 'tipo': 'texto', 'visivel': false},
            {
              'chave': 'adiantamento_centavos',
              'rotulo': 'Adiantamento (carta frete)',
              'tipo': 'dinheiro',
              'visivel': true,
            },
            {
              'chave': 'ticket',
              'rotulo': 'Número do ticket',
              'tipo': 'texto',
              'visivel': true,
              'obrigatorio': true,
              'extra': true,
            },
          ],
        ),
      ]
      ..modalidadeDoMotorista = 'graneleiro';
    final a = await celularDe(s, comAmostra: true);
    await abrirApp(tester, a, s);
    await tester.tap(find.text('Fretes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Novo frete'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Embarcador ou cliente'), findsNothing, reason: 'o dono escondeu');
    expect(find.widgetWithText(TextField, 'Adiantamento (carta frete)'), findsOneWidget, reason: 'o dono renomeou');

    await preencher(tester, 'Origem (de onde saiu)', 'Goiatuba');
    await preencher(tester, 'Destino (para onde vai)', 'Santos');
    await tocar(tester, find.text('Salvar frete'));
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(find.text('Preencha número do ticket.'), findsOneWidget, reason: 'o campo novo da Plataforma é obrigatório');
    await tester.enterText(find.widgetWithText(TextField, 'Número do ticket'), '778');
    await tester.pumpAndSettle();
    await tocar(tester, find.text('Salvar frete'));
    expect(find.text('Frete salvo.'), findsOneWidget);
    final novo = (await a.registros('fretes')).firstWhere((f) => f['origem'] == 'Goiatuba');
    expect(novo['extras'], {'ticket': '778'});
    expect(novo['modalidade'], 'graneleiro');
  });

  test('viagem feita sem internet vai para a nuvem e o acerto do patrão chega no celular', () async {
    final s = servidorBau();
    final c = await celular(s);
    final dados = c.read(dadosProvider.notifier);
    await dados.trocarCaminhao(caminhao1);
    final v = dados.novaViagem().copyWith(placaCarreta: 'ABC1D23', engateLocal: 'Cajamar SP');
    s.online = false;
    await dados.salvarViagem(v);
    await c.read(sincronizadorProvider.notifier).sincronizar();
    expect(s.nuvem['viagens'], isNull, reason: 'sem internet fica no celular');

    s.online = true;
    await c.read(sincronizadorProvider.notifier).sincronizar();
    expect(s.nuvem['viagens']![v.id]!['placa_carreta'], 'ABC1D23');
    expect(c.read(dadosProvider).requireValue.quantidadePendente, 0);

    s.colocar('acertos', {
      'id': 'ac1',
      'motorista_id': motoristaA,
      'periodo_inicio': '2026-10-01',
      'periodo_fim': '2026-10-15',
      'comissao_centavos': 150000,
      'para_receber_centavos': 130000,
      'quantidade_viagens': 1,
    });
    s.relogio = s.relogio.add(const Duration(minutes: 10));
    await c.read(sincronizadorProvider.notifier).sincronizar();
    final d = c.read(dadosProvider).requireValue;
    expect(d.acertos.single.paraReceberCentavos, 130000);
    expect(d.porViagem, isTrue);
    expect(d.viagens.single.emAndamento, isTrue);
  });
}
