import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleo/nucleo.dart';
import 'package:visual/visual.dart';

import '../../componentes/comuns.dart';

/// Uma viagem do Baú ou do Sider, como o motorista anotou (só para ver).
class TelaDetalheViagem extends ConsumerWidget {
  const TelaDetalheViagem({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = assistirEquipe(ref);
    final v = e.viagem(id);
    if (v == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EstadoVazio(icone: Icons.search_off, titulo: 'Viagem não encontrada', texto: 'Atualize a tela.'),
      );
    }
    final motorista = e.motorista(v.motoristaId);
    final m = e.modalidade(v.modalidade) ?? (motorista == null ? null : e.modalidadeDe(motorista));
    String rotulo(String chave, String padrao) => m?.rotulo(chave, padrao) ?? padrao;
    return Scaffold(
      appBar: AppBar(title: Text('Viagem${m == null ? '' : ' (${m.nome})'}')),
      body: ListaCentral(
        largura: 760,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LinhaValor(rotulo: 'Motorista', valor: e.nomeMotorista(v.motoristaId)),
                LinhaValor(rotulo: 'Cavalo', valor: placaTexto(e.placa(v.caminhaoId))),
                LinhaValor(rotulo: rotulo('placa_carreta', 'Placa da carreta'), valor: placaTexto(v.placaCarreta)),
                const TituloSecao('Engate'),
                LinhaValor(rotulo: rotulo('engate_local', 'Onde engatou'), valor: v.engateLocal.isEmpty ? '—' : v.engateLocal),
                LinhaValor(rotulo: rotulo('engate_em', 'Quando engatou'), valor: dataHoraTexto(v.engateEm)),
                const TituloSecao('Desengate'),
                if (v.emAndamento)
                  const Nota('Em andamento: a carreta ainda está engatada.')
                else ...[
                  LinhaValor(
                    rotulo: rotulo('desengate_local', 'Até onde levou'),
                    valor: v.desengateLocal.isEmpty ? '—' : v.desengateLocal,
                  ),
                  LinhaValor(rotulo: rotulo('desengate_em', 'Quando desengatou'), valor: dataHoraTexto(v.desengateEm!)),
                ],
                const TituloSecao('Entregas'),
                LinhaValor(rotulo: rotulo('entregas_quantidade', 'Quantas entregas'), valor: '${v.entregasQuantidade}'),
                if (v.entregasCidades.isNotEmpty)
                  LinhaValor(rotulo: rotulo('entregas_cidades', 'Cidades das entregas'), valor: v.entregasCidades.join(', ')),
                if ((v.observacao ?? '').trim().isNotEmpty)
                  LinhaValor(rotulo: rotulo('observacao', 'Observação'), valor: v.observacao!.trim()),
                if (v.extras.values.any((x) => !extraVazio(x))) ...[
                  const TituloSecao('Mais informações'),
                  LinhasExtras(extras: v.extras, modalidade: m),
                ],
                const SizedBox(height: 12),
                const Nota('A viagem é anotada pelo motorista. Para corrigir, combine com ele: ele muda no app.'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
