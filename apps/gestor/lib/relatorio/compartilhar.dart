import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show ByteData, rootBundle;
import 'package:nucleo/nucleo.dart';
import 'package:share_plus/share_plus.dart';

FontesPdf? _fontes;

/// As letras do PDF ficam no pacote nucleo (as mesmas da tela).
Future<FontesPdf> carregarFontes() async {
  if (_fontes != null) return _fontes!;
  final a = FontesPdf.arquivos;
  Future<ByteData> ler(String n) => rootBundle.load('packages/nucleo/fontes/$n');
  return _fontes = FontesPdf.deBytes(await ler(a[0]), await ler(a[1]), await ler(a[2]), await ler(a[3]));
}

/// Arquivo pronto para enviar ou baixar.
class Arquivo {
  const Arquivo(this.nome, this.bytes, this.tipo);
  final String nome;
  final Uint8List bytes;
  final String tipo;
}

/// No celular abre o "compartilhar" (WhatsApp, e-mail...). No computador o
/// navegador baixa os arquivos.
Future<void> compartilharArquivos(List<Arquivo> arquivos, {String assunto = ''}) async {
  await SharePlus.instance.share(
    ShareParams(
      files: [for (final a in arquivos) XFile.fromData(a.bytes, mimeType: a.tipo, name: a.nome)],
      fileNameOverrides: [for (final a in arquivos) a.nome],
      subject: assunto,
    ),
  );
}

Future<Arquivo> arquivoPdf(DadosRelatorio d) async =>
    Arquivo(nomeDoArquivoPdf(d), await gerarPdf(d, await carregarFontes()), 'application/pdf');

Future<void> compartilharPdf(DadosRelatorio d) async {
  final assunto = d.motorista.isNotEmpty && d.motorista != 'Todos'
      ? 'Relatório de ${d.motorista}'
      : 'Relatório da frota';
  await compartilharArquivos([await arquivoPdf(d)], assunto: assunto);
}

/// CSV (abre no Excel e no Google Planilhas) com BOM para os acentos.
Arquivo arquivoCsv(String nome, String conteudo) =>
    Arquivo(nome, Uint8List.fromList(utf8.encode(conteudo)), 'text/csv');
