// Arquivo com todos os dados (da empresa ou de um motorista), gerado antes da
// exclusão para a empresa guardar (regra aprovada pelo Evandro em 23/10/2026).

import 'formato.dart';
import 'modalidades.dart';
import 'modelos.dart';
import 'paradas.dart';
import 'regras/dados_relatorio.dart';
import 'regras/periodo.dart';

/// Um motorista dentro do arquivo: o cadastro, o relatório de todo o período,
/// os acertos e as paradas.
class MotoristaNoArquivo {
  const MotoristaNoArquivo({
    required this.nome,
    required this.relatorio,
    this.cpf = '',
    this.email = '',
    this.modalidade = '',
    this.ativo = true,
    this.acertos = const [],
    this.paradas,
  });

  final String nome;
  final String cpf;
  final String email;
  final String modalidade;
  final bool ativo;
  final DadosRelatorio relatorio;
  final List<Acerto> acertos;
  final DadosParadas? paradas;
}

class DadosArquivo {
  const DadosArquivo({
    required this.empresa,
    required this.motoristas,
    this.caminhoes = const [],
    this.daEmpresaToda = true,
  });

  final String empresa;
  final List<MotoristaNoArquivo> motoristas;
  final List<Caminhao> caminhoes;

  /// Falso quando o arquivo é de um motorista só (exclusão do motorista).
  final bool daEmpresaToda;
}

/// Do primeiro registro até hoje (todo o histórico).
Periodo periodoCompleto(Iterable<DateTime> datas, DateTime agora) {
  var inicio = agora;
  for (final d in datas) {
    if (d.isBefore(inicio)) inicio = d;
  }
  return Periodo(inicioDoDia(inicio), fimDoDia(agora));
}

/// "Frota_arquivo_Transportes_X_23-10-2026.pdf" ou "Frota_arquivo_Joao_23-10-2026.pdf".
String nomeDoArquivoDeDados(DadosArquivo d, DateTime agora) {
  final quem = d.daEmpresaToda || d.motoristas.isEmpty ? d.empresa : d.motoristas.first.nome.split(' ').first;
  var nome = semAcento(quem).replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');
  if (nome.length > 40) nome = nome.substring(0, 40);
  return 'Frota_arquivo_${nome.isEmpty ? 'dados' : nome}_${dataTexto(agora).replaceAll('/', '-')}.pdf';
}
