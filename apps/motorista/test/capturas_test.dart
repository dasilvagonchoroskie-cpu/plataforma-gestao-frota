@Tags(['capturas'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
import 'package:visual/visual.dart';

import 'amostra.dart';
import 'apoio.dart';

/// Imagens das telas (1080 x 2340) para conferir o visual.
/// Roda com: flutter test --tags capturas --update-goldens
void main() {
  setUpAll(carregarFontes);

  Future<void> capturar(WidgetTester tester, String nome, Widget tela, {bool escuro = false}) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final a = await celularComAmostra();
    final s = servidorComCadastros()..online = false;
    debugDisableShadows = false;
    try {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          armazenamentoProvider.overrideWithValue(a),
          servidorProvider.overrideWithValue(s),
          sincronizarSozinhoProvider.overrideWithValue(false),
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
}

/// Espera os dados do celular carregarem antes de mostrar a tela.
class _Espera extends ConsumerWidget {
  const _Espera({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(dadosProvider).hasValue ? child : const SizedBox.shrink();
}
