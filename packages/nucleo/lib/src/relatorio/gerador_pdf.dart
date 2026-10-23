import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../formato.dart';
import '../modalidades.dart';
import '../arquivo_dados.dart';
import '../modelos.dart';
import '../paradas.dart';
import '../placa.dart';
import '../regras/ajustes.dart';
import '../regras/dados_relatorio.dart';
import '../regras/media_diesel.dart';
import '../regras/resumo.dart';

/// Nome do produto no rodapé dos relatórios (provisório).
const nomeDoProduto = 'Plataforma de Gestão de Frota';

/// Letras embutidas no PDF (acentos e símbolos saem certos em qualquer celular).
class FontesPdf {
  const FontesPdf(this.normal, this.negrito, this.numero, this.numeroNegrito);
  final pw.Font normal;
  final pw.Font negrito;
  final pw.Font numero;
  final pw.Font numeroNegrito;

  /// Barlow Regular, Barlow SemiBold, Barlow Semi Condensed SemiBold e Bold.
  factory FontesPdf.deBytes(ByteData normal, ByteData negrito, ByteData numero, ByteData numeroNegrito) =>
      FontesPdf(pw.Font.ttf(normal), pw.Font.ttf(negrito), pw.Font.ttf(numero), pw.Font.ttf(numeroNegrito));

  /// Arquivos que os apps precisam carregar, na ordem do construtor.
  static const arquivos = [
    'Barlow-Regular.ttf',
    'Barlow-SemiBold.ttf',
    'BarlowSemiCondensed-SemiBold.ttf',
    'BarlowSemiCondensed-Bold.ttf',
  ];
}

const _tintaEscura = PdfColor.fromInt(0xFF1E2427);
const _tintaCinza = PdfColor.fromInt(0xFF5B6560);
const _tintaVerde = PdfColor.fromInt(0xFF0A7343);
const _tintaLaranja = PdfColor.fromInt(0xFF9A6200);
const _tintaVermelha = PdfColor.fromInt(0xFFB22A2A);
const _fundoCaixa = PdfColor.fromInt(0xFFF0F2EE);
const _fundoVerde = PdfColor.fromInt(0xFFE6F4EC);
const _fundoAmarelo = PdfColor.fromInt(0xFFFFF6DC);
const _fundoVermelho = PdfColor.fromInt(0xFFFDEDED);
const _verdePlaca = PdfColor.fromInt(0xFF0B5D3B);

String nomeDoArquivoPdf(DadosRelatorio d) {
  final inicio = dataTexto(d.periodo.inicio).replaceAll('/', '-');
  final placa = d.placa.isEmpty || !placaValida(d.placa) ? '' : '${normalizarPlaca(d.placa)}_';
  final quem = d.motorista.isEmpty || d.motorista == 'Todos'
      ? ''
      : '${semAcento(d.motorista.split(' ').first).replaceAll(RegExp(r'[^A-Za-z0-9]'), '')}_';
  if (d.acerto != null) {
    final a = d.acerto!;
    final i = dataTexto(a.periodoInicio).replaceAll('/', '-');
    final f = dataTexto(a.periodoFim).replaceAll('/', '-');
    return 'Frota_$quem${placa}acerto_${i}_a_$f.pdf';
  }
  if (d.ehViagem) {
    var v = d.viagem.replaceAll(' para ', '-');
    v = semAcento(v).replaceAll(RegExp(r'[^A-Za-z0-9\-]'), '');
    if (v.length > 40) v = v.substring(0, 40);
    return 'Frota_$quem${placa}viagem_${v}_$inicio.pdf';
  }
  final fim = dataTexto(d.periodo.fim).replaceAll('/', '-');
  final arquivo = d.porViagem && d.conteudo == ConteudoRelatorio.fretes ? 'viagens' : d.conteudo.arquivo;
  return 'Frota_$quem$placa${arquivo}_${inicio}_a_$fim.pdf';
}

class _Pdf {
  _Pdf(this.f, [this.d]);
  final FontesPdf f;

  /// Sem dados (relatório de paradas), não há conta de caminhão.
  final DadosRelatorio? d;

  pw.TextStyle t(double tamanho, {PdfColor cor = _tintaEscura, bool negrito = false, bool numero = false}) =>
      pw.TextStyle(
        font: numero ? (negrito ? f.numeroNegrito : f.numero) : (negrito ? f.negrito : f.normal),
        fontSize: tamanho,
        color: cor,
        lineSpacing: 1.5,
      );

  /// " | ABC1D23" quando o relatório tem mais de um caminhão.
  String placaDaLinha(String caminhaoId) {
    final d = this.d;
    if (d == null || !d.variosCaminhoes) return '';
    final p = d.placasPorCaminhao[caminhaoId];
    return p == null || p.isEmpty ? '' : '   ${placaTexto(p)}';
  }

  pw.Widget titulo(String texto) => pw.Container(
        margin: const pw.EdgeInsets.only(top: 18, bottom: 8),
        padding: const pw.EdgeInsets.only(bottom: 4),
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: _tintaCinza, width: 0.8)),
        ),
        child: pw.Text(texto, style: t(14, negrito: true)),
      );

  pw.Widget valor(String rotulo, String v, {PdfColor cor = _tintaEscura}) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 5, bottom: 1),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Expanded(child: pw.Text(rotulo, style: t(12))),
            pw.Text(v, style: t(14, negrito: true, numero: true, cor: cor)),
          ],
        ),
      );

  pw.Widget nota(String texto, {PdfColor cor = _tintaCinza, double recuo = 0, double tamanho = 9.5, double abaixo = 4}) =>
      pw.Padding(
        padding: pw.EdgeInsets.only(left: recuo, bottom: abaixo),
        child: pw.Text(texto, style: t(tamanho, cor: cor)),
      );

  pw.Widget item(String texto, String v) => pw.Padding(
        padding: const pw.EdgeInsets.only(left: 12, top: 1, bottom: 1),
        child: pw.Row(children: [
          pw.Expanded(child: pw.Text(texto, style: t(9.5, cor: _tintaCinza))),
          pw.Text(v, style: t(10, cor: _tintaCinza, numero: true)),
        ]),
      );

  pw.Widget bloco(String rotulo, String v, String detalhe,
          {PdfColor cor = _tintaVerde, PdfColor fundo = _fundoVerde}) =>
      pw.Container(
        width: double.infinity,
        margin: const pw.EdgeInsets.only(top: 8, bottom: 8),
        padding: const pw.EdgeInsets.fromLTRB(14, 10, 14, 12),
        decoration: pw.BoxDecoration(
          color: fundo,
          border: pw.Border.all(color: cor, width: 1.5),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(rotulo, style: t(10.5, cor: cor, negrito: true)),
            pw.SizedBox(height: 2),
            pw.Text(v, style: t(24, negrito: true, numero: true)),
            if (detalhe.isNotEmpty) pw.Text(detalhe, style: t(10, cor: _tintaCinza, numero: true)),
          ],
        ),
      );
}

