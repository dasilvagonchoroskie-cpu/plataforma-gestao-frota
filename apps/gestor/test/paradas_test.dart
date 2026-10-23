// Registro de paradas no painel: desligado por padrão (nem aparece), só o
// dono liga e muda o limite, maior intervalo sem descanso por motorista com
// destaque acima do limite e o aviso de que não substitui o tacógrafo.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show ByteData;
import 'package:flutter_test/flutter_test.dart';
import 'package:gestor/dados/equipe.dart';
import 'package:gestor/servidor/servidor.dart';
import 'package:nucleo/nucleo.dart';

import 'apoio.dart';

const motivosTeste = <Map<String, Object?>>[
  {'codigo': 'cafe', 'nome': 'Café ou pausa curta', 'conta_como_descanso': false, 'ativo': true, 'ordem': 10},
  {'codigo': 'refeicao', 'nome': 'Refeição', 'conta_como_descanso': true, 'ativo': true, 'ordem': 20},
  {'codigo': 'descanso', 'nome': 'Descanso', 'conta_como_descanso': true, 'ativo': true, 'ordem': 30},
  {'codigo': 'pernoite', 'nome': 'Pernoite', 'conta_como_descanso': true, 'ativo': true, 'ordem': 40},
  {'codigo': 'fiscalizacao', 'nome': 'Fiscalização', 'conta_como_descanso': false, 'ativo': true, 'ordem': 90},
  {'codigo': 'outro', 'nome': 'Outro', 'conta_como_descanso': false, 'ativo': true, 'ordem': 100},
];

/// Empresa da amostra com o catálogo de motivos (existe sempre no banco).
ServidorFalso servidorComMotivos({String usuario = euDono}) {
  final s = servidorComAmostra(usuario: usuario);
  s.t(Fontes.motivosParada).addAll([for (final m in motivosTeste) {...m}]);
  s.empresa['paradas_ativas'] = false;
  s.empresa['limite_sem_descanso_minutos'] = 330;
  return s;
}

/// Paradas ligadas: João passou 7h sem descanso (acima de 5h30); Pedro só tomou café.
ServidorFalso servidorComParadas({String usuario = euDono}) {
  final s = servidorComMotivos(usuario: usuario);
  s.empresa['paradas_ativas'] = true;
  Map<String, Object?> p(String id, String mot, String motivo, DateTime ini, [DateTime? fim, bool ajustado = false]) =>
      Parada(
        id: id,
        empresaId: empresaId,
        motoristaId: mot,
        caminhaoId: cam1,
        motivo: motivo,
        inicioEm: ini,
        fimEm: fim,
        ajustado: ajustado,
      ).paraMapa();
  s.t(Fontes.paradas).addAll([
    p('pa1', joao, 'pernoite', dia(2, hora: 0), dia(2, hora: 5)),
    p('pa2', joao, 'refeicao', dia(2, hora: 12), dia(2, hora: 13)),
    p('pa3', joao, 'cafe', dia(2, hora: 15), dia(2, hora: 16), true),
    p('pa4', joao, 'descanso', dia(2, hora: 17), dia(2, hora: 18)),
    // Pernoite ainda aberto: não há intervalo "até agora" (o teste não depende da hora).
    p('pa5', joao, 'pernoite', dia(2, hora: 22)),
    p('pb1', pedro, 'cafe', dia(3, hora: 9), dia(3, hora: 10)),
  ]);
  return s;
}

