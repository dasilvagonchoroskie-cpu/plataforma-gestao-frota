@Tags(['capturas'])
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motorista/app.dart';
import 'package:motorista/dados/armazenamento.dart';
import 'package:motorista/dados/dados.dart';
import 'package:motorista/telas/acesso/telas_acesso.dart';
import 'package:motorista/telas/caminhao/tela_caminhao.dart';
import 'package:motorista/telas/casca.dart';
import 'package:motorista/telas/fretes/detalhe_frete.dart';
import 'package:motorista/telas/fretes/form_frete.dart';
import 'package:nucleo/nucleo.dart';
import 'package:visual/visual.dart';

import 'amostra.dart';
import 'apoio.dart';

/// Imagens das telas (1080 x 2340) para conferir o visual.
/// Roda com: flutter test --tags capturas --update-goldens
void main() {
  setUpAll(carregarFontes);

  Future<void> capturar(
    WidgetTester tester,
    String nome,
    Widget tela, {
    bool escuro = false,
    Future<void> Function(ArmazenamentoMemoria a)? preparar,
    DateTime? agora,
  }) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final a = await celularComAmostra();
    final s = servidorComCadastros()..online = false;
    if (preparar != null) await preparar(a);
    debugDisableShadows = false;
    try {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          armazenamentoProvider.overrideWithValue(a),
          servidorProvider.overrideWithValue(s),
          sincronizarSozinhoProvider.overrideWithValue(false),
          if (agora != null) relogioProvider.overrideWithValue(() => agora),
        ],
        child: Theme(
          data: escuro ? temaEscuro : temaClaro,
          child: AplicativoMotorista(inicio: _Espera(child: tela)),
        ),
      ));
      await tester.pumpAndSettle();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('capturas/$nome.png'));
    } finally {
      debugDisableShadows = true;
    }
  }

  testWidgets('01 resumo', (t) => capturar(t, '01_resumo', const Casca()));
  testWidgets('02 fretes', (t) => capturar(t, '02_fretes', const Casca(abaInicial: 1)));
  testWidgets('03 detalhe', (t) => capturar(t, '03_frete_detalhe', const DetalheFrete(idFrete: 'f1')));
  testWidgets('04 formulario', (t) => capturar(t, '04_frete_novo', const FormFrete()));
  testWidgets('05 diesel', (t) => capturar(t, '05_diesel', const Casca(abaInicial: 2)));
  testWidgets('06 gastos', (t) => capturar(t, '06_gastos', const Casca(abaInicial: 3)));
  testWidgets('07 trocar caminhao', (t) => capturar(t, '07_trocar_caminhao', const TelaTrocarCaminhao()));
  testWidgets('08 boas vindas', (t) => capturar(t, '08_boas_vindas', const TelaBoasVindas()));
  testWidgets('09 entrar', (t) => capturar(t, '09_entrar', const TelaEntrar()));
  testWidgets('10 aguardando', (t) => capturar(t, '10_aguardando', const TelaAguardando(empresaNome: 'Transportes Goiatuba')));
  testWidgets('11 frete ajustado', (t) => capturar(t, '11_frete_ajustado', const DetalheFrete(idFrete: 'f2')));
  testWidgets(
    '12 paradas',
    (t) => capturar(t, '12_paradas', const Casca(abaInicial: 5), preparar: comParadas, agora: hojeAs(14, 10)),
  );
}

DateTime hojeAs(int hora, int minuto, {int diasAtras = 0}) {
  final h = DateTime.now();
  return DateTime(h.year, h.month, h.day - diasAtras, hora, minuto);
}

/// Empresa com o registro de paradas ligado e um dia de paradas.
Future<void> comParadas(ArmazenamentoMemoria a) async {
  final s = servidorComCadastros()..paradasAtivas = true;
  final situacao = s.situacaoAtual();
  (situacao['motorista'] as Map)['nome'] = 'João Batista';
  await a.gravarEstado('situacao', jsonEncode(situacao));
  Parada p(String id, String motivo, DateTime ini, [DateTime? fim, bool ajustado = false]) =>
      Parada(id: id, motoristaId: motoristaA, caminhaoId: caminhao1, motivo: motivo, inicioEm: ini, fimEm: fim, ajustado: ajustado);
  await a.gravarRegistros('paradas', [
    p('pa1', 'pernoite', hojeAs(22, 0, diasAtras: 1), hojeAs(5, 30)).paraMapa(),
    p('pa2', 'cafe', hojeAs(7, 40), hojeAs(7, 55)).paraMapa(),
    p('pa3', 'abastecimento', hojeAs(9, 10), hojeAs(9, 35), true).paraMapa(),
    p('pa4', 'fiscalizacao', hojeAs(11, 50), hojeAs(12, 5)).paraMapa(),
    p('pa5', 'refeicao', hojeAs(13, 30)).paraMapa(),
  ]);
}

/// Espera os dados do celular carregarem antes de mostrar a tela.
class _Espera extends ConsumerWidget {
  const _Espera({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(dadosProvider).hasValue ? child : const SizedBox.shrink();
}