/// Monta o PDF do relatório (ou do acerto de uma viagem). Mesmo modelo do
/// Meu Frete, com o nome da empresa, o motorista e o caminhão no cabeçalho.
Future<Uint8List> gerarPdf(DadosRelatorio d, FontesPdf fontes, {DateTime? agora}) async {
  final p = _Pdf(fontes, d);
  final doc = pw.Document(title: d.empresa.isEmpty ? nomeDoProduto : d.empresa, author: nomeDoProduto);
  final conteudo = _conteudoRelatorio(p, d, agora ?? DateTime.now());

  final rodape = d.empresa.isEmpty ? nomeDoProduto : '${d.empresa}  |  $nomeDoProduto';
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 36, 40, 36),
      maxPages: 200,
      theme: pw.ThemeData.withFont(base: fontes.normal, bold: fontes.negrito),
      footer: (ctx) => pw.Container(
        alignment: pw.Alignment.centerRight,
        margin: const pw.EdgeInsets.only(top: 10),
        child: pw.Text('$rodape  |  página ${ctx.pageNumber} de ${ctx.pagesCount}', style: p.t(8.5, cor: _tintaCinza)),
      ),
      build: (ctx) => conteudo,
    ),
  );
  return doc.save();
}

/// O relatório (cabeçalho e seções), para o PDF dele ou para o arquivo de dados.
List<pw.Widget> _conteudoRelatorio(_Pdf p, DadosRelatorio d, DateTime agora) {
  final conteudo = <pw.Widget>[];
  conteudo.addAll(_cabecalho(p, d, agora));
  switch (d.conteudo) {
    case ConteudoRelatorio.tudo:
      if (d.porViagem) {
        conteudo.addAll(_resumoViagens(p, d));
        conteudo.addAll(_viagens(p, d));
      } else {
        conteudo.addAll(_resumo(p, d));
        conteudo.addAll(_fretes(p, d.fretes, d.modalidade));
        // Frota com Graneleiro e Baú juntos: as viagens entram também.
        if (d.viagens.isNotEmpty) conteudo.addAll(_viagens(p, d));
      }
      conteudo.addAll(_abastecimentos(p, d.abastecimentos, d.abastecimentosCompletos));
      conteudo.addAll(_vales(p, d.vales, d.resultado.totalVale));
      conteudo.addAll(_gastos(p, d.gastos, d.resultado.totalGastos));
    case ConteudoRelatorio.diesel:
      conteudo.addAll(_abastecimentos(p, d.abastecimentos, d.abastecimentosCompletos));
      conteudo.addAll(_fechoDiesel(p, d));
    case ConteudoRelatorio.fretes:
      if (d.porViagem) {
        conteudo.addAll(_viagens(p, d));
      } else {
        conteudo.addAll(_fretes(p, d.fretes, d.modalidade));
        conteudo.addAll(_fechoFretes(p, d.resultado));
        if (d.viagens.isNotEmpty) conteudo.addAll(_viagens(p, d));
      }
    case ConteudoRelatorio.vales:
      conteudo.addAll(_vales(p, d.vales, d.resultado.totalVale));
    case ConteudoRelatorio.gastos:
      conteudo.addAll(_gastos(p, d.gastos, d.resultado.totalGastos));
      if (!d.porViagem) conteudo.addAll(_fechoGastos(p, d));
  }
  conteudo.addAll(_ajustesKm(p, d.ajustes));
  conteudo.addAll(_avisoAjustes(p, d));
  return conteudo;
}

List<pw.Widget> _cabecalho(_Pdf p, DadosRelatorio d, DateTime agora) {
  final String subtitulo;
  if (d.acerto != null) {
    subtitulo = 'Acerto do motorista${d.modalidade == null ? '' : ' (${d.modalidade!.nome})'}';
  } else if (d.ehViagem) {
    subtitulo = 'Acerto da viagem: ${d.viagem}';
  } else if (d.porViagem) {
    subtitulo = switch (d.conteudo) {
      ConteudoRelatorio.tudo => 'Relatório de viagens, diesel, vales e gastos',
      ConteudoRelatorio.fretes => 'Relatório de viagens',
      ConteudoRelatorio.diesel => 'Relatório de diesel',
      ConteudoRelatorio.vales => 'Relatório de vales',
      ConteudoRelatorio.gastos => 'Relatório de gastos',
    };
  } else {
    switch (d.conteudo) {
      case ConteudoRelatorio.tudo:
        subtitulo = 'Relatório de fretes, diesel, vales e gastos';
      case ConteudoRelatorio.diesel:
        subtitulo = 'Relatório de diesel';
      case ConteudoRelatorio.fretes:
        subtitulo = 'Relatório de fretes';
      case ConteudoRelatorio.vales:
        subtitulo = 'Relatório de vales';
      case ConteudoRelatorio.gastos:
        subtitulo = 'Relatório de gastos';
    }
  }
  var marca = d.empresa.isEmpty ? 'Gestão de Frota' : d.empresa;
  if (marca.length > 28) marca = '${marca.substring(0, 27)}…';
  return [
    pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.all(2),
          decoration: const pw.BoxDecoration(
            color: _verdePlaca,
            borderRadius: pw.BorderRadius.all(pw.Radius.circular(5)),
          ),
          child: pw.Container(
            padding: const pw.EdgeInsets.fromLTRB(8, 3, 8, 3),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.white, width: 1),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Text(marca, style: p.t(16, cor: PdfColors.white, negrito: true, numero: true)),
          ),
        ),
        pw.SizedBox(width: 12),
        pw.Expanded(child: pw.Text(subtitulo, style: p.t(12.5, cor: _tintaCinza))),
      ],
    ),
    pw.SizedBox(height: 10),
    if (d.ehViagem)
      p.nota(
        'Entram nesta conta os gastos, abastecidas e vales lançados entre a data desta carga e o dia em que a '
        'carga seguinte foi pega, com esse último dia incluído, porque o que se gasta nele (pedágio e diesel '
        'rodando até o próximo carregamento) é custo de fechar esta viagem. Confira as datas abaixo: gasto lançado '
        'com data errada aparece na viagem errada.',
        tamanho: 8.5,
        abaixo: 8,
      ),
    pw.Container(
      width: double.infinity,
      color: _fundoCaixa,
      padding: const pw.EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            flex: 5,
            child: _campoCaixa(p, 'Período', '${dataTexto(d.periodo.inicio)}  a  ${dataTexto(d.periodo.fim)}'),
          ),
          if (d.placa.isNotEmpty)
            pw.Expanded(
                flex: 3, child: _campoCaixa(p, 'Caminhão', placaValida(d.placa) ? placaTexto(d.placa) : d.placa)),
          if (d.motorista.isNotEmpty) pw.Expanded(flex: 5, child: _campoCaixa(p, 'Motorista', d.motorista)),
        ],
      ),
    ),
    if (d.embarcador.isNotEmpty) p.nota('Embarcador: ${d.embarcador}', tamanho: 10, abaixo: 2),
    pw.SizedBox(height: 4),
    p.nota('Gerado em ${dataHoraTexto(agora)}', tamanho: 9),
  ];
}

