@Tags(['capturas'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestor/telas/lancamentos/detalhe_lancamento.dart';

import 'apoio.dart';
import 'paradas_test.dart' show servidorComParadas;

/// Imagens das telas no computador (1440 x 900) e no celular (1078 x 2337)
/// para conferir o visual. Roda com: flutter test --tags capturas --update-goldens
void main() {
  setUpAll(carregarFontes);

  Future<void> foto(WidgetTester tester, String nome) async {
    await tester.pumpAndSettle();
    try {
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('capturas/$nome.png'));
    } finally {
      debugDisableShadows = true;
    }
  }

  Future<ServidorFalso> abrir(WidgetTester tester, {bool noCelular = false, String usuario = euDono}) async {
    debugDisableShadows = false;
    final s = servidorComAmostra(usuario: usuario);
    // Uma correção já feita, para aparecer nas telas.
    await s.inserir('ajustes_gestor', {
      'id': 'aj1',
      'empresa_id': empresaId,
      'tabela_alvo': 'fretes',
      'registro_id': 'f2',
      'campo': 'saldo_centavos',
      'valor_novo': 150000,
      'motivo': 'Conferido no extrato',
      'autor_id': euDono,
    });
    await abrirApp(tester, s, tela: noCelular ? celular : const Size(1440, 900), densidade: noCelular ? 2.75 : 1);
    return s;
  }

  Future<void> ir(WidgetTester tester, String parte) async {
    await tester.tap(find.text(parte).first);
    await tester.pumpAndSettle();
  }

  testWidgets('01 painel computador', (t) async {
    await abrir(t);
    await foto(t, '01_painel_computador');
  });

  testWidgets('02 painel celular', (t) async {
    await abrir(t, noCelular: true);
    await foto(t, '02_painel_celular');
  });

  testWidgets('03 motoristas', (t) async {
    await abrir(t);
    await ir(t, 'Motoristas');
    await foto(t, '03_motoristas');
  });

  testWidgets('04 como o motorista ve', (t) async {
    await abrir(t, noCelular: true);
    await ir(t, 'Motoristas');
    await ir(t, 'João Batista');
    await foto(t, '04_como_o_motorista_ve');
  });

  testWidgets('05 caminhoes', (t) async {
    await abrir(t);
    await ir(t, 'Caminhões');
    await foto(t, '05_caminhoes');
  });

  testWidgets('06 detalhe caminhao', (t) async {
    await abrir(t);
    await ir(t, 'Caminhões');
    await ir(t, 'Frota 07  ·  Scania R450');
    await foto(t, '06_caminhao');
  });

  testWidgets('07 lancamentos', (t) async {
    await abrir(t);
    await ir(t, 'Lançamentos');
    await foto(t, '07_lancamentos');
  });

  testWidgets('08 frete corrigido', (t) async {
    await abrir(t, noCelular: true);
    await ir(t, 'Lançamentos');
    await ir(t, 'Paranaguá (PR)  –  Rio Verde (GO)');
    expect(find.byType(TelaDetalheLancamento), findsOneWidget);
    await foto(t, '08_frete_corrigido');
  });

  testWidgets('09 relatorios', (t) async {
    await abrir(t);
    await ir(t, 'Relatórios');
    await foto(t, '09_relatorios');
  });

  testWidgets('10 configuracoes', (t) async {
    await abrir(t, noCelular: true);
    await t.tap(find.byTooltip('Configurações'));
    await t.pumpAndSettle();
    await foto(t, '10_configuracoes');
  });

  testWidgets('11 entrar', (t) async {
    debugDisableShadows = false;
    await abrirApp(t, servidorComAmostra()..sessao = false, tela: const Size(1440, 900));
    await foto(t, '11_entrar');
  });

  testWidgets('13 paradas', (t) async {
    debugDisableShadows = false;
    await abrirApp(t, servidorComParadas(), tela: const Size(1440, 900));
    await ir(t, 'Paradas');
    await ir(t, 'João Batista');
    await foto(t, '13_paradas_motorista');
  });

  testWidgets('14 paradas configuracao', (t) async {
    debugDisableShadows = false;
    await abrirApp(t, servidorComParadas(), tela: celular, densidade: 2.75);
    await t.tap(find.byTooltip('Configurações'));
    await t.pumpAndSettle();
    await ir(t, 'Registro de paradas');
    await foto(t, '14_paradas_configuracao');
  });

  testWidgets('12 painel escuro', (t) async {
    t.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(t.platformDispatcher.clearPlatformBrightnessTestValue);
    await abrir(t);
    await foto(t, '12_painel_escuro');
  });
}
