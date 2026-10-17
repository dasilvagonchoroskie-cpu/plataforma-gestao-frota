import 'package:flutter_test/flutter_test.dart';
import 'package:gestor/dados/equipe.dart';
import 'package:nucleo/nucleo.dart';

import 'apoio.dart';

Future<Equipe> equipeDe(ServidorFalso s) async => Equipe.montar(
  situacao: await s.situacao(),
  tabelas: await s.carregar(),
  pedidos: await s.pedidosEntrada(),
  agora: DateTime.now(),
);

void main() {
  final mes = calcularPeriodo(TipoPeriodo.mesAtual)!;

  test('a conta da frota é a soma das contas de cada motorista', () async {
    final e = await equipeDe(servidorComAmostra());
    final frota = e.relatorio(mes).resultado;
    final porMotorista = [for (final m in e.motoristas) e.relatorio(mes, motoristaId: m.id).resultado];
    double soma(double Function(ResultadoResumo) f) => porMotorista.fold(0, (s, r) => s + f(r));
    expect(frota.totalFretes, soma((r) => r.totalFretes));
    expect(frota.totalAbastecimento, soma((r) => r.totalAbastecimento));
    expect(frota.totalGastos, soma((r) => r.totalGastos));
    expect(frota.comissaoDoCaminhao, closeTo(soma((r) => r.comissaoDoCaminhao), 0.001));
    expect(frota.liquido, closeTo(soma((r) => r.liquido), 0.001));
    expect(frota.totalFretes, 540000 + 225000 + 380000 + 500000 + 205000);
  });

  test('a conta por caminhão também fecha com a frota (vale fica de fora)', () async {
    final e = await equipeDe(servidorComAmostra());
    final frota = e.relatorio(mes).resultado;
    final porCaminhao = [for (final c in e.caminhoes) e.relatorio(mes, caminhaoId: c.id).resultado];
    expect(porCaminhao.fold<double>(0, (s, r) => s + r.totalFretes), frota.totalFretes);
    expect(porCaminhao.fold<double>(0, (s, r) => s + r.sobraDoCaminhao), closeTo(frota.sobraDoCaminhao, 0.001));
    expect(porCaminhao.every((r) => r.totalVale == 0), isTrue);
    expect(frota.totalVale, 50000);
  });

  test('o resumo do motorista no painel é o mesmo do app dele', () async {
    final e = await equipeDe(servidorComAmostra());
    final d = e.relatorio(mes, motoristaId: joao);
    final f1 = e.fretes.firstWhere((f) => f.id == 'f1');
    final f2 = e.fretes.firstWhere((f) => f.id == 'f2');
    final esperado = calcularResumo(
      fretes: [f1, f2],
      abastecimentos: [228000, 219300],
      gastos: [8000],
      vales: [50000],
      regras: const Regras(),
    );
    expect(d.resultado.liquido, esperado.liquido);
    expect(d.resultado.comissao, esperado.comissao);
    expect(d.motorista, 'João Batista');
    expect(d.empresa, 'Transportes Goiatuba');
  });

  test('embarcador: só os fretes dele, e diesel só quando ligado ao frete', () async {
    final s = servidorComAmostra();
    s.t('abastecimentos_efetivos').firstWhere((a) => a['id'] == 'a1')['frete_id'] = 'f1';
    final e = await equipeDe(s);
    final l = e.recorte(embarcador: 'cerealista cerrado ');
    expect(l.fretes.map((f) => f.id), unorderedEquals(['f1', 'f3']));
    expect(l.abastecimentos.map((a) => a.id), ['a1']);
    expect(l.vales, isEmpty);
    expect(e.embarcadores, ['Cerealista Cerrado', 'Fertilizantes Sul']);
  });

  test('caminhão atual, motoristas no caminhão e último envio', () async {
    final e = await equipeDe(servidorComAmostra());
    expect(e.caminhaoAtual(joao)?.placa, 'RVG2C47');
    expect(e.caminhaoAtual(carlos), isNull);
    expect(e.motoristasNoCaminhao(cam2).map((m) => m.id), [pedro]);
    expect(e.ultimoEnvio(e.motorista(joao)!), isNotNull);
    expect(e.caminhoesNoPlano, 2, reason: 'o caminhão não confirmado não conta no plano');
  });

  test('alertas: pedido de entrada, caminhão para conferir, motorista sem enviar', () async {
    final e = await equipeDe(servidorComAmostra());
    final tipos = e.alertas(DateTime.now()).map((a) => a.tipo).toList();
    expect(tipos, containsAll([TipoAlerta.pedidos, TipoAlerta.caminhaoNaoConfirmado, TipoAlerta.semEnvio]));
    expect(tipos, isNot(contains(TipoAlerta.doisMotoristas)));
    final semEnvio = e.alertas(DateTime.now()).firstWhere((a) => a.tipo == TipoAlerta.semEnvio);
    expect(semEnvio.motoristaId, pedro);
  });

  test('dois motoristas no mesmo caminhão geram alerta', () async {
    final s = servidorComAmostra();
    await s.definirCaminhaoAtual(pedro, cam1);
    final e = await equipeDe(s);
    final a = e.alertas(DateTime.now()).where((a) => a.tipo == TipoAlerta.doisMotoristas).toList();
    expect(a, hasLength(1));
    expect(a.single.caminhaoId, cam1);
    expect(e.caminhaoAtual(pedro)?.id, cam1);
  });

  test('km rodados pelo odômetro do caminhão no período', () async {
    final e = await equipeDe(servidorComAmostra());
    expect(e.kmRodados(cam1, mes), 413900 - 412000);
    expect(e.kmRodados(cam3, mes), 0);
  });

  test('correção do gestor aparece no valor efetivo e no histórico', () async {
    final s = servidorComAmostra();
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
    final e = await equipeDe(s);
    final f2 = e.fretes.firstWhere((f) => f.id == 'f2');
    expect(f2.saldoCentavos, 150000);
    expect(f2.camposAjustados, ['saldo_centavos']);
    final h = e.ajustesDe('fretes', 'f2');
    expect(h.single.valorAntigo, 0);
    expect(e.nomeAutor(h.single.autorId), 'Evandro Dono');
  });

  test('textos de quando foi o último envio', () {
    final agora = DateTime(2026, 10, 17, 15);
    expect(quandoTexto(null, agora), 'nunca');
    expect(quandoTexto(DateTime(2026, 10, 17, 9, 5), agora), 'hoje às 09:05');
    expect(quandoTexto(DateTime(2026, 10, 16, 22, 40), agora), 'ontem às 22:40');
    expect(quandoTexto(DateTime(2026, 10, 12, 8), agora), 'há 5 dias');
  });
}
