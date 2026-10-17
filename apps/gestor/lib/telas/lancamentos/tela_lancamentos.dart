import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleo/nucleo.dart';
import 'package:visual/visual.dart';

import '../../componentes/comuns.dart';
import '../../componentes/itens.dart';
import '../../dados/provedores.dart';
import '../casca.dart';

/// Filtros da tela de lançamentos (além do período).
class Filtros {
  const Filtros({this.motoristaId, this.caminhaoId, this.embarcador, this.soCorrigidos = false});
  final String? motoristaId;
  final String? caminhaoId;
  final String? embarcador;
  final bool soCorrigidos;

  Filtros copiar({
    Object? motoristaId = _igual,
    Object? caminhaoId = _igual,
    Object? embarcador = _igual,
    bool? soCorrigidos,
  }) => Filtros(
    motoristaId: motoristaId == _igual ? this.motoristaId : motoristaId as String?,
    caminhaoId: caminhaoId == _igual ? this.caminhaoId : caminhaoId as String?,
    embarcador: embarcador == _igual ? this.embarcador : embarcador as String?,
    soCorrigidos: soCorrigidos ?? this.soCorrigidos,
  );

  bool get algum => motoristaId != null || caminhaoId != null || embarcador != null || soCorrigidos;
}

const _igual = Object();

class FiltrosEscolhidos extends Notifier<Filtros> {
  @override
  Filtros build() => const Filtros();
  void mudar(Filtros f) => state = f;
}

final filtrosProvider = NotifierProvider<FiltrosEscolhidos, Filtros>(FiltrosEscolhidos.new);

/// Todos os lançamentos dos motoristas, com filtro por período, motorista,
/// caminhão e embarcador. Tocar num lançamento abre a correção.
class TelaLancamentos extends ConsumerWidget {
  const TelaLancamentos({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = assistirEquipe(ref);
    final f = ref.watch(filtrosProvider);
    final periodo = ref.watch(periodoProvider).periodoOuMes;
    final l = e.recorte(motoristaId: f.motoristaId, caminhaoId: f.caminhaoId, embarcador: f.embarcador);
    bool ok(DateTime d, bool ajustado) => periodo.contem(d) && (!f.soCorrigidos || ajustado);
    final fretes = l.fretes.where((x) => ok(x.dataCarga, x.ajustado)).toList();
    final abast = l.abastecimentos.where((x) => !x.pontoDePartida && ok(x.data, x.ajustado)).toList();
    final gastos = l.gastos.where((x) => ok(x.data, x.ajustado)).toList();
    final vales = l.vales.where((x) => ok(x.data, x.ajustado)).toList();
    final mudar = ref.read(filtrosProvider.notifier).mudar;

    String total<T>(List<T> itens, num Function(T) v) => reais(itens.fold<num>(0, (s, x) => s + v(x)));

    final filtros = Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Escolha<String>(
            rotulo: 'Motorista',
            valor: f.motoristaId,
            todos: 'Todos',
            itens: {for (final m in e.motoristas) m.id: m.nome},
            aoMudar: (v) => mudar(f.copiar(motoristaId: v)),
          ),
          Escolha<String>(
            rotulo: 'Caminhão',
            valor: f.caminhaoId,
            todos: 'Todos',
            largura: 180,
            itens: {for (final c in e.caminhoes) c.id: placaTexto(c.placa)},
            aoMudar: (v) => mudar(f.copiar(caminhaoId: v)),
          ),
          Escolha<String>(
            rotulo: 'Embarcador',
            valor: f.embarcador,
            todos: 'Todos',
            itens: {for (final x in e.embarcadores) x: x},
            aoMudar: (v) => mudar(f.copiar(embarcador: v)),
          ),
          FilterChip(
            label: const Text('Só corrigidos'),
            selected: f.soCorrigidos,
            onSelected: (v) => mudar(f.copiar(soCorrigidos: v)),
          ),
          if (f.algum)
            TextButton.icon(
              onPressed: () => mudar(const Filtros()),
              icon: const Icon(Icons.filter_alt_off_outlined),
              label: const Text('Limpar'),
            ),
        ],
      ),
    );

    Widget aba(Widget lista) => ListaCentral(largura: 900, children: [lista]);

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Lançamentos'),
          actions: acoesPadrao(context, ref),
          bottom: TabBar(
            isScrollable: !telaLarga(context),
            tabAlignment: telaLarga(context) ? TabAlignment.fill : TabAlignment.start,
            tabs: [
              Tab(text: 'Fretes (${fretes.length})'),
              Tab(text: 'Diesel (${abast.length})'),
              Tab(text: 'Gastos (${gastos.length})'),
              Tab(text: 'Vales (${vales.length})'),
            ],
          ),
        ),
        body: Column(
          children: [
            const SizedBox(height: 8),
            const Centro(largura: 900, child: FaixaPeriodo()),
            Centro(largura: 900, child: filtros),
            if (f.embarcador != null)
              const Centro(
                largura: 900,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 4),
                  child: Nota(
                    'Com embarcador escolhido, diesel e gastos aparecem só quando foram ligados a um frete dele. Vales não entram.',
                  ),
                ),
              ),
            Expanded(
              child: TabBarView(
                children: [
                  aba(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Total('Frete que caiu na conta', total(fretes, (x) => x.freteRealCentavos)),
                        ListaPorMes(
                          itens: fretes,
                          data: (x) => x.dataCarga,
                          valor: (x) => x.freteRealCentavos,
                          item: (x) => ItemFrete(frete: x, equipe: e),
                          vazio: 'Nenhum frete com estes filtros.',
                        ),
                      ],
                    ),
                  ),
                  aba(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Total(
                          'Diesel',
                          total(abast, (x) => x.valorCentavos),
                          detalhe: '${umaCasa(abast.fold<double>(0, (s, x) => s + x.litros))} L',
                        ),
                        ListaPorMes(
                          itens: abast,
                          data: (x) => x.data,
                          valor: (x) => x.valorCentavos,
                          item: (x) => ItemAbastecimento(abastecimento: x, equipe: e),
                          vazio: 'Nenhuma abastecida com estes filtros.',
                        ),
                      ],
                    ),
                  ),
                  aba(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Total('Gastos', total(gastos, (x) => x.valorCentavos)),
                        ListaPorMes(
                          itens: gastos,
                          data: (x) => x.data,
                          valor: (x) => x.valorCentavos,
                          item: (x) => ItemGasto(gasto: x, equipe: e),
                          vazio: 'Nenhum gasto com estes filtros.',
                        ),
                      ],
                    ),
                  ),
                  aba(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Total('Vales', total(vales, (x) => x.valorCentavos)),
                        ListaPorMes(
                          itens: vales,
                          data: (x) => x.data,
                          valor: (x) => x.valorCentavos,
                          item: (x) => ItemVale(vale: x, equipe: e),
                          vazio: f.caminhaoId != null || f.embarcador != null
                              ? 'Vale é do motorista, não do caminhão nem do embarcador. Tire esse filtro para ver os vales.'
                              : 'Nenhum vale com estes filtros.',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Total extends StatelessWidget {
  const _Total(this.rotulo, this.valor, {this.detalhe});
  final String rotulo;
  final String valor;
  final String? detalhe;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
    child: LinhaValor(rotulo: 'Total: $rotulo', valor: valor, detalhe: detalhe, destaque: true),
  );
}
