import '../formato.dart';
import '../modalidades.dart';
import '../modelos.dart';
import '../paradas.dart';
import '../placa.dart';
import '../regras/ajustes.dart';
import '../regras/media_diesel.dart';

/// Planilha CSV no jeito que o Excel e o Google Planilhas em português abrem
/// direto: separador ";", vírgula nos decimais e acentos certos (UTF-8 com BOM).
String gerarCsv(List<String> cabecalho, Iterable<List<Object?>> linhas) {
  String celula(Object? v) {
    if (v == null) return '';
    var t = v is double ? numeroBr(v, 2).replaceAll('.', '') : v.toString();
    if (t.contains(';') || t.contains('"') || t.contains('\n')) {
      t = '"${t.replaceAll('"', '""')}"';
    }
    return t;
  }

  final b = StringBuffer('﻿');
  b.writeln(cabecalho.map(celula).join(';'));
  for (final l in linhas) {
    b.writeln(l.map(celula).join(';'));
  }
  return b.toString();
}

String _reaisCsv(num centavos) => numeroBr(centavos / 100.0, 2).replaceAll('.', '');
String _numCsv(num v, int casas) => numeroBr(v, casas).replaceAll('.', '');

String csvFretes(List<Frete> fretes, {Map<String, String> motoristas = const {}, Map<String, String> placas = const {}}) {
  final ordenados = List<Frete>.from(fretes)..sort((a, b) => a.dataCarga.compareTo(b.dataCarga));
  return gerarCsv([
    'Data da carga', 'Motorista', 'Caminhão', 'Origem', 'Destino', 'Embarcador', 'Peso carga (kg)',
    'Peso descarga (kg)', 'Valor da tonelada (R\$)', 'Contratado (R\$)', 'Adiantamento (R\$)', 'Saldo (R\$)',
    'Frete real (R\$)', 'Pedágio (R\$)', 'Desconto quebra (R\$)', 'Comissão (%)', 'Base da comissão (R\$)',
    'Comissão do motorista (R\$)', 'Corrigido pelo gestor',
  ], [
    for (final f in ordenados)
      [
        dataTexto(f.dataCarga), motoristas[f.motoristaId] ?? '', placaTexto(placas[f.caminhaoId] ?? ''), f.origem,
        f.destino, f.embarcador, _numCsv(f.pesoCargaKg, 0), _numCsv(f.pesoDescargaKg, 0),
        _reaisCsv(f.valorToneladaCentavos), _reaisCsv(f.valorContratadoCentavos), _reaisCsv(f.adiantamentoCentavos),
        _reaisCsv(f.saldoCentavos), _reaisCsv(f.freteRealCentavos), _reaisCsv(f.pedagioCentavos),
        _reaisCsv(f.descontoQuebraCentavos), percentualTexto(f.percentualComissao),
        _reaisCsv(f.baseComissaoCentavos), _reaisCsv(f.minhaParteCentavos),
        f.camposAjustados.map(nomeDoCampo).join(', '),
      ],
  ]);
}

String csvAbastecimentos(List<Abastecimento> lista, List<Abastecimento> todas,
    {Map<String, String> motoristas = const {}, Map<String, String> placas = const {}}) {
  final ordenados = lista.where((a) => !a.pontoDePartida).toList()..sort((a, b) => a.data.compareTo(b.data));
  return gerarCsv([
    'Data', 'Motorista', 'Caminhão', 'Cidade', 'Posto', 'Km', 'Litros', 'Valor (R\$)', 'Preço do litro (R\$)',
    'Tanque cheio', 'Média (km/L)', 'Corrigido pelo gestor',
  ], [
    for (final a in ordenados)
      [
        dataTexto(a.data), motoristas[a.motoristaId] ?? '', placaTexto(placas[a.caminhaoId] ?? ''), a.cidade, a.posto,
        _numCsv(a.km, 0), _numCsv(a.litros, 2), _reaisCsv(a.valorCentavos), _reaisCsv(a.precoLitroCentavos),
        a.tanqueCheio ? 'sim' : 'não',
        () {
          final m = mediaDaLinha(todas, a).media;
          return m == null ? '' : _numCsv(m, 2);
        }(),
        a.camposAjustados.map(nomeDoCampo).join(', '),
      ],
  ]);
}

