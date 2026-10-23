// Registro de paradas no celular: só aparece quando a empresa liga, grava a
// hora do toque sem internet, "Retomar viagem" fecha a parada e o horário
// informado depois fica marcado como ajustado.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motorista/dados/armazenamento.dart';
import 'package:motorista/dados/dados.dart';
import 'package:motorista/dados/sincronizador.dart';
import 'package:nucleo/nucleo.dart';

import 'apoio.dart';
import 'modalidades_test.dart' show abrirApp, celularDe, tocar;

/// Celular com relógio que o teste anda.
class Relogio {
  Relogio(this.agora);
  DateTime agora;
  void andar(Duration d) => agora = agora.add(d);
}

Future<ProviderContainer> celularComRelogio(ServidorFalso s, Relogio r) async {
  final a = ArmazenamentoMemoria();
  await a.gravarEstado('situacao', jsonEncode(s.situacaoAtual()));
  await a.gravarEstado('pronto', '1');
  final c = ProviderContainer(
    overrides: [
      armazenamentoProvider.overrideWithValue(a),
      servidorProvider.overrideWithValue(s),
      relogioProvider.overrideWithValue(() => r.agora),
    ],
  );
  await c.read(dadosProvider.future);
  return c;
}

void main() {
  test('a empresa liga as paradas: o celular recebe o limite e os motivos', () async {
    final s = servidorComCadastros();
    var d = (await c0(s)).read(dadosProvider).requireValue;
    expect(d.paradasAtivas, isFalse, reason: 'desligado por padrão');
    expect(d.info.paradas.motivos, isEmpty);

    s
      ..paradasAtivas = true
      ..limiteSemDescanso = 300;
    final c = await c0(s);
    await c.read(sincronizadorProvider.notifier).sincronizar();
    d = c.read(dadosProvider).requireValue;
    expect(d.paradasAtivas, isTrue);
    expect(d.info.paradas.limiteMinutos, 300);
    expect(d.info.paradas.motivos, hasLength(10));
    expect([for (final m in d.info.paradas.motivos) if (m.contaComoDescanso) m.codigo], ['refeicao', 'descanso', 'pernoite']);
  });

  test('sem internet: registra, retoma e manda tudo depois', () async {
    final s = servidorComCadastros()..paradasAtivas = true;
    final r = Relogio(DateTime(2026, 10, 15, 11, 30));
    final c = await celularComRelogio(s, r);
    final dados = c.read(dadosProvider.notifier);
    await c.read(sincronizadorProvider.notifier).baixar(tudo: true);
    await dados.recarregar();
    await dados.trocarCaminhao(caminhao1);
    s.online = false;

    final refeicao = await dados.registrarParada('refeicao');
    var d = c.read(dadosProvider).requireValue;
    expect(d.paradaEmAndamento?.id, refeicao.id);
    expect(refeicao.inicioEm, DateTime(2026, 10, 15, 11, 30), reason: 'a hora do toque');
    expect(refeicao.ajustado, isFalse);
    expect(refeicao.caminhaoId, caminhao1);

    r.andar(const Duration(minutes: 50));
    await dados.retomarViagem();
    d = c.read(dadosProvider).requireValue;
    expect(d.paradaEmAndamento, isNull);
    expect(d.paradas.single.duracao(r.agora), const Duration(minutes: 50));
    expect(d.fimDoUltimoDescanso!.isAtSameMomentAs(DateTime(2026, 10, 15, 12, 20)), isTrue);
    expect(d.estaPendente(Tabelas.paradas, refeicao.id), isTrue);

    s.online = true;
    await c.read(sincronizadorProvider.notifier).sincronizar();
    expect(c.read(dadosProvider).requireValue.quantidadePendente, 0);
    final naNuvem = s.nuvem['paradas']![refeicao.id]!;
    expect(naNuvem['motivo'], 'refeicao');
    expect(naNuvem['fim_em'], dataIso(DateTime(2026, 10, 15, 12, 20)));
    expect(naNuvem['ajustado'], isFalse);
  });

  test('esqueceu de retomar: informa a hora e a parada fica ajustada', () async {
    final s = servidorComCadastros()..paradasAtivas = true;
    final r = Relogio(DateTime(2026, 10, 15, 8));
    final c = await celularComRelogio(s, r);
    final dados = c.read(dadosProvider.notifier);
    await dados.registrarParada('carga');
    r.andar(const Duration(hours: 3));
    await dados.retomarViagem(fim: DateTime(2026, 10, 15, 9, 15));
    final p = c.read(dadosProvider).requireValue.paradas.single;
    expect(p.fimEm!.isAtSameMomentAs(DateTime(2026, 10, 15, 9, 15)), isTrue);
    expect(p.ajustado, isTrue);
    expect(duracaoTexto(p.duracao(r.agora)), '1h15');

    // Horário antes da parada não fica negativo.
    await dados.registrarParada('descarga');
    await dados.retomarViagem(fim: DateTime(2026, 10, 15, 7));
    final d2 = c.read(dadosProvider).requireValue.paradas.first;
    expect(d2.duracao(r.agora), Duration.zero);
  });

  test('parada nova com outra aberta: a anterior termina onde a nova começa', () async {
    final s = servidorComCadastros()..paradasAtivas = true;
    final r = Relogio(DateTime(2026, 10, 15, 14));
    final c = await celularComRelogio(s, r);
    final dados = c.read(dadosProvider.notifier);
    final abastecimento = await dados.registrarParada('abastecimento');
    r.andar(const Duration(minutes: 20));
    await dados.registrarParada('outro', descricao: 'Esperando a balança');
    final d = c.read(dadosProvider).requireValue;
    expect(d.paradas, hasLength(2));
    final primeira = d.paradas.firstWhere((p) => p.id == abastecimento.id);
    expect(primeira.fimEm!.isAtSameMomentAs(DateTime(2026, 10, 15, 14, 20)), isTrue);
    expect(primeira.ajustado, isFalse);
    expect(d.paradaEmAndamento?.descricao, 'Esperando a balança');

    // Esqueceu de registrar: parou antes e informa a hora.
    r.andar(const Duration(hours: 1));
    final pernoite = await dados.registrarParada('pernoite', inicio: DateTime(2026, 10, 15, 15));
    expect(pernoite.ajustado, isTrue);
    final balanca = c.read(dadosProvider).requireValue.paradas.firstWhere((p) => p.motivo == 'outro');
    expect(balanca.fimEm!.isAtSameMomentAs(DateTime(2026, 10, 15, 15)), isTrue);
    expect(balanca.ajustado, isTrue, reason: 'o fim também foi informado depois');
  });

  test('corrigir e apagar: horário mudado fica marcado', () async {
    final s = servidorComCadastros()..paradasAtivas = true;
    final r = Relogio(DateTime(2026, 10, 15, 10));
    final c = await celularComRelogio(s, r);
    final dados = c.read(dadosProvider.notifier);
    final p = await dados.registrarParada('cafe');
    r.andar(const Duration(minutes: 10));
    await dados.retomarViagem();
    var atual = c.read(dadosProvider).requireValue.paradas.single;

    await dados.corrigirParada(atual.copyWith(motivo: 'fiscalizacao'), mudouHorario: false);
    atual = c.read(dadosProvider).requireValue.paradas.single;
    expect(atual.motivo, 'fiscalizacao');
    expect(atual.ajustado, isFalse, reason: 'só o motivo mudou');

    await dados.corrigirParada(atual.copyWith(fimEm: DateTime(2026, 10, 15, 10, 40)), mudouHorario: true);
    atual = c.read(dadosProvider).requireValue.paradas.single;
    expect(atual.ajustado, isTrue);

    await dados.apagarParada(atual);
    expect(c.read(dadosProvider).requireValue.paradas, isEmpty);
    await c.read(sincronizadorProvider.notifier).sincronizar();
    expect(s.nuvem['paradas']![p.id]!['apagado_em'], isNotNull, reason: 'o patrão vê que foi apagada');
  });

  testWidgets('desligado: a aba Paradas nem aparece', (tester) async {
    final s = servidorComCadastros();
    final a = await celularDe(s);
    await abrirApp(tester, a, s);
    expect(find.text('Paradas'), findsNothing);
    expect(find.text('Vales'), findsWidgets);
  });

  testWidgets('ligado: registrar parada, ver no Início e retomar a viagem', (tester) async {
    final s = servidorComCadastros()..paradasAtivas = true;
    final a = await celularDe(s);
    await abrirApp(tester, a, s);
    expect(find.text('Registrar parada e retomar viagem'), findsOneWidget, reason: 'o botão Paradas no Início');
    await tocar(tester, find.text('Paradas'));
    expect(find.text('Nenhuma parada registrada'), findsOneWidget);
    expect(find.text('Rodando'), findsOneWidget);

    await tocar(tester, find.text('Registrar parada'));
    expect(find.text('Por que você parou?'), findsOneWidget);
    expect(find.text('Fiscalização'), findsOneWidget);
    await tocar(tester, find.text('Refeição'));
    expect(find.textContaining('Parada registrada: Refeição'), findsOneWidget);
    expect(find.text('Parado: Refeição'), findsOneWidget);
    expect(find.text('Retomar viagem'), findsWidgets);
    expect(find.text('Não enviado'), findsOneWidget, reason: 'sem internet fica no celular');

    // No Início também dá para retomar.
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();
    expect(find.text('Parado: Refeição'), findsOneWidget);
    expect(find.text('parado'), findsOneWidget, reason: 'o botão Paradas mostra que está parado');
    await tocar(tester, find.widgetWithText(FilledButton, 'Retomar viagem'));
    expect(find.textContaining('Boa viagem! A parada durou'), findsOneWidget);
    expect(find.text('Parado: Refeição'), findsNothing);

    await tocar(tester, find.text('Paradas'));
    expect(find.text('Hoje'), findsOneWidget);
    expect(find.text('Refeição'), findsOneWidget);
    expect(find.text('Descanso'), findsOneWidget, reason: 'refeição conta como descanso');
    expect(find.textContaining('Sem descanso há'), findsOneWidget);
  });

  testWidgets('motivo Outro pede a descrição; abrir a parada mostra os horários', (tester) async {
    final s = servidorComCadastros()..paradasAtivas = true;
    final a = await celularDe(s);
    await abrirApp(tester, a, s);
    await tocar(tester, find.text('Paradas'));
    await tocar(tester, find.text('Registrar parada'));
    await tocar(tester, find.text('Outro'));
    expect(find.text('Qual foi o motivo?'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Esperando a balança');
    await tocar(tester, find.text('Registrar'));
    expect(find.text('Parado: Outro'), findsOneWidget);
    expect(find.text('Esperando a balança'), findsWidgets);

    await tocar(tester, find.widgetWithText(OutlinedButton, 'Esqueci de retomar'));
    expect(find.text('Que horas você saiu?'), findsOneWidget);
    await tocar(tester, find.text('Pronto'));
    await tocar(tester, find.text('Pronto'));
    expect(find.textContaining('Boa viagem!'), findsOneWidget);
    expect(find.text('Horário informado depois'), findsOneWidget);

    await tocar(tester, find.text('Esperando a balança'));
    expect(find.text('Parou em'), findsOneWidget);
    expect(find.text('Saiu em'), findsOneWidget);
    expect(find.textContaining('foi informado depois'), findsOneWidget);
  });
}

Future<ProviderContainer> c0(ServidorFalso s) => celular(s);
