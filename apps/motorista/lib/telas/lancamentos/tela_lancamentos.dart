import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleo/nucleo.dart';
import 'package:visual/visual.dart';

import '../../componentes/comuns.dart';
import '../../dados/dados.dart';
import '../diesel/form_abastecimento.dart';
import '../fretes/detalhe_frete.dart';
import '../gastos/tela_gastos.dart';
import '../inicio/lancar.dart';
import '../vales/tela_vales.dart';
import '../viagens/form_viagem.dart';

/// Um lançamento qualquer na lista única (frete, viagem, diesel, gasto, vale).
class _Item {
  const _Item({
    required this.tipo,
    required this.id,
    required this.tabela,
    required this.data,
    required this.titulo,
    required this.detalhe,
    required this.valor,
    required this.abrir,
    this.placa,
  });

  final Categoria tipo;
  final String id;
  final String tabela;
  final DateTime data;
  final String titulo;
  final String detalhe;
  final String valor;
  final String? placa;
  final Widget Function() abrir;
}

/// Filtro de cima da lista.
enum _Filtro {
  todos('Todos'),
  fretes('Fretes'),
  viagens('Viagens'),
  diesel('Diesel'),
  gastos('Gastos'),
  vales('Vales');

  const _Filtro(this.rotulo);
  final String rotulo;
}

/// Lançamentos: tudo o que o motorista anotou numa lista só, do mais novo
/// para o mais velho, com filtro por tipo.
class TelaLancamentos extends ConsumerStatefulWidget {
  const TelaLancamentos({super.key});

  @override
  ConsumerState<TelaLancamentos> createState() => _TelaLancamentosState();
}

class _TelaLancamentosState extends ConsumerState<TelaLancamentos> {
  var _filtro = _Filtro.todos;

  List<_Item> _itens(EstadoDados d) => [
    for (final f in d.fretes)
      _Item(
        tipo: Categoria.fretes,
        id: f.id,
        tabela: Tabelas.fretes,
        data: f.dataCarga,
        titulo: '${f.origem.isEmpty ? 'Origem' : f.origem}  –  ${f.destino.isEmpty ? 'Destino' : f.destino}',
        detalhe: ['Frete', if (f.embarcador.isNotEmpty) f.embarcador].join(' · '),
        valor: reais(f.freteRealCentavos),
        placa: d.placaDe(f.caminhaoId),
        abrir: () => DetalheFrete(idFrete: f.id),
      ),
    for (final v in d.viagens)
      _Item(
        tipo: Categoria.viagens,
        id: v.id,
        tabela: Tabelas.viagens,
        data: v.engateEm,
        titulo:
            '${v.engateLocal.isEmpty ? 'Engate' : v.engateLocal}  –  ${v.emAndamento ? 'em andamento' : (v.desengateLocal.isEmpty ? 'Desengate' : v.desengateLocal)}',
        detalhe: 'Viagem · carreta ${placaTexto(v.placaCarreta)}',
        valor: plural(v.entregasQuantidade, 'entrega', 'entregas'),
        abrir: () => FormViagem(modo: ModoViagem.mudar, viagem: v),
      ),
    for (final a in d.abastecimentos.where((a) => !a.pontoDePartida))
      _Item(
        tipo: Categoria.diesel,
        id: a.id,
        tabela: Tabelas.abastecimentos,
        data: a.data,
        titulo: ['Diesel', if (a.cidade.isNotEmpty) a.cidade].join(' · '),
        detalhe: [if (a.posto.isNotEmpty) a.posto, '${umaCasa(a.litros)} L'].join(' · '),
        valor: reais(a.valorCentavos),
        placa: d.placaDe(a.caminhaoId),
        abrir: () => FormAbastecimento(editando: a),
      ),
    for (final g in d.gastos)
      _Item(
        tipo: Categoria.gastos,
        id: g.id,
        tabela: Tabelas.gastos,
        data: g.data,
        titulo: g.categoriaNome,
        detalhe: ['Gasto', if ((g.observacao ?? '').isNotEmpty) g.observacao!].join(' · '),
        valor: reais(g.valorCentavos),
        placa: d.placaDe(g.caminhaoId),
        abrir: () => FormGasto(editando: g),
      ),
    for (final v in d.vales)
      _Item(
        tipo: Categoria.vales,
        id: v.id,
        tabela: Tabelas.vales,
        data: v.data,
        titulo: 'Vale',
        detalhe: (v.observacao ?? '').isEmpty ? 'Dinheiro pego adiantado' : v.observacao!,
        valor: reais(v.valorCentavos),
        abrir: () => FormVale(editando: v),
      ),
  ];