pw.Widget _campoCaixa(_Pdf p, String rotulo, String valor) => pw.Padding(
      padding: const pw.EdgeInsets.only(right: 10),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(rotulo, style: p.t(9.5, cor: _tintaCinza, negrito: true)),
          pw.Text(valor, style: p.t(14, negrito: true, numero: true)),
        ],
      ),
    );

List<pw.Widget> _resumo(_Pdf p, DadosRelatorio d) {
  final r = d.resultado;
  final regras = d.regras;
  final w = <pw.Widget>[p.titulo('Resumo do período')];
  w.add(p.valor('Total de fretes', reais(r.totalFretes)));
  w.add(p.nota(
    plural(r.quantidadeFretes, 'frete', 'fretes') +
        (r.totalPedagio > 0 ? '   |   pedágio ${reais(r.totalPedagio)} (cartão/tag, fora do frete)' : ''),
    recuo: 8,
  ));
  w.add(p.valor(regras.freteRealEhValorCheio ? 'Comissão (a parte do motorista)' : 'Parte do motorista', reais(r.comissao)));
  final String linhaComissao;
  if (!regras.freteRealEhValorCheio) {
    linhaComissao = 'Valor já lançado como a parte do motorista';
  } else if (r.percentuaisDiferentes) {
    linhaComissao = 'Percentuais diferentes entre os fretes. Na média deu ${percentualTexto(r.percentualMedio)}% '
        'sobre ${reais(r.totalBaseComissao)}';
  } else {
    linhaComissao = '${percentualTexto(r.percentualMedio)}% sobre ${reais(r.totalBaseComissao)}';
  }
  w.add(p.nota(linhaComissao, recuo: 8, cor: r.percentuaisDiferentes ? _tintaLaranja : _tintaCinza));
  w.add(p.valor('Total gasto', reais(r.totalGastoGeral)));
  w.add(p.nota('Diesel ${reais(r.totalAbastecimento)}   |   Outros gastos ${reais(r.totalGastos)}', recuo: 8, abaixo: 1));
  w.add(p.nota(
    regras.gastosDescontamDoLiquido
        ? 'Pago pelo motorista. Desconta do líquido.'
        : 'Pago pela empresa. Não desconta do líquido do motorista.',
    recuo: 8,
  ));
  w.add(p.valor('Total de vale', reais(r.totalVale)));
  w.add(p.nota(
    regras.valeDescontaDoLiquido ? 'Já adiantado ao motorista. Desconta do líquido.' : 'Só histórico. Não desconta do líquido.',
    recuo: 8,
  ));
  final conta = StringBuffer('Comissão ${reais(r.comissao)}');
  if (regras.gastosDescontamDoLiquido) conta.write('  menos gastos ${reais(r.totalGastoGeral)}');
  if (regras.valeDescontaDoLiquido) conta.write('  menos vale ${reais(r.totalVale)}');
  w.add(p.bloco('VALOR LÍQUIDO A RECEBER', reais(r.liquido), conta.toString(),
      cor: r.liquido < 0 ? _tintaVermelha : _tintaVerde, fundo: r.liquido < 0 ? _fundoVermelho : _fundoVerde));
  if (regras.freteRealEhValorCheio) w.addAll(_contaDoCaminhao(p, d));
  return w;
}

List<pw.Widget> _contaDoCaminhao(_Pdf p, DadosRelatorio d) {
  final r = d.resultado;
  final w = <pw.Widget>[
    p.titulo(d.variosCaminhoes ? 'Conta dos caminhões' : 'Conta do caminhão'),
    p.nota('Aqui a pergunta é outra: este período deu lucro para o caminhão? Parte do que entrou na conta e '
        'desconta tudo que saiu.', abaixo: 6),
  ];
  if (r.totalContratado > 0) {
    w.add(p.valor('Frete contratado', reais(r.totalContratado)));
    w.add(p.nota('Peso vezes o valor da tonelada, conforme a carta-frete', recuo: 8));
    w.add(p.valor('( - ) Desconto da transportadora', reais(r.totalDescontoDoFrete)));
    w.add(p.nota(
      'INSS, SEST/SENAT, seguro, quebra, vale-pedágio e o que mais a transportadora tiver retido. A conta é '
      'feita pela diferença entre o contratado e o que caiu na conta, então o valor bate sempre com a carta-frete.',
      recuo: 8,
    ));
  }
  w.add(p.valor('Frete líquido', reais(r.totalFretes)));
  w.add(p.nota('O que realmente caiu na conta: adiantamento mais saldo de ${plural(r.quantidadeFretes, 'frete', 'fretes')}',
      recuo: 8));
  w.add(p.valor('( - ) Diesel', reais(r.totalAbastecimento)));
  for (final a in d.abastecimentos) {
    final posto = a.posto.trim().isEmpty ? 'posto' : a.posto.trim();
    final cidade = a.cidade.trim().isEmpty ? '' : ' (${a.cidade.trim()})';
    w.add(p.item('${dataTexto(a.data)}   $posto$cidade   ${umaCasa(a.litros)} L${p.placaDaLinha(a.caminhaoId)}',
        reais(a.valorCentavos)));
  }
  w.add(p.valor('( - ) Outros gastos', reais(r.totalGastos)));
  for (final g in d.gastos) {
    w.add(p.item(
        '${dataTexto(g.data)}   ${g.categoriaNome.trim().isEmpty ? 'sem categoria' : g.categoriaNome}${p.placaDaLinha(g.caminhaoId)}',
        reais(g.valorCentavos)));
  }
  w.add(p.valor('( - ) Comissão do motorista', reais(r.comissaoDoCaminhao)));
  w.add(p.nota('Quem paga a comissão é o frete. Por isso ela entra como despesa do caminhão, no mesmo peso do diesel.',
      recuo: 8));
  if (r.totalPedagio > 0) {
    w.add(p.nota(
      'O pedágio de ${reais(r.totalPedagio)} NÃO entra nesta subtração: foi pago no cartão ou tag da empresa, esse '
      'dinheiro nunca saiu da conta. Pedágio pago do próprio bolso deve ser lançado em Gastos.',
      recuo: 8,
      tamanho: 8.5,
    ));
  }
  final emAberto = r.fretesEmAberto > 0;
  final positivo = r.sobraDoCaminhao >= 0;
  if (emAberto) {
    w.add(p.bloco(
      r.fretesEmAberto == 1 ? '1 FRETE AINDA NÃO FOI PAGO' : '${r.fretesEmAberto} FRETES AINDA NÃO FORAM PAGOS',
      reais(r.contratadoEmAberto),
      'Devem entrar quando o saldo cair. Enquanto isso, a conta abaixo mostra despesa sem a receita correspondente.',
      cor: _tintaLaranja,
      fundo: _fundoAmarelo,
    ));
  }
  final contaTexto = '${reais(r.totalFretes)} - ${dinheiro(r.totalAbastecimento)} - ${dinheiro(r.totalGastos)} - '
      '${dinheiro(r.comissaoDoCaminhao)}';
  w.add(p.bloco(
    positivo
        ? (d.variosCaminhoes ? 'SOBROU PARA OS CAMINHÕES' : 'SOBROU PARA O CAMINHÃO')
        : (emAberto ? 'NO VERMELHO POR ENQUANTO (falta o frete cair)' : 'FALTOU (o período deu prejuízo)'),
    reais(r.sobraDoCaminhao),
    contaTexto,
    cor: positivo ? _tintaVerde : (emAberto ? _tintaLaranja : _tintaVermelha),
    fundo: positivo ? _fundoVerde : (emAberto ? _fundoAmarelo : _fundoVermelho),
  ));
  if (r.totalQuebraKg > 0 || r.totalDescontoQuebra > 0) {
    w.add(pw.Padding(
      padding: const pw.EdgeInsets.only(top: 4, bottom: 2),
      child: pw.Text('Quebra na descarga', style: p.t(11, negrito: true)),
    ));
    if (r.totalQuebraKg > 0) {
      w.add(p.nota('Faltaram ${semCasas(r.totalQuebraKg)} kg entre a carga e a descarga. Pelo valor da tonelada isso '
          'daria ${reais(r.totalQuebraCalculada)}.', recuo: 8));
    }
    if (r.totalDescontoQuebra > 0) {
      w.add(p.nota('A transportadora cobrou ${reais(r.totalDescontoQuebra)}.', recuo: 8));
      final aMais = r.totalDescontoQuebra - r.totalQuebraCalculada;
      if (r.totalQuebraCalculada > 0 && aMais > 1) {
        w.add(p.nota('ATENÇÃO: cobraram ${reais(aMais)} a mais do que a quebra valia pelo preço da tonelada. '
            'Vale conferir o contrato.', recuo: 8, cor: _tintaLaranja));
      }
    }
    w.add(p.nota('A quebra não é subtraída de novo aqui: o saldo recebido já veio com ela descontada.',
        recuo: 8, tamanho: 8.5));
  }
  return w;
}

