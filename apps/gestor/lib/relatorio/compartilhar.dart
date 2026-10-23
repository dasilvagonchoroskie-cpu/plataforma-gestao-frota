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

typedef Compartilhador = Future<void> Function(List<Arquivo> arquivos, String assunto);

/// Quem entrega os arquivos. Nos testes é trocado por um que só guarda.
Compartilhador compartilhador = _compartilharNoAparelho;

/// No celular abre o "compartilhar" (WhatsApp, e-mail...). No computador o
/// navegador baixa os arquivos.
Future<void> compartilharArquivos(List<Arquivo> arquivos, {String assunto = ''}) =>
    compartilhador(arquivos, assunto);

Future<void> _compartilharNoAparelho(List<Arquivo> arquivos, String assunto) async {
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

/// PDF com todos os dados (da empresa ou de um motorista), antes da exclusão.
Future<void> compartilharArquivoDeDados(DadosArquivo d, DateTime agora) async {
  final bytes = await gerarPdfArquivo(d, await carregarFontes(), agora: agora);
  await compartilharArquivos(
    [Arquivo(nomeDoArquivoDeDados(d, agora), bytes, 'application/pdf')],
    assunto: d.daEmpresaToda ? 'Todos os dados de ${d.empresa}' : 'Todos os dados de ${d.motoristas.first.nome}',
  );
}

/// CSV (abre no Excel e no Google Planilhas) com BOM para os acentos.
Arquivo arquivoCsv(String nome, String conteudo) =>
    Arquivo(nome, Uint8List.fromList(utf8.encode(conteudo)), 'text/csv');
