import 'dart:io';

import 'package:flutter/services.dart' show ByteData, rootBundle;
import 'package:nucleo/nucleo.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

FontesPdf? _fontes;

/// As letras do PDF ficam no pacote nucleo (as mesmas da tela).
Future<FontesPdf> carregarFontes() async {
  if (_fontes != null) return _fontes!;
  final a = FontesPdf.arquivos;
  Future<ByteData> ler(String n) => rootBundle.load('packages/nucleo/fontes/$n');
  return _fontes = FontesPdf.deBytes(await ler(a[0]), await ler(a[1]), await ler(a[2]), await ler(a[3]));
}

/// Gera o PDF, salva e abre o "compartilhar" do Android (WhatsApp, e-mail...).
Future<void> gerarEEnviarPdf(DadosRelatorio d) async {
  final bytes = await gerarPdf(d, await carregarFontes());
  final pasta = Directory('${(await getTemporaryDirectory()).path}/relatorios');
  await pasta.create(recursive: true);
  final nome = nomeDoArquivoPdf(d);
  final arquivo = File('${pasta.path}/$nome');
  await arquivo.writeAsBytes(bytes, flush: true);
  await SharePlus.instance.share(ShareParams(
    files: [XFile(arquivo.path, mimeType: 'application/pdf', name: nome)],
    subject: (d.ehViagem ? 'Acerto da viagem: ${d.viagem}' : 'Relatório do motorista') +
        (d.motorista.isEmpty ? '' : ' - ${d.motorista}'),
  ));
}