List<pw.Widget> _fechoDiesel(_Pdf p, DadosRelatorio d) {
  final lista = d.abastecimentos;
  if (lista.isEmpty) return [];
  final total = lista.fold<double>(0, (s, a) => s + a.valorCentavos);
  final litros = lista.fold<double>(0, (s, a) => s + a.litros);
  final mp = mediaDoPeriodo(lista, d.abastecimentosCompletos);
  final w = <pw.Widget>[
    p.titulo('Fecho do diesel'),
    p.valor('Total gasto com diesel', reais(total)),
    p.valor('Litros abastecidos', '${umaCasa(litros)} L'),
  ];
  if (litros > 0) w.add(p.nota('Preço médio do litro: ${reais(total / litros)}', recuo: 8));
  final media = mp.media;
  if (media != null) {
    w.add(p.bloco(d.variosCaminhoes ? 'MÉDIA REAL DOS CAMINHÕES' : 'MÉDIA REAL DO CAMINHÃO', '${umaCasa(media)} km/L',
        '${semCasas(mp.km)} km rodados com ${umaCasa(mp.litros)} L'));
    if (d.variosCaminhoes) {
      final porCaminhao = mediaPorCaminhao(lista, d.abastecimentosCompletos);
      for (final e in porCaminhao.entries) {
        final m = e.value.media;
        final placa = d.placasPorCaminhao[e.key];
        if (placa == null) continue;
        w.add(p.item(placaTexto(placa), m == null ? 'sem média ainda' : '${umaCasa(m)} km/L'));
      }
    }
    w.add(p.nota('Km rodados divididos pelos litros que entraram, de tanque cheio a tanque cheio, sempre dentro do '
        'mesmo caminhão. Não é a média de cada abastecida somada e dividida, que daria outro número, porque cada '
        'tanque tem um tamanho.', tamanho: 8.5));
  } else {
    w.add(p.nota('Ainda não dá para calcular a média do período: é preciso pelo menos dois tanques cheios.',
        cor: _tintaLaranja));
  }
  return w;
}

List<pw.Widget> _fechoFretes(_Pdf p, ResultadoResumo r) {
  if (r.quantidadeFretes == 0) return [];
  return [
    p.titulo('Fecho dos fretes'),
    if (r.totalContratado > 0) ...[
      p.valor('Frete contratado', reais(r.totalContratado)),
      p.valor('( - ) Desconto da transportadora', reais(r.totalDescontoDoFrete)),
    ],
    p.bloco('FRETE LÍQUIDO QUE CAIU NA CONTA', reais(r.totalFretes),
        '${plural(r.quantidadeFretes, 'frete', 'fretes')}   |   comissão do motorista ${reais(r.comissaoDoCaminhao)}'),
  ];
}

List<pw.Widget> _fechoGastos(_Pdf p, DadosRelatorio d) {
  final r = d.resultado;
  final total = r.totalGastoGeral + r.comissaoDoCaminhao;
  if (total <= 0) return [];
  return [
    p.titulo('Tudo que o caminhão gastou'),
    p.nota('A lista acima traz só os gastos avulsos. O custo de verdade inclui o diesel e a comissão do motorista.'),
    p.valor('Diesel', reais(r.totalAbastecimento)),
    p.valor('Gastos avulsos', reais(r.totalGastos)),
    p.valor('Comissão do motorista', reais(r.comissaoDoCaminhao)),
    p.bloco('CUSTO TOTAL DO CAMINHÃO NO PERÍODO', reais(total),
        '${dinheiro(r.totalAbastecimento)} + ${dinheiro(r.totalGastos)} + ${dinheiro(r.comissaoDoCaminhao)}'),
    if (r.totalFretes > 0)
      pw.Text('Entrou de frete ${reais(r.totalFretes)} no mesmo período. Sobrou para o caminhão ${reais(r.sobraDoCaminhao)}.',
          style: p.t(10.5, negrito: true)),
  ];
}