String csvGastos(List<Gasto> lista, {Map<String, String> motoristas = const {}, Map<String, String> placas = const {}}) {
  final ordenados = List<Gasto>.from(lista)..sort((a, b) => a.data.compareTo(b.data));
  return gerarCsv(['Data', 'Motorista', 'Caminhão', 'Categoria', 'Valor (R\$)', 'Observação', 'Corrigido pelo gestor'], [
    for (final g in ordenados)
      [
        dataTexto(g.data), motoristas[g.motoristaId] ?? '', placaTexto(placas[g.caminhaoId] ?? ''), g.categoriaNome,
        _reaisCsv(g.valorCentavos), g.observacao ?? '', g.camposAjustados.map(nomeDoCampo).join(', '),
      ],
  ]);
}

String csvVales(List<Vale> lista, {Map<String, String> motoristas = const {}}) {
  final ordenados = List<Vale>.from(lista)..sort((a, b) => a.data.compareTo(b.data));
  return gerarCsv(['Data', 'Motorista', 'Valor (R\$)', 'Observação', 'Corrigido pelo gestor'], [
    for (final v in ordenados)
      [
        dataTexto(v.data), motoristas[v.motoristaId] ?? '', _reaisCsv(v.valorCentavos), v.observacao ?? '',
        v.camposAjustados.map(nomeDoCampo).join(', '),
      ],
  ]);
}

String csvViagens(List<Viagem> lista,
    {Map<String, String> motoristas = const {}, Map<String, String> placas = const {}, Modalidade? modalidade}) {
  final ordenados = List<Viagem>.from(lista)..sort((a, b) => a.engateEm.compareTo(b.engateEm));
  final extras = <String>[
    for (final c in modalidade?.campos ?? const <CampoModalidade>[]) if (c.extra) c.chave,
  ];
  return gerarCsv([
    'Engate', 'Motorista', 'Cavalo', 'Carreta', 'Onde engatou', 'Desengate', 'Até onde levou', 'Entregas',
    'Cidades das entregas', 'Observação',
    for (final k in extras) modalidade!.campo(k)!.rotulo,
  ], [
    for (final v in ordenados)
      [
        dataHoraTexto(v.engateEm), motoristas[v.motoristaId] ?? '', placaTexto(placas[v.caminhaoId] ?? ''),
        placaTexto(v.placaCarreta), v.engateLocal, v.desengateEm == null ? 'em andamento' : dataHoraTexto(v.desengateEm!),
        v.desengateLocal, v.entregasQuantidade, v.entregasCidades.join(', '), v.observacao ?? '',
        for (final k in extras) textoDoExtra(modalidade!.campo(k), v.extras[k]),
      ],
  ]);
}

/// Paradas do período, uma por linha, com o tempo sem descanso que veio antes
/// de cada descanso. A última linha é o aviso de que não substitui o tacógrafo.
String csvParadas(DadosParadas d, {Map<String, String> motoristas = const {}, DateTime? agora}) {
  final quando = agora ?? DateTime.now();
  final descanso = {for (final m in d.motivos) if (m.contaComoDescanso) m.codigo};
  final antes = {for (final i in d.resumo.intervalos) if (!i.ateAgora) i.fim: i};
  return gerarCsv([
    'Motorista', 'Caminhão', 'Motivo', 'Descrição', 'Início', 'Fim', 'Duração', 'Duração (min)', 'Conta como descanso',
    'Sem descanso antes', 'Acima do limite', 'Horário informado depois',
  ], [
    for (final p in d.resumo.paradas)
      [
        motoristas[p.motoristaId] ?? d.motorista, d.placaDe(p.caminhaoId), nomeDoMotivo(p.motivo, d.motivos),
        p.descricao ?? '', dataHoraTexto(p.inicioEm), p.fimEm == null ? 'em andamento' : dataHoraTexto(p.fimEm!),
        duracaoTexto(p.duracao(quando)), p.duracao(quando).inMinutes, descanso.contains(p.motivo) ? 'sim' : 'não',
        antes[p.inicioEm] == null ? '' : duracaoTexto(antes[p.inicioEm]!.duracao),
        antes[p.inicioEm] == null ? '' : (antes[p.inicioEm]!.acimaDoLimite ? 'sim' : 'não'),
        p.ajustado ? 'sim' : 'não',
      ],
    <Object?>[],
    <Object?>[avisoParadas],
  ]);
}
