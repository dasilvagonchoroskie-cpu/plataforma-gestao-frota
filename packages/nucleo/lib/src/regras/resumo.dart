import '../modelos.dart';

/// As perguntas de "como a empresa acerta com o motorista".
class Regras {
  const Regras({
    this.freteRealEhValorCheio = true,
    this.gastosDescontamDoLiquido = false,
    this.valeDescontaDoLiquido = true,
  });

  factory Regras.daEmpresa(ConfiguracaoEmpresa c) => Regras(
        gastosDescontamDoLiquido: c.gastosDescontamDoLiquido,
        valeDescontaDoLiquido: c.valeDescontaDoLiquido,
      );

  /// Adiantamento + saldo é o frete inteiro (true) ou só a parte do motorista.
  /// Na frota é sempre o frete inteiro (a empresa recebe o frete).
  final bool freteRealEhValorCheio;

  /// Diesel e gastos saem do bolso do motorista.
  final bool gastosDescontamDoLiquido;

  /// O vale abate do que o motorista tem para receber.
  final bool valeDescontaDoLiquido;
}

/// Totais de um período. Tudo em centavos (com casas; arredonde para mostrar).
class ResultadoResumo {
  const ResultadoResumo({
    required this.totalFretes,
    required this.quantidadeFretes,
    required this.totalPedagio,
    required this.totalDescontoQuebra,
    required this.totalBaseComissao,
    required this.comissao,
    required this.percentualMedio,
    required this.percentuaisDiferentes,
    required this.totalAbastecimento,
    required this.totalGastos,
    required this.totalGastoGeral,
    required this.totalVale,
    required this.liquido,
    required this.totalQuebraCalculada,
    required this.totalQuebraKg,
    required this.totalContratado,
    required this.totalDescontoDoFrete,
    required this.fretesEmAberto,
    required this.contratadoEmAberto,
    required this.comissaoDoCaminhao,
    required this.sobraDoCaminhao,
  });

  /// Frete real somado (o que caiu na conta).
  final double totalFretes;
  final int quantidadeFretes;
  final double totalPedagio;
  final double totalDescontoQuebra;
  final double totalBaseComissao;

  /// A parte do motorista.
  final double comissao;
  final double percentualMedio;
  final bool percentuaisDiferentes;
  final double totalAbastecimento;
  final double totalGastos;

  /// Diesel + outros gastos.
  final double totalGastoGeral;
  final double totalVale;

  /// O que o motorista tem para receber.
  final double liquido;
  final double totalQuebraCalculada;
  final double totalQuebraKg;

  /// Contratado (peso x tonelada) dos fretes já pagos.
  final double totalContratado;

  /// Contratado menos o que caiu, dos fretes já pagos.
  final double totalDescontoDoFrete;
  final int fretesEmAberto;
  final double contratadoEmAberto;
  final double comissaoDoCaminhao;

  /// Frete líquido - diesel - gastos - comissão.
  final double sobraDoCaminhao;

  bool get vazio => quantidadeFretes == 0 && totalAbastecimento == 0 && totalGastos == 0 && totalVale == 0;
}

double _soma<T>(Iterable<T> itens, num Function(T) valor) => itens.fold<double>(0, (s, e) => s + valor(e));

/// Mesma conta do Meu Frete (versão 1.2, CalculoResumo.kt), em centavos.
ResultadoResumo calcularResumo({
  required List<Frete> fretes,
  required List<int> abastecimentos,
  required List<int> gastos,
  required List<int> vales,
  Regras regras = const Regras(),
}) {
  final totalFretes = _soma(fretes, (Frete f) => f.freteRealCentavos);
  final totalPedagio = _soma(fretes, (Frete f) => f.pedagioCentavos);
  final totalDescontoQuebra = _soma(fretes, (Frete f) => f.descontoQuebraCentavos);
  final totalBaseComissao = _soma(fretes, (Frete f) => f.baseComissaoCentavos);
  final totalAbastecimento = _soma(abastecimentos, (int v) => v);
  final totalGastos = _soma(gastos, (int v) => v);
  final totalGastoGeral = totalAbastecimento + totalGastos;
  final totalVale = _soma(vales, (int v) => v);
  final totalQuebraCalculada = _soma(fretes, (Frete f) => f.valorQuebraIntegralCentavos);
  final totalQuebraKg = _soma(fretes, (Frete f) => f.quebraKg ?? 0);

  final emAberto = fretes.where((f) => f.freteRealCentavos <= 0 && f.valorContratadoCentavos > 0).toList();
  final contratadoEmAberto = _soma(emAberto, (Frete f) => f.valorContratadoCentavos);

  final pagos = fretes.where((f) => f.freteRealCentavos > 0).toList();
  final totalContratado = _soma(pagos, (Frete f) => f.valorContratadoCentavos);
  final caiuDosPagos = _soma(pagos, (Frete f) => f.freteRealCentavos);
  final descontoDoFrete = totalContratado - caiuDosPagos;
  final totalDescontoDoFrete = descontoDoFrete > 0 ? descontoDoFrete : 0.0;

  final comissaoDoCaminhao = _soma(fretes, (Frete f) => f.minhaParteCentavos);
  final comissao = regras.freteRealEhValorCheio ? comissaoDoCaminhao : totalFretes;
  final percentualMedio =
      (totalBaseComissao > 0 && regras.freteRealEhValorCheio) ? (comissao / totalBaseComissao) * 100 : 0.0;
  final percentuaisDiferentes = fretes.map((f) => f.percentualComissao).toSet().length > 1;

  var liquido = regras.gastosDescontamDoLiquido ? comissao - totalGastoGeral : comissao;
  if (regras.valeDescontaDoLiquido) liquido -= totalVale;

  return ResultadoResumo(
    totalFretes: totalFretes,
    quantidadeFretes: fretes.length,
    totalPedagio: totalPedagio,
    totalDescontoQuebra: totalDescontoQuebra,
    totalBaseComissao: totalBaseComissao,
    comissao: comissao,
    percentualMedio: percentualMedio,
    percentuaisDiferentes: percentuaisDiferentes,
    totalAbastecimento: totalAbastecimento,
    totalGastos: totalGastos,
    totalGastoGeral: totalGastoGeral,
    totalVale: totalVale,
    liquido: liquido,
    totalQuebraCalculada: totalQuebraCalculada,
    totalQuebraKg: totalQuebraKg,
    totalContratado: totalContratado,
    totalDescontoDoFrete: totalDescontoDoFrete,
    fretesEmAberto: emAberto.length,
    contratadoEmAberto: contratadoEmAberto,
    comissaoDoCaminhao: comissaoDoCaminhao,
    sobraDoCaminhao: totalFretes - totalAbastecimento - totalGastos - comissaoDoCaminhao,
  );
}