  bool _passa(_Item i) => switch (_filtro) {
    _Filtro.todos => true,
    _Filtro.fretes => i.tipo == Categoria.fretes,
    _Filtro.viagens => i.tipo == Categoria.viagens,
    _Filtro.diesel => i.tipo == Categoria.diesel,
    _Filtro.gastos => i.tipo == Categoria.gastos,
    _Filtro.vales => i.tipo == Categoria.vales,
  };

  @override
  Widget build(BuildContext context) {
    final dados = assistirDados(ref);
    final filtros = [
      _Filtro.todos,
      if (dados.porViagem || dados.viagens.isNotEmpty) _Filtro.viagens,
      if (!dados.porViagem || dados.fretes.isNotEmpty) _Filtro.fretes,
      _Filtro.diesel,
      _Filtro.gastos,
      _Filtro.vales,
    ];
    final todos = _itens(dados);
    final itens = todos.where(_passa).toList()..sort((a, b) => b.data.compareTo(a.data));
    // A placa só aparece quando o motorista lançou em mais de um caminhão.
    final variosCaminhoes = {for (final i in todos) if ((i.placa ?? '').isNotEmpty) i.placa}.length > 1;
    final grupos = agruparPorMes<_Item>(itens, (i) => i.data);

    return Scaffold(
      appBar: AppBar(title: const Text('Lançamentos')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'lancar_lista',
        onPressed: () => abrirLancar(context, ref),
        icon: const Icon(Icons.add, size: 28),
        label: const Text('Lançar', style: TextStyle(fontSize: 19)),
      ),
      body: ListView(
        children: [
          const TopoCaminhao(),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                for (final f in filtros)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f.rotulo),
                      selected: _filtro == f,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _filtro = f),
                    ),
                  ),
              ],
            ),
          ),
          if (itens.isEmpty)
            const EstadoVazio(
              icone: Icons.receipt_long_outlined,
              titulo: 'Nada lançado ainda',
              texto: 'Toque em "Lançar" para anotar um frete, uma carreta, o diesel, um gasto ou um vale.',
            )
          else ...[
            for (final g in grupos) ...[
              CabecalhoMes(titulo: g.titulo, resumo: plural(g.itens.length, 'lançamento', 'lançamentos')),
              for (var i = 0; i < g.itens.length; i++) ...[
                if (i > 0) const Divider(indent: 72, endIndent: 20),
                _Linha(
                  item: g.itens[i],
                  comPlaca: variosCaminhoes,
                  pendente: dados.estaPendente(g.itens[i].tabela, g.itens[i].id),
                  ajustado: dados.ajustesDe(g.itens[i].id).isNotEmpty,
                ),
              ],
            ],
            espacoFinalLista,
          ],
        ],
      ),
    );
  }
}

class _Linha extends StatelessWidget {
  const _Linha({required this.item, required this.pendente, required this.ajustado, required this.comPlaca});
  final _Item item;
  final bool comPlaca;
  final bool pendente;
  final bool ajustado;

  @override
  Widget build(BuildContext context) {
    final cores = context.cores;
    final i = item;
    final icone = switch (i.tipo) {
      Categoria.fretes => Icons.local_shipping_outlined,
      Categoria.viagens => Icons.route_outlined,
      Categoria.diesel => Icons.local_gas_station_outlined,
      Categoria.gastos => Icons.receipt_long_outlined,
      _ => Icons.payments_outlined,
    };
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => i.abrir())),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 20, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconeCategoria(icone, i.tipo, tamanho: 42),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    i.titulo,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${dataTexto(i.data)} · ${i.detalhe}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, color: cores.textoFraco),
                  ),
                  if (pendente || ajustado || (comPlaca && (i.placa ?? '').isNotEmpty))
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: MarcasLancamento(pendente: pendente, ajustado: ajustado, placa: comPlaca ? i.placa : null),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(i.valor, style: estiloNumero(17)),
          ],
        ),
      ),
    );
  }
}
