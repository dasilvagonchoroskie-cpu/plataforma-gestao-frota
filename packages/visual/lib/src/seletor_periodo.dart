import 'package:flutter/material.dart';

import 'package:nucleo/nucleo.dart';

/// Escolha do período (este mês, mês passado, 7/15/30 dias, datas).
class EscolhaPeriodo {
  const EscolhaPeriodo(this.tipo, {this.inicio, this.fim});

  final TipoPeriodo tipo;
  final DateTime? inicio;
  final DateTime? fim;

  Periodo? get periodo => calcularPeriodo(tipo, inicio: inicio, fim: fim);

  /// Nome curto para mostrar ("outubro de 2026", "ultimos 7 dias"...).
  String get descricao {
    final agora = DateTime.now();
    switch (tipo) {
      case TipoPeriodo.mesAtual:
        return mesAno(agora);
      case TipoPeriodo.mesPassado:
        return mesAno(DateTime(agora.year, agora.month - 1, 1));
      case TipoPeriodo.seteDias:
        return 'últimos 7 dias';
      case TipoPeriodo.quinzeDias:
        return 'últimos 15 dias';
      case TipoPeriodo.trintaDias:
        return 'últimos 30 dias';
      case TipoPeriodo.escolher:
        final p = periodo;
        return p == null ? 'escolha as datas' : p.texto;
    }
  }
}

class SeletorPeriodo extends StatelessWidget {
  const SeletorPeriodo({super.key, required this.escolha, required this.aoMudar});

  final EscolhaPeriodo escolha;
  final ValueChanged<EscolhaPeriodo> aoMudar;

  Future<void> _escolherDatas(BuildContext context) async {
    final agora = DateTime.now();
    final atual = escolha.periodo;
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2015),
      lastDate: DateTime(agora.year + 1, 12, 31),
      initialDateRange: atual == null
          ? DateTimeRange(start: DateTime(agora.year, agora.month, 1), end: agora)
          : DateTimeRange(start: atual.inicio, end: atual.fim),
      locale: const Locale('pt', 'BR'),
      helpText: 'De quando até quando',
      saveText: 'Pronto',
      cancelText: 'Cancelar',
    );
    if (r != null) aoMudar(EscolhaPeriodo(TipoPeriodo.escolher, inicio: r.start, fim: r.end));
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (final t in TipoPeriodo.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(t == TipoPeriodo.escolher && escolha.tipo == TipoPeriodo.escolher && escolha.periodo != null
                    ? '${diaMes(escolha.periodo!.inicio)} a ${diaMes(escolha.periodo!.fim)}'
                    : t.rotulo),
                avatar: t == TipoPeriodo.escolher ? const Icon(Icons.date_range, size: 18) : null,
                selected: escolha.tipo == t,
                showCheckmark: false,
                onSelected: (_) {
                  if (t == TipoPeriodo.escolher) {
                    _escolherDatas(context);
                  } else {
                    aoMudar(EscolhaPeriodo(t));
                  }
                },
              ),
            ),
        ],
      ),
    );
  }
}