/// Resumo de quem trabalha por viagem (Baú, Sider): viagens, entregas, gastos,
/// vales e, quando há, o acerto fechado pelo gestor.
List<pw.Widget> _resumoViagens(_Pdf p, DadosRelatorio d) {
  final r = d.resultado;
  final regras = d.regras;
  final a = d.acerto;
  final entregas = d.viagens.fold<int>(0, (s, v) => s + v.entregasQuantidade);
  final emAndamento = d.viagens.where((v) => v.emAndamento).length;
  final w = <pw.Widget>[p.titulo(a != null ? 'Acerto do período' : 'Resumo do período')];
  w.add(p.valor('Viagens', '${d.viagens.length}'));
  w.add(p.nota(
    '${plural(entregas, 'entrega', 'entregas')}${emAndamento > 0 ? '   |   ${plural(emAndamento, 'em andamento', 'em andamento')}' : ''}',
    recuo: 8,
  ));
  if (a == null) {
    w.add(p.valor('Total gasto', reais(r.totalGastoGeral)));
    w.add(p.nota('Diesel ${reais(r.totalAbastecimento)}   |   Outros gastos ${reais(r.totalGastos)}', recuo: 8, abaixo: 1));
    w.add(p.nota(
      regras.gastosDescontamDoLiquido
          ? 'Pago pelo motorista. Desconta do acerto.'
          : 'Pago pela empresa. Não desconta do acerto do motorista.',
      recuo: 8,
    ));
    w.add(p.valor('Total de vale', reais(r.totalVale)));
    w.add(p.nota(
      regras.valeDescontaDoLiquido ? 'Já adiantado ao motorista. Desconta do acerto.' : 'Só histórico. Não desconta do acerto.',
      recuo: 8,
    ));
    w.add(p.nota('A comissão entra no acerto que o gestor fecha. Este período ainda não tem acerto fechado.',
        cor: _tintaLaranja, tamanho: 10));
    return w;
  }
  w.add(p.valor('Comissão', reais(a.comissaoCentavos)));
  for (final x in a.descontos) {
    w.add(p.item('( - ) ${x.descricao}', reais(x.valorCentavos)));
  }
  if (a.totalDescontosCentavos > 0) w.add(p.valor('( - ) Descontos', reais(a.totalDescontosCentavos)));
  w.add(p.valor(a.descontaVales ? '( - ) Vales' : 'Vales', reais(a.valesCentavos)));
  w.add(p.nota(a.descontaVales ? 'Já adiantado ao motorista. Desconta do acerto.' : 'Só histórico. Não desconta do acerto.',
      recuo: 8));
  w.add(p.valor(a.descontaGastos ? '( - ) Diesel e gastos' : 'Diesel e gastos', reais(a.dieselCentavos + a.gastosCentavos)));
  w.add(p.nota('Diesel ${reais(a.dieselCentavos)}   |   Outros gastos ${reais(a.gastosCentavos)}', recuo: 8, abaixo: 1));
  w.add(p.nota(
    a.descontaGastos ? 'Pago pelo motorista. Desconta do acerto.' : 'Pago pela empresa. Não desconta do acerto.',
    recuo: 8,
  ));
  w.add(p.bloco('VALOR A RECEBER', reais(a.paraReceberCentavos), contaDoAcerto(a),
      cor: a.paraReceberCentavos < 0 ? _tintaVermelha : _tintaVerde,
      fundo: a.paraReceberCentavos < 0 ? _fundoVermelho : _fundoVerde));
  if ((a.observacao ?? '').trim().isNotEmpty) w.add(p.nota('Observação: ${a.observacao!.trim()}', tamanho: 10));
  if (a.fechadoEm != null) {
    w.add(p.nota('Acerto fechado em ${dataHoraTexto(a.fechadoEm!)}. Vales, diesel e gastos somados no fechamento.',
        tamanho: 9));
  }
  return w;
}

List<pw.Widget> _viagens(_Pdf p, DadosRelatorio d) {
  final lista = d.viagens;
  final w = <pw.Widget>[p.titulo('Viagens (${lista.length})')];
  if (lista.isEmpty) return w..add(p.nota('Nenhuma viagem neste período.', tamanho: 11));
  for (final v in lista) {
    final linhas = <pw.Widget>[
      pw.Text('${dataTexto(v.engateEm)}   ${v.rota}${p.placaDaLinha(v.caminhaoId)}', style: p.t(12, negrito: true)),
      p.nota(
        'Carreta ${placaTexto(v.placaCarreta)}   Engatou ${dataHoraTexto(v.engateEm)}'
        '${v.emAndamento ? '   Em andamento' : '   Desengatou ${dataHoraTexto(v.desengateEm!)}'}',
        recuo: 8,
        tamanho: 10,
        abaixo: 1,
      ),
      if (v.entregasQuantidade > 0 || v.entregasCidades.isNotEmpty)
        p.nota(
          '${plural(v.entregasQuantidade, 'entrega', 'entregas')}'
          '${v.entregasCidades.isEmpty ? '' : ': ${v.entregasCidades.join(', ')}'}',
          recuo: 8,
          tamanho: 10,
          abaixo: 1,
          cor: _tintaVerde,
        ),
      if ((v.observacao ?? '').trim().isNotEmpty) p.nota('Obs.: ${v.observacao!.trim()}', recuo: 8, tamanho: 10, abaixo: 1),
      for (final l in linhasDosExtras(v.extras, d.modalidade)) p.nota(l, recuo: 8, tamanho: 10, abaixo: 1),
      pw.SizedBox(height: 8),
    ];
    w.add(pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: linhas));
  }
  return w;
}

List<pw.Widget> _fretes(_Pdf p, List<Frete> lista, Modalidade? modalidade) {
  final w = <pw.Widget>[p.titulo('Fretes (${lista.length})')];
  if (lista.isEmpty) return w..add(p.nota('Nenhum frete neste período.', tamanho: 11));
  final ordenados = List<Frete>.from(lista)..sort((a, b) => a.dataCarga.compareTo(b.dataCarga));
  for (final f in ordenados) {
    final linhas = <pw.Widget>[
      pw.Text('${dataTexto(f.dataCarga)}   ${f.origem} para ${f.destino}${p.placaDaLinha(f.caminhaoId)}',
          style: p.t(12, negrito: true)),
      if (f.embarcador.trim().isNotEmpty) p.nota(f.embarcador, recuo: 8, tamanho: 10, abaixo: 1),
      if (f.pesoCargaKg > 0)
        p.nota(
            'Carregou ${toneladas(f.pesoCargaKg)} t${f.pesoDescargaKg > 0 ? '   Descarregou ${toneladas(f.pesoDescargaKg)} t' : ''}',
            recuo: 8,
            tamanho: 10,
            abaixo: 1),
    ];
    final q = f.quebraKg;
    if (q != null) {
      final desc = f.descontoQuebraCentavos > 0
          ? '   Descontado no acerto: ${reais(f.descontoQuebraCentavos)} (integral daria ${reais(f.valorQuebraIntegralCentavos)})'
          : '   Não foi descontado';
      linhas.add(p.nota('Quebra de ${semCasas(q)} kg$desc', recuo: 8, tamanho: 10, abaixo: 1, cor: _tintaLaranja));
    }
    linhas.add(p.nota(
      'Adiantamento ${reais(f.adiantamentoCentavos)}   Saldo ${f.saldoCentavos > 0 ? reais(f.saldoCentavos) : 'em aberto'}'
      '${f.pedagioCentavos > 0 ? '   Pedágio ${reais(f.pedagioCentavos)}' : ''}',
      recuo: 8,
      tamanho: 10,
      abaixo: 1,
    ));
    linhas.add(p.nota(
      'Frete real ${reais(f.freteRealCentavos)}   Comissão ${percentualTexto(f.percentualComissao)}% sobre '
      '${reais(f.baseComissaoCentavos)} = ${reais(f.minhaParteCentavos)}'
      '${f.pedagioCentavos > 0 && f.comissaoSobreBruto ? ' (com pedágio)' : ''}',
      recuo: 8,
      tamanho: 10,
      cor: _tintaVerde,
      abaixo: f.ajustado ? 1 : 10,
    ));
    for (final l in linhasDosExtras(f.extras, modalidade)) {
      linhas.add(p.nota(l, recuo: 8, tamanho: 10, abaixo: 1));
    }
    if (f.ajustado) {
      linhas.add(p.nota('* ${textoCamposAjustados(f.camposAjustados)}', recuo: 8, tamanho: 9, cor: _tintaLaranja, abaixo: 10));
    }
    w.add(pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: linhas));
  }
  return w;
}

