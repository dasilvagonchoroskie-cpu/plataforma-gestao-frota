import 'package:flutter/material.dart';
import 'package:nucleo/nucleo.dart';

import 'basicos.dart';
import 'listas.dart';
import 'tema.dart';

/// Ícone de cada motivo do catálogo (motivo novo usa o ícone de pausa).
IconData iconeDoMotivo(String codigo) => switch (codigo) {
  'cafe' => Icons.coffee_outlined,
  'refeicao' => Icons.restaurant_outlined,
  'descanso' => Icons.airline_seat_recline_normal_outlined,
  'pernoite' => Icons.bedtime_outlined,
  'manutencao' => Icons.build_outlined,
  'abastecimento' => Icons.local_gas_station_outlined,
  'carga' => Icons.inventory_2_outlined,
  'descarga' => Icons.move_to_inbox_outlined,
  'fiscalizacao' => Icons.local_police_outlined,
  'outro' => Icons.more_horiz,
  _ => Icons.pause_circle_outline,
};

/// Grupo de paradas de um mesmo dia.
class GrupoDia<T> {
  GrupoDia(this.dia, this.itens);
  final DateTime dia;
  final List<T> itens;
}

/// Separa a lista (já ordenada da mais nova para a mais velha) por dia.
List<GrupoDia<T>> agruparPorDia<T>(List<T> itens, DateTime Function(T) data) {
  final grupos = <GrupoDia<T>>[];
  for (final item in itens) {
    final d = data(item).toLocal();
    final dia = DateTime(d.year, d.month, d.day);
    if (grupos.isEmpty || grupos.last.dia != dia) grupos.add(GrupoDia<T>(dia, []));
    grupos.last.itens.add(item);
  }
  return grupos;
}

/// "Hoje", "Ontem" ou "seg, 5 out".
String tituloDoDia(DateTime dia, DateTime agora) {
  final hoje = DateTime(agora.year, agora.month, agora.day);
  final d = DateTime(dia.year, dia.month, dia.day);
  if (d == hoje) return 'Hoje';
  if (d == hoje.subtract(const Duration(days: 1))) return 'Ontem';
  return '${diaSemana(d)}, ${diaMes(d)}';
}

/// "11:30 – 12:30", "22:00 – 6 out 05:30" ou "11:30 – agora".
String horarioDaParada(Parada p) {
  final ini = horaTexto(p.inicioEm);
  if (p.fimEm == null) return '$ini – agora';
  final mesmoDia = dataTexto(p.fimEm!) == dataTexto(p.inicioEm);
  return '$ini – ${mesmoDia ? '' : '${diaMes(p.fimEm!)} '}${horaTexto(p.fimEm!)}';
}

/// Uma parada na lista: motivo, horário e duração.
class LinhaParada extends StatelessWidget {
  const LinhaParada({
    super.key,
    required this.parada,
    required this.motivos,
    required this.agora,
    this.pendente = false,
    this.placa,
    this.aoTocar,
  });

  final Parada parada;
  final List<MotivoParada> motivos;
  final DateTime agora;
  final bool pendente;
  final String? placa;
  final VoidCallback? aoTocar;

  @override
  Widget build(BuildContext context) {
    final cores = context.cores;
    final p = parada;
    final descanso = motivos.any((m) => m.codigo == p.motivo && m.contaComoDescanso);
    final descricao = p.descricao ?? '';
    return InkWell(
      onTap: aoTocar,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 20, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: descanso
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.surfaceContainerHigh,
              child: Icon(iconeDoMotivo(p.motivo), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nomeDoMotivo(p.motivo, motivos),
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                  if (descricao.isNotEmpty)
                    Text(descricao, style: TextStyle(fontSize: 14.5, color: cores.textoFraco)),
                  const SizedBox(height: 2),
                  Text(horarioDaParada(p), style: estiloNumero(15, peso: FontWeight.w500, cor: cores.textoFraco)),
                  if (descanso || p.ajustado || pendente || (placa ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if ((placa ?? '').isNotEmpty)
                            Text(placaTexto(placa!), style: estiloNumero(13.5, cor: cores.textoFraco)),
                          if (descanso) const Etiqueta('Descanso', atencao: false),
                          if (p.ajustado) const Etiqueta('Horário informado depois'),
                          if (pendente) const Etiqueta('Não enviado', atencao: false),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            p.emAndamento
                ? Text('parado', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: cores.atencao))
                : Text(duracaoTexto(p.duracao(agora)), style: estiloNumero(18)),
          ],
        ),
      ),
    );
  }
}

/// Resumo do período: tempo parado, tempo de descanso e o maior intervalo
/// sem descanso, em destaque quando passa do limite da empresa.
class CartaoResumoParadas extends StatelessWidget {
  const CartaoResumoParadas({super.key, required this.resumo});
  final ResumoParadas resumo;

  @override
  Widget build(BuildContext context) {
    final cores = context.cores;
    final r = resumo;
    final maior = r.maior;
    final acima = maior?.acimaDoLimite ?? false;
    final acimaTodos = r.acimaDoLimite;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          decoration: BoxDecoration(
            color: acima ? cores.negativo.withValues(alpha: 0.08) : Theme.of(context).colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: acima ? cores.negativo : Theme.of(context).colorScheme.outlineVariant, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                acima ? 'Maior intervalo sem descanso (acima do limite)' : 'Maior intervalo sem descanso',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: acima ? cores.negativo : null),
              ),
              const SizedBox(height: 2),
              if (maior == null)
                Text(
                  r.temDescanso
                      ? 'Ainda não dá para medir neste período.'
                      : 'Nenhum descanso registrado neste período.',
                  style: TextStyle(fontSize: 15.5, color: cores.textoFraco),
                )
              else ...[
                Text(duracaoTexto(maior.duracao), style: estiloNumero(30, peso: FontWeight.w700)),
                Text(textoDoIntervalo(maior), style: TextStyle(fontSize: 14, color: cores.textoFraco)),
              ],
              if (r.limiteMinutos != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Limite da empresa: ${limiteTexto(r.limiteMinutos!)} sem descanso'
                    '${acimaTodos.isEmpty ? '' : '  •  ${plural(acimaTodos.length, 'vez acima', 'vezes acima')}'}',
                    style: TextStyle(fontSize: 13.5, color: acimaTodos.isEmpty ? cores.textoFraco : cores.negativo),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        LinhaValor(rotulo: 'Paradas registradas', valor: '${r.paradas.length}'),
        LinhaValor(rotulo: 'Tempo parado', valor: duracaoTexto(r.tempoParado)),
        LinhaValor(
          rotulo: 'Tempo de descanso',
          detalhe: 'Refeição, descanso e pernoite',
          valor: duracaoTexto(r.tempoDescanso),
        ),
        if (acimaTodos.length > 1) ...[
          const SizedBox(height: 6),
          Text('Acima do limite', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: cores.negativo)),
          for (final i in acimaTodos)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Row(
                children: [
                  Expanded(child: Text(textoDoIntervalo(i), style: TextStyle(fontSize: 14, color: cores.textoFraco))),
                  Text(duracaoTexto(i.duracao), style: estiloNumero(15, cor: cores.negativo)),
                ],
              ),
            ),
        ],
        const SizedBox(height: 8),
        Nota(avisoParadas),
      ],
    );
  }
}
