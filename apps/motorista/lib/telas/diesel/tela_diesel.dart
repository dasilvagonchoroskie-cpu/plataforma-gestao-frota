import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleo/nucleo.dart';
import 'package:visual/visual.dart';

import '../../componentes/comuns.dart';
import '../../dados/dados.dart';
import 'form_abastecimento.dart';
import 'ponto_partida.dart';

/// Diesel do caminhão em uso (a média é sempre de um caminhão só). Dá para
/// olhar os outros caminhões em que o motorista já lançou.
class TelaDiesel extends ConsumerStatefulWidget {
  const TelaDiesel({super.key});

  @override
  ConsumerState<TelaDiesel> createState() => _TelaDieselState();
}

class _TelaDieselState extends ConsumerState<TelaDiesel> {
  String? _caminhao;

  @override
  Widget build(BuildContext context) {
    final dados = assistirDados(ref);
    final cores = context.cores;
    final idsComDiesel = {for (final a in dados.abastecimentos) a.caminhaoId};
    final atual = dados.caminhaoAtualId;
    final escolhido = _caminhao ?? atual ?? (idsComDiesel.isEmpty ? null : idsComDiesel.first);
    final todas = dados.abastecimentos;
    final abastecidas = dados.abastecidasDo(escolhido)
      ..sort((a, b) {
        final c = b.data.compareTo(a.data);
        return c != 0 ? c : b.km.compareTo(a.km);
      });
    final ponto = dados.pontoDePartidaDo(escolhido);
    final grupos = agruparPorMes<Abastecimento>(abastecidas, (a) => a.data);
    final outros = {...idsComDiesel, ?atual}.toList();

    void nova() => Navigator.push(context, MaterialPageRoute(builder: (_) => const FormAbastecimento()));
    void pontoPartida() => Navigator.push(
        context, MaterialPageRoute(builder: (_) => TelaPontoPartida(caminhaoId: escolhido ?? '')));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diesel'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Mais opções',
            onSelected: (v) {
              if (v == 'ponto' && escolhido != null) pontoPartida();
              if (v == 'historico') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => TelaHistoricoKm(caminhaoId: escolhido)));
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'ponto', child: Text('Km inicial (ponto de partida)')),
              PopupMenuItem(value: 'historico', child: Text('Mudanças do km inicial')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'nova_abastecida',
        onPressed: nova,
        icon: const Icon(Icons.add),
        label: const Text('Abastecida'),
      ),
      body: ListView(
        children: [
          const TopoCaminhao(),
          if (outros.length > 1)
            SizedBox(
              height: 56,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                children: [
                  for (final id in outros)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(placaTexto(dados.placaDe(id))),
                        selected: id == escolhido,
                        showCheckmark: false,
                        onSelected: (_) => setState(() => _caminhao = id),
                      ),
                    ),
                ],
              ),
            ),
          if (abastecidas.isEmpty)
            EstadoVazio(
              icone: Icons.local_gas_station_outlined,
              titulo: ponto == null ? 'Comece pelo km da última abastecida' : 'Nenhuma abastecida ainda',
              texto: ponto == null
                  ? 'Se você tem anotado o km da última vez que encheu o tanque deste caminhão, coloque como ponto de '
                      'partida. Assim a média já sai certa na primeira abastecida.'
                  : 'Ponto de partida no km ${semCasas(ponto.km)}. Na próxima vez que encher o tanque, '
                      'anote aqui e a média aparece.',
              acao: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  if (ponto == null && escolhido != null)
                    OutlinedButton(onPressed: pontoPartida, child: const Text('Informar km inicial')),
                  FilledButton.icon(onPressed: nova, icon: const Icon(Icons.add), label: const Text('Anotar abastecida')),
                ],
              ),
            )
          else ...[
            for (final g in grupos) ...[
              CabecalhoMes(titulo: g.titulo, resumo: _resumoMes(g.itens, todas)),
              for (var i = 0; i < g.itens.length; i++) ...[
                if (i > 0) const Divider(indent: 20, endIndent: 20),
                LinhaAbastecida(item: g.itens[i], todas: todas, dados: dados),
              ],
            ],
            if (ponto != null) ...[
              const CabecalhoMes(titulo: 'Ponto de partida', resumo: ''),
              ListTile(
                leading: Icon(Icons.flag_outlined, color: cores.textoFraco),
                title: Text('km ${semCasas(ponto.km)}', style: estiloNumero(18)),
                subtitle: Text('${dataTexto(ponto.data)}${ponto.cidade.trim().isNotEmpty ? ', ${ponto.cidade}' : ''}. '
                    'Tanque cheio, de onde a média começa a contar.'),
                trailing: const Icon(Icons.edit_outlined),
                onTap: pontoPartida,
              ),
            ],
            espacoFinalLista,
          ],
        ],
      ),
    );
  }

  String _resumoMes(List<Abastecimento> doMes, List<Abastecimento> todas) {
    final total = doMes.fold<double>(0, (s, a) => s + a.valorCentavos);
    final media = mediaDoPeriodo(doMes, todas).media;
    return media == null ? reais(total) : '${umaCasa(media)} km/L   ${reais(total)}';
  }
}

class LinhaAbastecida extends StatelessWidget {
  const LinhaAbastecida({super.key, required this.item, required this.todas, required this.dados});
  final Abastecimento item;
  final List<Abastecimento> todas;
  final EstadoDados dados;

  @override
  Widget build(BuildContext context) {
    final cores = context.cores;
    final a = item;
    final media = mediaDaLinha(todas, a).media;
    final lugar = [a.cidade.trim(), a.posto.trim()].where((s) => s.isNotEmpty).join(', ');
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FormAbastecimento(editando: a))),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 20, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ColunaData(a.data),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(lugar.isEmpty ? 'Abastecida' : lugar,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('km ${semCasas(a.km)}   ${umaCasa(a.litros)} L',
                      style: estiloNumero(16, peso: FontWeight.w500, cor: cores.textoFraco)),
                  const SizedBox(height: 4),
                  MarcasLancamento(pendente: dados.estaPendente(Tabelas.abastecimentos, a.id), ajustado: a.ajustado),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(reais(a.valorCentavos), style: estiloNumero(18)),
                const SizedBox(height: 6),
                if (!a.tanqueCheio)
                  const Etiqueta('Não encheu', atencao: false)
                else if (media != null)
                  Text('${umaCasa(media)} km/L', style: estiloNumero(16, cor: cores.positivo))
                else
                  Text('primeira cheia', style: TextStyle(fontSize: 13.5, color: cores.textoFraco)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