List<pw.Widget> _abastecimentos(_Pdf p, List<Abastecimento> lista, List<Abastecimento> todas) {
  final doPeriodo = lista.where((a) => !a.pontoDePartida).toList()
    ..sort((a, b) {
      final c = a.caminhaoId.compareTo(b.caminhaoId);
      return c != 0 ? c : a.km.compareTo(b.km);
    });
  final w = <pw.Widget>[p.titulo('Diesel (${doPeriodo.length})')];
  if (doPeriodo.isEmpty) return w..add(p.nota('Nenhuma abastecida neste período.', tamanho: 11));
  var total = 0.0;
  var litros = 0.0;
  for (final a in doPeriodo) {
    total += a.valorCentavos;
    litros += a.litros;
    final m = mediaDaLinha(todas, a);
    final media = m.media;
    w.add(pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('${dataTexto(a.data)}   km ${semCasas(a.km)}   ${a.cidade}${p.placaDaLinha(a.caminhaoId)}',
            style: p.t(12, negrito: true)),
        if (a.posto.trim().isNotEmpty) p.nota(a.posto, recuo: 8, tamanho: 10, abaixo: 1),
        p.nota(
          '${umaCasa(a.litros)} litros   ${reais(a.valorCentavos)}   ${a.tanqueCheio ? 'tanque cheio' : 'tanque não completado'}'
          '${media != null ? '   média ${umaCasa(media)} km/L' : ''}',
          recuo: 8,
          tamanho: 10,
          cor: media != null ? _tintaVerde : _tintaCinza,
          abaixo: a.ajustado ? 1 : 9,
        ),
        if (a.ajustado)
          p.nota('* ${textoCamposAjustados(a.camposAjustados)}', recuo: 8, tamanho: 9, cor: _tintaLaranja, abaixo: 9),
      ],
    ));
  }
  w.add(p.valor('Total abastecido', reais(total)));
  w.add(p.nota('${umaCasa(litros)} litros no período', recuo: 8));
  return w;
}

List<pw.Widget> _vales(_Pdf p, List<Vale> lista, double total) {
  final w = <pw.Widget>[p.titulo('Vales (${lista.length})')];
  if (lista.isEmpty) return w..add(p.nota('Nenhum vale neste período.', tamanho: 11));
  final ordenados = List<Vale>.from(lista)..sort((a, b) => a.data.compareTo(b.data));
  for (final v in ordenados) {
    final obs = (v.observacao ?? '').trim();
    w.add(p.item('${dataTexto(v.data)}${obs.isEmpty ? '' : '   $obs'}${v.ajustado ? '   *corrigido' : ''}',
        reais(v.valorCentavos)));
  }
  w.add(p.valor('Total de vale', reais(total)));
  return w;
}

List<pw.Widget> _gastos(_Pdf p, List<Gasto> lista, double total) {
  final w = <pw.Widget>[p.titulo('Gastos (${lista.length})')];
  if (lista.isEmpty) return w..add(p.nota('Nenhum gasto neste período.', tamanho: 11));
  final ordenados = List<Gasto>.from(lista)..sort((a, b) => a.data.compareTo(b.data));
  for (final g in ordenados) {
    final obs = (g.observacao ?? '').trim();
    w.add(p.item(
        '${dataTexto(g.data)}   ${g.categoriaNome}${obs.isEmpty ? '' : ' ($obs)'}${p.placaDaLinha(g.caminhaoId)}'
        '${g.ajustado ? '   *corrigido' : ''}',
        reais(g.valorCentavos)));
  }
  w.add(p.valor('Total de gastos', reais(total)));
  return w;
}

List<pw.Widget> _ajustesKm(_Pdf p, List<AjusteKm> lista) {
  if (lista.isEmpty) return [];
  final ordenados = List<AjusteKm>.from(lista)..sort((a, b) => b.quando.compareTo(a.quando));
  return [
    p.titulo('Ajustes do km inicial'),
    p.nota('Toda vez que o km inicial foi alterado fica registrado aqui, com data, hora e motivo.', abaixo: 8),
    for (final a in ordenados)
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          p.nota('${dataHoraTexto(a.quando)}${p.placaDaLinha(a.caminhaoId)}', abaixo: 1),
          pw.Padding(
            padding: const pw.EdgeInsets.only(left: 8),
            child: pw.Text('km ${semCasas(a.kmAnterior)} alterado para ${semCasas(a.kmNovo)}',
                style: p.t(11, negrito: true, numero: true)),
          ),
          p.nota('Motivo: ${a.motivo}', recuo: 8, tamanho: 10, abaixo: 8),
        ],
      ),
  ];
}

List<pw.Widget> _avisoAjustes(_Pdf p, DadosRelatorio d) {
  final algum = d.fretes.any((f) => f.ajustado) ||
      d.abastecimentos.any((a) => a.ajustado) ||
      d.gastos.any((g) => g.ajustado) ||
      d.vales.any((v) => v.ajustado);
  if (!algum) return [];
  return [
    pw.SizedBox(height: 10),
    p.nota('* Valores marcados foram corrigidos pelo gestor. As contas acima já usam o valor corrigido; o '
        'lançamento original do motorista continua guardado no histórico.', cor: _tintaLaranja, tamanho: 9),
  ];
}

// ----------------------------------------------------------------- paradas

