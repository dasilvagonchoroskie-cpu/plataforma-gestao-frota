import '../modelos.dart';
import 'periodo.dart';
import 'resumo.dart';

enum ConteudoRelatorio {
  tudo('Tudo', 'completo'),
  fretes('Fretes', 'fretes'),
  diesel('Diesel', 'diesel'),
  gastos('Gastos', 'gastos'),
  vales('Vales', 'vales');

  const ConteudoRelatorio(this.rotulo, this.arquivo);
  final String rotulo;
  final String arquivo;
}

/// Tudo que entra num relatório (ou no resumo de um período).
class DadosRelatorio {
  const DadosRelatorio({
    required this.periodo,
    required this.conteudo,
    required this.fretes,
    required this.abastecimentos,
    required this.abastecimentosCompletos,
    required this.vales,
    required this.gastos,
    required this.ajustes,
    required this.resultado,
    required this.regras,
    this.viagem = '',
    this.motorista = '',
    this.placa = '',
    this.empresa = '',
    this.embarcador = '',
    this.placasPorCaminhao = const {},
  });

  final Periodo periodo;
  final ConteudoRelatorio conteudo;
  final List<Frete> fretes;

  /// Abastecidas do período (sem o ponto de partida).
  final List<Abastecimento> abastecimentos;

  /// Todas as abastecidas (para a média de cada linha).
  final List<Abastecimento> abastecimentosCompletos;
  final List<Vale> vales;
  final List<Gasto> gastos;
  final List<AjusteKm> ajustes;
  final ResultadoResumo resultado;
  final Regras regras;

  /// "Uberlândia para Santos" quando é o acerto de uma viagem.
  final String viagem;

  /// Saem no cabeçalho do PDF ("" = não mostra; "Todos" quando é a frota).
  final String motorista;
  final String placa;
  final String empresa;
  final String embarcador;

  /// Placa de cada caminhão (para mostrar em cada linha quando há mais de um).
  final Map<String, String> placasPorCaminhao;

  bool get ehViagem => viagem.isNotEmpty;

  bool get vazio => fretes.isEmpty && abastecimentos.isEmpty && vales.isEmpty && gastos.isEmpty;

  /// Mais de um caminhão nos lançamentos do relatório.
  bool get variosCaminhoes => {
        ...fretes.map((f) => f.caminhaoId),
        ...abastecimentos.map((a) => a.caminhaoId),
        ...gastos.map((g) => g.caminhaoId),
      }.length > 1;
}

DadosRelatorio montarDados({
  required List<Frete> fretes,
  required List<Abastecimento> abastecimentos,
  required List<Vale> vales,
  required List<Gasto> gastos,
  required List<AjusteKm> ajustes,
  required Periodo periodo,
  required Regras regras,
  ConteudoRelatorio conteudo = ConteudoRelatorio.tudo,
  Frete? soEsteFrete,
  String motorista = '',
  String placa = '',
  String empresa = '',
  String embarcador = '',
  Map<String, String> placasPorCaminhao = const {},
}) {
  bool vivo(DateTime? apagado) => apagado == null;
  final fretesP = soEsteFrete != null
      ? [soEsteFrete]
      : fretes.where((f) => vivo(f.apagadoEm) && periodo.contem(f.dataCarga)).toList();
  final abastP =
      abastecimentos.where((a) => vivo(a.apagadoEm) && !a.pontoDePartida && periodo.contem(a.data)).toList();
  final valesP = vales.where((v) => vivo(v.apagadoEm) && periodo.contem(v.data)).toList();
  final gastosP = gastos.where((g) => vivo(g.apagadoEm) && periodo.contem(g.data)).toList();
  final ajustesP = ajustes.where((a) => periodo.contem(a.quando)).toList();

  final resultado = calcularResumo(
    fretes: fretesP,
    abastecimentos: abastP.map((a) => a.valorCentavos).toList(),
    gastos: gastosP.map((g) => g.valorCentavos).toList(),
    vales: valesP.map((v) => v.valorCentavos).toList(),
    regras: regras,
  );

  return DadosRelatorio(
    periodo: periodo,
    conteudo: conteudo,
    fretes: fretesP,
    abastecimentos: abastP,
    abastecimentosCompletos: abastecimentos.where((a) => vivo(a.apagadoEm)).toList(),
    vales: valesP,
    gastos: gastosP,
    ajustes: ajustesP,
    resultado: resultado,
    regras: regras,
    viagem: soEsteFrete?.rota ?? '',
    motorista: motorista,
    placa: placa,
    empresa: empresa,
    embarcador: embarcador,
    placasPorCaminhao: placasPorCaminhao,
  );
}

/// Acerto de uma viagem: o frete e o que foi lançado na janela dela. As
/// outras cargas que definem a janela são as do mesmo motorista.
DadosRelatorio montarDadosDaViagem({
  required Frete frete,
  required List<Frete> fretes,
  required List<Abastecimento> abastecimentos,
  required List<Vale> vales,
  required List<Gasto> gastos,
  required List<AjusteKm> ajustes,
  required Regras regras,
  DateTime? agora,
  String motorista = '',
  String placa = '',
  String empresa = '',
  Map<String, String> placasPorCaminhao = const {},
}) {
  final doMotorista = fretes.where((f) => f.motoristaId == frete.motoristaId && f.apagadoEm == null);
  final janela = janelaDaViagem(frete.dataCarga, doMotorista.map((f) => f.dataCarga).toList(), agora: agora);
  return montarDados(
    fretes: fretes,
    abastecimentos: abastecimentos.where((a) => a.motoristaId == frete.motoristaId).toList(),
    vales: vales.where((v) => v.motoristaId == frete.motoristaId).toList(),
    gastos: gastos.where((g) => g.motoristaId == frete.motoristaId).toList(),
    ajustes: ajustes.where((a) => a.motoristaId == frete.motoristaId).toList(),
    periodo: janela,
    regras: regras,
    soEsteFrete: frete,
    motorista: motorista,
    placa: placa,
    empresa: empresa,
    placasPorCaminhao: placasPorCaminhao,
  );
}
