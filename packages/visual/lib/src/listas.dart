import 'package:flutter/material.dart';

import 'package:nucleo/nucleo.dart';

import 'tema.dart';

/// Grupo de registros de um mesmo mes.
class GrupoMes<T> {
  GrupoMes(this.mes, this.itens);
  final DateTime mes;
  final List<T> itens;
  String get titulo => mesAnoTitulo(mes);
}

/// Separa a lista (ja ordenada da mais nova para a mais velha) por mes.
List<GrupoMes<T>> agruparPorMes<T>(List<T> itens, DateTime Function(T) data) {
  final grupos = <GrupoMes<T>>[];
  for (final item in itens) {
    final d = data(item).toLocal();
    final mes = DateTime(d.year, d.month);
    if (grupos.isEmpty || grupos.last.mes != mes) {
      grupos.add(GrupoMes<T>(mes, []));
    }
    grupos.last.itens.add(item);
  }
  return grupos;
}

/// Coluna da data nas linhas das listas: "12 out" / "qui".
class ColunaData extends StatelessWidget {
  const ColunaData(this.data, {super.key});
  final DateTime data;

  @override
  Widget build(BuildContext context) {
    final d = data.toLocal();
    final cores = context.cores;
    return SizedBox(
      width: 46,
      child: Column(
        children: [
          Text('${d.day}', style: estiloNumero(22, peso: FontWeight.w700)),
          Text(diaMes(d).split(' ').last, style: TextStyle(fontSize: 13, color: cores.textoFraco, height: 1.1)),
        ],
      ),
    );
  }
}

/// Marcador de trajeto: bolinha vazia (origem), linha, bolinha cheia (destino).
class MarcadorTrajeto extends StatelessWidget {
  const MarcadorTrajeto({super.key, this.altura = 20, this.cor});
  final double altura;
  final Color? cor;

  @override
  Widget build(BuildContext context) {
    final c = cor ?? Theme.of(context).colorScheme.primary;
    return Column(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c, width: 2)),
        ),
        Container(width: 2, height: altura, color: c.withValues(alpha: 0.5)),
        Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: c)),
      ],
    );
  }
}

/// Etiqueta pequena (ex.: "Aguardando saldo").
class Etiqueta extends StatelessWidget {
  const Etiqueta(this.texto, {super.key, this.atencao = true});
  final String texto;
  final bool atencao;

  @override
  Widget build(BuildContext context) {
    final cores = context.cores;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: atencao ? cores.atencaoFundo : Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        texto,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: atencao ? cores.atencao : cores.textoFraco),
      ),
    );
  }
}

/// Espaco no fim da lista para o botao flutuante nao cobrir o ultimo item.
const espacoFinalLista = SizedBox(height: 96);