/// Relatório de paradas de um motorista no período. Leva no pé de cada
/// página que é registro interno e não substitui o tacógrafo.
Future<Uint8List> gerarPdfParadas(DadosParadas d, FontesPdf fontes, {DateTime? agora}) async {
  final p = _Pdf(fontes);
  final quando = agora ?? DateTime.now();
  final doc = pw.Document(title: d.empresa.isEmpty ? nomeDoProduto : d.empresa, author: nomeDoProduto);
  final conteudo = _conteudoParadas(p, d, quando);

  final rodape = d.empresa.isEmpty ? nomeDoProduto : '${d.empresa}  |  $nomeDoProduto';
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 36, 40, 36),
      maxPages: 200,
      theme: pw.ThemeData.withFont(base: fontes.normal, bold: fontes.negrito),
      footer: (ctx) => pw.Container(
        margin: const pw.EdgeInsets.only(top: 10),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
          pw.Text(avisoParadas, style: p.t(9, cor: _tintaLaranja, negrito: true)),
          pw.SizedBox(height: 2),
          pw.Text('$rodape  |  página ${ctx.pageNumber} de ${ctx.pagesCount}',
              style: p.t(8.5, cor: _tintaCinza), textAlign: pw.TextAlign.right),
        ]),
      ),
      build: (ctx) => conteudo,
    ),
  );
  return doc.save();
}

/// As paradas (cabeçalho, resumo, acima do limite e a lista), para o PDF
/// delas ou para o arquivo de dados.
List<pw.Widget> _conteudoParadas(_Pdf p, DadosParadas d, DateTime quando, {bool avisoNoFim = false}) {
  final r = d.resumo;
  var marca = d.empresa.isEmpty ? 'Gestão de Frota' : d.empresa;
  if (marca.length > 28) marca = '${marca.substring(0, 27)}…';

  final conteudo = <pw.Widget>[
    pw.Row(children: [
      pw.Container(
        padding: const pw.EdgeInsets.fromLTRB(10, 5, 10, 5),
        decoration: const pw.BoxDecoration(
          color: _verdePlaca,
          borderRadius: pw.BorderRadius.all(pw.Radius.circular(5)),
        ),
        child: pw.Text(marca, style: p.t(16, cor: PdfColors.white, negrito: true, numero: true)),
      ),
      pw.SizedBox(width: 12),
      pw.Expanded(child: pw.Text('Relatório de paradas', style: p.t(12.5, cor: _tintaCinza))),
    ]),
    pw.SizedBox(height: 10),
    pw.Container(
      width: double.infinity,
      color: _fundoCaixa,
      padding: const pw.EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(flex: 5, child: _campoCaixa(p, 'Período', '${dataTexto(d.periodo.inicio)}  a  ${dataTexto(d.periodo.fim)}')),
        if (d.motorista.isNotEmpty) pw.Expanded(flex: 5, child: _campoCaixa(p, 'Motorista', d.motorista)),
      ]),
    ),
    pw.SizedBox(height: 4),
    p.nota('Gerado em ${dataHoraTexto(quando)}', tamanho: 9),
    p.titulo('Resumo do período'),
    p.valor('Paradas registradas', '${r.paradas.length}'),
    p.valor('Tempo parado', duracaoTexto(r.tempoParado)),
    p.valor('Tempo de descanso (refeição, descanso e pernoite)', duracaoTexto(r.tempoDescanso)),
    if (r.limiteMinutos != null) p.valor('Limite sem descanso da empresa', limiteTexto(r.limiteMinutos!)),
  ];

  final maior = r.maior;
  if (maior == null) {
    conteudo.add(p.nota(
      r.temDescanso
          ? 'Não há intervalo sem descanso para medir neste período.'
          : 'Nenhum descanso registrado neste período; não dá para medir o intervalo sem descanso.',
      tamanho: 10.5,
    ));
  } else {
    final acima = maior.acimaDoLimite;
    conteudo.add(p.bloco(
      acima ? 'MAIOR INTERVALO SEM DESCANSO (ACIMA DO LIMITE)' : 'MAIOR INTERVALO SEM DESCANSO',
      duracaoTexto(maior.duracao),
      textoDoIntervalo(maior),
      cor: acima ? _tintaVermelha : _tintaVerde,
      fundo: acima ? _fundoVermelho : _fundoVerde,
    ));
  }

  if (r.semRegistro.isNotEmpty) {
    conteudo.add(p.nota(
      '${r.semRegistro.length == 1 ? 'Um intervalo' : '${r.semRegistro.length} intervalos'} de mais de um dia sem '
      'descanso registrado (folga ou registro esquecido) não ${r.semRegistro.length == 1 ? 'entra' : 'entram'} na conta: '
      '${r.semRegistro.map(textoDoIntervalo).join('; ')}.',
      tamanho: 9.5,
    ));
  }

  final acima = r.acimaDoLimite;
  if (acima.isNotEmpty) {
    conteudo.add(p.titulo('Acima do limite (${acima.length})'));
    for (final i in acima) {
      conteudo.add(p.item(textoDoIntervalo(i), duracaoTexto(i.duracao)));
    }
  }

  conteudo.add(p.titulo('Paradas (${r.paradas.length})'));
  if (r.paradas.isEmpty) {
    conteudo.add(p.nota('Nenhuma parada registrada neste período.', tamanho: 10.5));
  } else {
    pw.Widget cel(String texto, {bool negrito = false, PdfColor cor = _tintaEscura, bool direita = false}) => pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(4, 3, 4, 3),
          child: pw.Text(texto,
              style: p.t(9.5, negrito: negrito, cor: cor, numero: !negrito),
              textAlign: direita ? pw.TextAlign.right : pw.TextAlign.left),
        );
    final descanso = {for (final m in d.motivos) if (m.contaComoDescanso) m.codigo};
    final variosCaminhoes = {for (final x in r.paradas) x.caminhaoId}.length > 1;
    conteudo.add(pw.Table(
      columnWidths: const {
        0: pw.FlexColumnWidth(1.6),
        1: pw.FlexColumnWidth(3.4),
        2: pw.FlexColumnWidth(1.2),
        3: pw.FlexColumnWidth(1.6),
        4: pw.FlexColumnWidth(1.3),
      },
      border: const pw.TableBorder(horizontalInside: pw.BorderSide(color: _fundoCaixa, width: 0.8)),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _fundoCaixa),
          children: [
            cel('Dia', negrito: true),
            cel('Motivo', negrito: true),
            cel('Início', negrito: true),
            cel('Fim', negrito: true),
            cel('Duração', negrito: true, direita: true),
          ],
        ),
        for (final x in r.paradas)
          pw.TableRow(children: [
            cel('${dataTexto(x.inicioEm)} ${diaSemana(x.inicioEm)}'),
            cel([
              nomeDoMotivo(x.motivo, d.motivos),
              if (x.descricao != null && x.descricao!.isNotEmpty) x.descricao!,
              if (descanso.contains(x.motivo)) '(descanso)',
              if (x.ajustado) '(horário informado depois)',
              if (variosCaminhoes && d.placaDe(x.caminhaoId).isNotEmpty) d.placaDe(x.caminhaoId),
            ].join('  ')),
            cel(horaTexto(x.inicioEm)),
            cel(x.fimEm == null
                ? 'em andamento'
                : (dataTexto(x.fimEm!) == dataTexto(x.inicioEm)
                    ? horaTexto(x.fimEm!)
                    : '${diaMes(x.fimEm!)} ${horaTexto(x.fimEm!)}')),
            cel(duracaoTexto(x.duracao(quando)), direita: true),
          ]),
      ],
    ));
  }

  // No arquivo de dados o rodapé é outro: o aviso vai no fim das paradas.
  if (avisoNoFim) conteudo.add(p.nota(avisoParadas, cor: _tintaLaranja, tamanho: 9.5));
  return conteudo;
}