Future<void> tocar(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('desligado: nem o menu, nem o motorista, nem o painel mostram paradas', (tester) async {
    final s = servidorComMotivos();
    await abrirApp(tester, s);
    expect(find.text('Paradas'), findsNothing);
    await tester.tap(find.text('Motoristas').first);
    await tester.pumpAndSettle();
    await tocar(tester, find.text('João Batista').first);
    expect(find.widgetWithText(Tab, 'Paradas'), findsNothing);
  });

  testWidgets('o dono liga o registro e muda o limite; o menu ganha Paradas', (tester) async {
    final s = servidorComMotivos();
    await abrirApp(tester, s);
    await tester.tap(find.text('Configurações').first);
    await tester.pumpAndSettle();
    expect(find.text('Desligado (os motoristas não veem a aba).'), findsOneWidget);
    await tocar(tester, find.text('Registro de paradas'));
    expect(find.text('Conta como descanso'), findsNWidgets(3), reason: 'refeição, descanso e pernoite');
    expect(find.text(avisoParadas), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Horas'), findsOneWidget);

    await tocar(tester, find.text('Usar o registro de paradas'));
    await tester.enterText(find.widgetWithText(TextField, 'Horas'), '6');
    await tester.enterText(find.widgetWithText(TextField, 'Minutos'), '15');
    await tester.pumpAndSettle();
    await tocar(tester, find.text('Salvar'));
    expect(s.chamadas, contains('alterar empresas $empresaId paradas_ativas,limite_sem_descanso_minutos'));
    expect(s.empresa['paradas_ativas'], isTrue);
    expect(s.empresa['limite_sem_descanso_minutos'], 375);
    expect(find.text('Ligado. Limite sem descanso: 6h15.'), findsOneWidget);
    expect(find.widgetWithText(NavigationRail, 'Paradas'), findsOneWidget);
  });

  testWidgets('limite fora da faixa não é salvo', (tester) async {
    final s = servidorComMotivos();
    await abrirApp(tester, s);
    await tester.tap(find.text('Configurações').first);
    await tester.pumpAndSettle();
    await tocar(tester, find.text('Registro de paradas'));
    await tester.enterText(find.widgetWithText(TextField, 'Horas'), '0');
    await tester.enterText(find.widgetWithText(TextField, 'Minutos'), '10');
    await tocar(tester, find.text('Salvar'));
    expect(find.text('O limite fica entre 0h30 e 24h00.'), findsOneWidget);
    expect(s.chamadas.where((c) => c.startsWith('alterar empresas')), isEmpty);
  });

  testWidgets('o gestor vê, mas só o dono liga', (tester) async {
    final s = servidorComMotivos(usuario: euGestor);
    await abrirApp(tester, s);
    await tester.tap(find.text('Configurações').first);
    await tester.pumpAndSettle();
    await tocar(tester, find.text('Registro de paradas'));
    final chave = tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'Usar o registro de paradas'));
    expect(chave.onChanged, isNull);
    expect(find.text('Salvar'), findsNothing);
    expect(find.text('Só o dono liga, desliga e muda o limite.'), findsOneWidget);
  });

  testWidgets('aba Paradas: maior intervalo sem descanso e destaque acima do limite', (tester) async {
    final s = servidorComParadas();
    await abrirApp(tester, s);
    // O painel avisa quem passou do limite.
    expect(find.text('Acima do limite: João'), findsOneWidget);
    await tocar(tester, find.text('Acima do limite: João'));
    expect(find.text('João Batista'), findsWidgets);
    expect(find.text('7h00'), findsOneWidget, reason: 'do fim do pernoite (05:00) até a refeição (12:00)');
    expect(find.textContaining('1 vez acima do limite'), findsOneWidget);
    expect(find.textContaining('parado agora: pernoite'), findsOneWidget);
    expect(find.text(avisoParadas), findsOneWidget);

    await tocar(tester, find.text('Pedro Henrique'));
    expect(find.text('Nenhum descanso registrado neste período.'), findsOneWidget);
    tester.state<NavigatorState>(find.byType(Navigator).last).pop();
    await tester.pumpAndSettle();

    await tocar(tester, find.text('João Batista').first);
    expect(find.text('Paradas: João'), findsOneWidget);
    expect(find.text('Maior intervalo sem descanso (acima do limite)'), findsOneWidget);
    expect(find.text('Limite da empresa: 5h30 sem descanso  •  1 vez acima'), findsOneWidget);
    expect(find.text('Refeição'), findsOneWidget);
    expect(find.text('Horário informado depois'), findsOneWidget, reason: 'o café foi ajustado pelo motorista');
    expect(find.text('PDF'), findsOneWidget);
    expect(find.text('Planilha'), findsOneWidget);
  });

  testWidgets('na tela do motorista, a aba Paradas aparece quando a empresa usa', (tester) async {
    final s = servidorComParadas();
    await abrirApp(tester, s);
    await tester.tap(find.text('Motoristas').first);
    await tester.pumpAndSettle();
    await tocar(tester, find.text('João Batista').first);
    await tocar(tester, find.widgetWithText(Tab, 'Paradas'));
    expect(find.text('Maior intervalo sem descanso (acima do limite)'), findsOneWidget);
    expect(find.text('Pernoite'), findsWidgets);
    expect(find.text('parado'), findsOneWidget, reason: 'o pernoite ainda está aberto');
  });

  testWidgets('no celular: Paradas não ocupa aba embaixo; abre pelo cartão do Painel', (tester) async {
    final s = servidorComParadas();
    await abrirApp(tester, s, tela: celular, densidade: 2.75);
    expect(find.widgetWithText(NavigationBar, 'Paradas'), findsNothing);
    await tocar(tester, find.text('Acima do limite: João'));
    expect(find.text('Paradas'), findsWidgets);
    expect(find.text('7h00'), findsOneWidget);
  });

  test('relatório do motorista no período: PDF com o aviso e planilha', () async {
    final s = servidorComParadas();
    final e = Equipe.montar(
      situacao: await s.situacao(),
      tabelas: await s.carregar(),
      pedidos: const [],
      agora: DateTime.now(),
    );
    expect(e.paradas, hasLength(6));
    expect(e.motivosParada, hasLength(6));
    expect(e.configParadas.limiteMinutos, 330);
    final periodo = calcularPeriodo(TipoPeriodo.mesAtual)!;
    final d = e.dadosParadas(joao, periodo, DateTime.now());
    expect(d.motorista, 'João Batista');
    expect(d.empresa, 'Transportes Goiatuba');
    expect(duracaoTexto(d.resumo.maior!.duracao), '7h00');
    expect(d.resumo.paradas.every((p) => p.motoristaId == joao), isTrue, reason: 'só as dele');

    ByteData ler(String n) => ByteData.sublistView(File('../../packages/nucleo/lib/fontes/$n').readAsBytesSync());
    final a = FontesPdf.arquivos;
    final pdf = await gerarPdfParadas(d, FontesPdf.deBytes(ler(a[0]), ler(a[1]), ler(a[2]), ler(a[3])));
    expect(String.fromCharCodes(pdf.sublist(0, 5)), '%PDF-');
    expect(nomeDoArquivoParadas(d), startsWith('Frota_Joao_paradas_'));
    final csv = csvParadas(d);
    expect(csv, contains('Refeição'));
    expect(csv, contains('7h00;sim'), reason: 'sem descanso antes da refeição, acima do limite');
    expect(csv.trim().split('\n').last, '"$avisoParadas"');
  });
}
