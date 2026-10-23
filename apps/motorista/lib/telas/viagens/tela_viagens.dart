import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleo/nucleo.dart';
import 'package:visual/visual.dart';

import '../../componentes/comuns.dart';
import '../../dados/dados.dart';
import 'form_viagem.dart';

/// Aba Viagens (Baú e Sider): uma viagem por carreta engatada.
class TelaViagens extends ConsumerWidget {
  const TelaViagens({super.key});

  static void abrir(BuildContext context, ModoViagem modo, {Viagem? viagem}) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => FormViagem(modo: modo, viagem: viagem),
    ),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dados = assistirDados(ref);
    final aberta = dados.viagemEmAndamento;
    final grupos = agruparPorMes<Viagem>(dados.viagens, (v) => v.engateEm);

    return Scaffold(
      appBar: AppBar(title: const Text('Viagens')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'viagem',
        onPressed: () =>
            aberta == null ? abrir(context, ModoViagem.engatar) : abrir(context, ModoViagem.desengatar, viagem: aberta),
        icon: Icon(aberta == null ? Icons.add_link : Icons.link_off),
        label: Text(aberta == null ? 'Engatar carreta' : 'Desengatar'),
      ),
      body: ListView(
        children: [
          const TopoCaminhao(),
          if (aberta != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: CartaoViagemAberta(viagem: aberta),
            ),
          if (dados.viagens.isEmpty)
            EstadoVazio(
              icone: Icons.route_outlined,
              titulo: 'Nenhuma viagem anotada',
              texto:
                  'Quando engatar uma carreta, anote a placa e onde engatou. No desengate, anote até onde levou '
                  'e as entregas.',
              acao: FilledButton.icon(
                onPressed: () => abrir(context, ModoViagem.engatar),
                icon: const Icon(Icons.add_link),
                label: const Text('Engatar a primeira carreta'),
              ),
            )
          else ...[
            for (final g in grupos) ...[
              CabecalhoMes(
                titulo: g.titulo,
                resumo: plural(g.itens.fold<int>(0, (s, v) => s + v.entregasQuantidade), 'entrega', 'entregas'),
              ),
              for (var i = 0; i < g.itens.length; i++) ...[
                if (i > 0) const Divider(indent: 20, endIndent: 20),
                LinhaViagem(viagem: g.itens[i], dados: dados),
              ],
            ],
            espacoFinalLista,
          ],
        ],
      ),
    );
  }
}

/// A carreta engatada agora, com os botões do dia a dia.
class CartaoViagemAberta extends StatelessWidget {
  const CartaoViagemAberta({super.key, required this.viagem});
  final Viagem viagem;

  @override
  Widget build(BuildContext context) {
    final cores = context.cores;
    final v = viagem;
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.link, size: 22),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Carreta engatada', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                ),
                PlacaVeiculo(v.placaCarreta, tamanho: 16),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Desde ${dataHoraTexto(v.engateEm)}${v.engateLocal.isEmpty ? '' : ', em ${v.engateLocal}'}',
              style: TextStyle(fontSize: 15, color: cores.textoFraco),
            ),
            if (v.entregasCidades.isNotEmpty || v.entregasQuantidade > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${plural(v.entregasQuantidade, 'entrega', 'entregas')}'
                  '${v.entregasCidades.isEmpty ? '' : ': ${v.entregasCidades.join(', ')}'}',
                  style: TextStyle(fontSize: 15, color: cores.positivo),
                ),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => TelaViagens.abrir(context, ModoViagem.mudar, viagem: v),
                    child: const Text('Anotar entregas'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => TelaViagens.abrir(context, ModoViagem.desengatar, viagem: v),
                    child: const Text('Desengatar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class LinhaViagem extends StatelessWidget {
  const LinhaViagem({super.key, required this.viagem, required this.dados});
  final Viagem viagem;
  final EstadoDados dados;

  @override
  Widget build(BuildContext context) {
    final cores = context.cores;
    final v = viagem;
    return InkWell(
      onTap: () => TelaViagens.abrir(context, ModoViagem.mudar, viagem: v),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 20, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ColunaData(v.engateEm),
            const SizedBox(width: 12),
            const Padding(padding: EdgeInsets.only(top: 6), child: MarcadorTrajeto(altura: 14)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    v.engateLocal.isEmpty ? 'Engate' : v.engateLocal,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  if (v.emAndamento)
                    const Etiqueta('Em andamento', atencao: false)
                  else
                    Text(
                      v.desengateLocal.isEmpty ? 'Desengate' : v.desengateLocal,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                    ),
                  if (v.entregasCidades.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        v.entregasCidades.join(', '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 14, color: cores.textoFraco),
                      ),
                    ),
                  const SizedBox(height: 4),
                  MarcasLancamento(
                    pendente: dados.estaPendente(Tabelas.viagens, v.id),
                    ajustado: false,
                    placa: v.placaCarreta,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${v.entregasQuantidade}', style: estiloNumero(20)),
                Text(
                  v.entregasQuantidade == 1 ? 'entrega' : 'entregas',
                  style: TextStyle(fontSize: 13.5, color: cores.textoFraco),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