// ---------------------------------------------------------- arquivo de dados

/// Todos os dados (da empresa ou de um motorista) num PDF só, para a empresa
/// guardar antes da exclusão: caminhões e, para cada motorista, o cadastro, o
/// relatório de todo o período, os acertos e as paradas.
Future<Uint8List> gerarPdfArquivo(DadosArquivo d, FontesPdf fontes, {DateTime? agora}) async {
  final quando = agora ?? DateTime.now();
  final p = _Pdf(fontes);
  final doc = pw.Document(title: 'Arquivo de dados - ${d.empresa}', author: nomeDoProduto);
  var marca = d.empresa.isEmpty ? 'Gestão de Frota' : d.empresa;
  if (marca.length > 28) marca = '${marca.substring(0, 27)}…';

  final conteudo = <pw.Widget>[
    pw.Row(children: [
      pw.Container(
        padding: const pw.EdgeInsets.fromLTRB(10, 5, 10, 5),
        decoration: const pw.BoxDecoration(
          color: _verdePlaca,
          borderRadius: pw.BorderRadius.all(pw.Radius.circular(5)),
        ),
        child: pw.Text(marca, style: p.t(16, cor: PdfColors.white, negrito: true, numero: true)),
      ),
      pw.SizedBox(width: 12),
      pw.Expanded(
        child: pw.Text(d.daEmpresaToda ? 'Arquivo de todos os dados da empresa' : 'Arquivo de todos os dados do motorista',
            style: p.t(12.5, cor: _tintaCinza)),
      ),
    ]),
    pw.SizedBox(height: 12),
    p.bloco(
      'GUARDE ESTE ARQUIVO',
      d.daEmpresaToda ? d.empresa : (d.motoristas.isEmpty ? '' : d.motoristas.first.nome),
      'Gerado em ${dataHoraTexto(quando)}, antes da exclusão. Depois de excluídos, os dados não podem ser recuperados.',
      cor: _tintaLaranja,
      fundo: _fundoAmarelo,
    ),
    if (d.daEmpresaToda) p.valor('Caminhões', '${d.caminhoes.length}'),
    p.valor('Motoristas', '${d.motoristas.length}'),
    for (final m in d.motoristas)
      p.item('${m.nome}${m.ativo ? '' : ' (desligado)'}', _semNada(m) ? 'sem lançamentos' : m.relatorio.periodo.texto),
  ];

  if (d.caminhoes.isNotEmpty) {
    conteudo.add(p.titulo('Caminhões (${d.caminhoes.length})'));
    for (final c in d.caminhoes) {
      conteudo.add(p.item(
        [
          placaTexto(c.placa),
          if ((c.numeroFrota ?? '').isNotEmpty) 'frota ${c.numeroFrota}',
          if (c.modelo.isNotEmpty) c.modelo,
          if (c.ano != null) '${c.ano}',
        ].join('  ·  '),
        c.ativo ? (c.confirmado ? 'em uso' : 'para conferir') : 'fora de uso',
      ));
    }
  }

  for (final m in d.motoristas) {
    final pm = _Pdf(fontes, m.relatorio);
    conteudo.add(pw.NewPage());
    conteudo.add(p.titulo('Motorista: ${m.nome}'));
    if (m.cpf.isNotEmpty) conteudo.add(p.item('CPF', m.cpf));
    if (m.email.isNotEmpty) conteudo.add(p.item('E-mail', m.email));
    if (m.modalidade.isNotEmpty) conteudo.add(p.item('Modalidade', m.modalidade));
    conteudo.add(p.item('Situação', m.ativo ? 'ativo' : 'desligado'));
    conteudo.add(pw.SizedBox(height: 10));
    if (m.relatorio.vazio) {
      conteudo.add(p.nota('Nenhum frete, viagem, abastecida, gasto ou vale registrado.', tamanho: 10.5));
    } else {
      conteudo.addAll(_conteudoRelatorio(pm, m.relatorio, quando));
    }
    if (m.acertos.isNotEmpty) conteudo.addAll(_acertosDoArquivo(p, m.acertos));
    final paradas = m.paradas;
    if (paradas != null && paradas.resumo.paradas.isNotEmpty) {
      conteudo.add(pw.NewPage());
      conteudo.addAll(_conteudoParadas(p, paradas, quando, avisoNoFim: true));
    }
  }

  final rodape = 'Arquivo de dados  |  ${d.empresa.isEmpty ? nomeDoProduto : '${d.empresa}  |  $nomeDoProduto'}';
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 36, 40, 36),
      maxPages: 2000,
      theme: pw.ThemeData.withFont(base: fontes.normal, bold: fontes.negrito),
      footer: (ctx) => pw.Container(
        alignment: pw.Alignment.centerRight,
        margin: const pw.EdgeInsets.only(top: 10),
        child: pw.Text('$rodape  |  página ${ctx.pageNumber} de ${ctx.pagesCount}', style: p.t(8.5, cor: _tintaCinza)),
      ),
      build: (ctx) => conteudo,
    ),
  );
  return doc.save();
}

bool _semNada(MotoristaNoArquivo m) =>
    m.relatorio.vazio && m.acertos.isEmpty && (m.paradas?.resumo.paradas.isEmpty ?? true);

List<pw.Widget> _acertosDoArquivo(_Pdf p, List<Acerto> acertos) {
  final w = <pw.Widget>[p.titulo('Acertos fechados (${acertos.length})')];
  for (final a in acertos) {
    w.add(p.valor(a.periodoTexto, reais(a.paraReceberCentavos)));
    w.add(p.item('Comissão', reais(a.comissaoCentavos)));
    for (final x in a.descontos) {
      w.add(p.item('Desconto: ${x.descricao}', '- ${reais(x.valorCentavos)}'));
    }
    if (a.descontaVales && a.valesCentavos > 0) w.add(p.item('Vales', '- ${reais(a.valesCentavos)}'));
    if (a.descontaGastos && (a.dieselCentavos + a.gastosCentavos) > 0) {
      w.add(p.item('Diesel e gastos', '- ${reais(a.dieselCentavos + a.gastosCentavos)}'));
    }
    w.add(p.item('Viagens no período', '${a.quantidadeViagens}'));
    if ((a.observacao ?? '').isNotEmpty) w.add(p.item('Observação', a.observacao!));
    if (a.fechadoEm != null) w.add(p.item('Fechado em', dataHoraTexto(a.fechadoEm!)));
  }
  return w;
}
