import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../dados/equipe.dart';
import '../dados/provedores.dart';
import '../relatorio/compartilhar.dart';
import 'comuns.dart';

/// PDF com todos os dados de um motorista (cadastro, fretes ou viagens, diesel,
/// gastos, vales, acertos e paradas). Devolve se deu certo.
Future<bool> baixarDadosMotorista(BuildContext context, WidgetRef ref, String motoristaId) {
  final agora = ref.read(relogioProvider)();
  final e = ref.read(equipeProvider).requireValue;
  return executar(
    context,
    () => compartilharArquivoDeDados(e.arquivoDeDados(motoristaId: motoristaId, agora: agora), agora),
    sucesso: 'PDF com todos os dados gerado. Guarde o arquivo.',
  );
}

/// PDF com todos os dados da empresa. Com o acesso encerrado ([doServidor]),
/// os dados vêm da exportação do dono (o painel não lê mais nada).
Future<bool> baixarDadosEmpresa(BuildContext context, WidgetRef ref, {bool doServidor = false}) {
  final agora = ref.read(relogioProvider)();
  return executar(
    context,
    () async {
      final Equipe e;
      if (doServidor) {
        final s = ref.read(servidorProvider);
        final tabelas = await s.exportarDadosEmpresa();
        e = Equipe.montar(
          situacao: await s.situacao(),
          tabelas: tabelas,
          pedidos: const [],
          modalidades: tabelas['modalidades'],
          agora: agora,
        );
      } else {
        e = ref.read(equipeProvider).requireValue;
      }
      await compartilharArquivoDeDados(e.arquivoDeDados(agora: agora), agora);
    },
    sucesso: 'PDF com todos os dados da empresa gerado. Guarde o arquivo.',
  );
}

/// Antes de excluir: explica e gera o PDF com tudo. Só segue se o PDF saiu.
Future<bool> primeiroOPdf(
  BuildContext context, {
  required String quem,
  required Future<bool> Function() gerar,
}) async {
  final seguir = await confirmar(
    context,
    titulo: 'Primeiro, o PDF com todos os dados',
    texto:
        'Antes de excluir, o app gera um PDF com todos os dados $quem: cadastro, fretes ou viagens, diesel, gastos, '
        'vales, acertos e paradas. Guarde o arquivo: depois da exclusão não dá para recuperar nada.',
    botao: 'Gerar o PDF',
  );
  if (!seguir || !context.mounted) return false;
  return gerar();
}
