import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleo/nucleo.dart';
import 'package:visual/visual.dart';

import '../dados/dados.dart';
import '../dados/sincronizador.dart';
import '../telas/acesso/telas_acesso.dart';
import '../telas/caminhao/tela_caminhao.dart';

/// Dados do celular (já carregados quando as abas aparecem).
EstadoDados assistirDados(WidgetRef ref) => ref.watch(dadosProvider).value ?? const EstadoDados();

/// Topo das telas de lançamento: o caminhão em que o motorista está, com
/// o botão para trocar.
class TopoCaminhao extends ConsumerWidget {
  const TopoCaminhao({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = assistirDados(ref);
    final cores = context.cores;
    final c = d.caminhaoAtual;
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TelaTrocarCaminhao())),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 16, 10),
          child: Row(
            children: [
              if (c != null) PlacaVeiculo(c.placa, tamanho: 17) else Icon(Icons.local_shipping_outlined, color: cores.atencao),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c == null ? 'Escolha o seu caminhão' : 'Lançando neste caminhão',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c == null ? cores.atencao : null),
                    ),
                    if (c != null && (c.numeroFrota ?? '').isNotEmpty)
                      Text('Frota ${c.numeroFrota}', style: TextStyle(fontSize: 13.5, color: cores.textoFraco)),
                    if (c != null && !c.confirmado)
                      Text('O gestor ainda vai conferir esta placa', style: TextStyle(fontSize: 13.5, color: cores.atencao)),
                  ],
                ),
              ),
              const Icon(Icons.swap_horiz),
              const SizedBox(width: 4),
              const Text('Trocar', style: TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Linha que diz se está tudo enviado ou quantos itens esperam internet.
class LinhaEnvio extends ConsumerWidget {
  const LinhaEnvio({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = assistirDados(ref);
    final envio = ref.watch(sincronizadorProvider);
    final cores = context.cores;

    if (envio.desligado) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 4),
        child: Aviso(
          icone: Icons.block,
          titulo: 'Acesso desligado',
          texto: 'A empresa desligou o seu acesso ou este celular. Seus lançamentos continuam guardados aqui. '
              'Fale com o seu patrão.',
        ),
      );
    }
    if (envio.precisaEntrar) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
        child: Aviso(
          icone: Icons.login,
          titulo: 'Entre de novo para enviar',
          texto: 'Seus lançamentos estão guardados no celular. Toque aqui para entrar com CPF e senha.',
        ),
      ).comToque(() => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => TelaEntrar(depois: () => ref.read(sincronizadorProvider.notifier).sincronizar())),
          ));
    }

    final String texto;
    final IconData icone;
    Color cor = cores.textoFraco;
    if (envio.ocupado) {
      texto = 'Enviando...';
      icone = Icons.cloud_upload_outlined;
    } else if (d.quantidadePendente == 0) {
      texto = envio.ultimaVez == null
          ? 'Tudo guardado no celular'
          : 'Tudo enviado (${diaMes(envio.ultimaVez!)} às ${envio.ultimaVez!.toLocal().hour.toString().padLeft(2, '0')}:${envio.ultimaVez!.toLocal().minute.toString().padLeft(2, '0')})';
      icone = Icons.cloud_done_outlined;
      cor = cores.positivo;
    } else {
      texto = '${plural(d.quantidadePendente, 'item aguardando', 'itens aguardando')} internet para enviar';
      icone = Icons.cloud_off_outlined;
      cor = cores.atencao;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: envio.ocupado ? null : () => ref.read(sincronizadorProvider.notifier).sincronizar(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Row(
              children: [
                Icon(icone, size: 20, color: cor),
                const SizedBox(width: 8),
                Expanded(child: Text(texto, style: TextStyle(fontSize: 14.5, color: cor, fontWeight: FontWeight.w500))),
                if (!envio.ocupado) Text('Enviar agora', style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
        if (envio.erro != null && d.quantidadePendente > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(48, 0, 20, 6),
            child: Text(envio.erro!, style: TextStyle(fontSize: 13.5, color: cores.textoFraco)),
          ),
        for (final r in d.recusados)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
            child: Aviso(
              icone: Icons.report_outlined,
              titulo: 'Um lançamento não foi aceito',
              texto: '${r.mensagem ?? 'Não foi aceito.'} Toque para dispensar o aviso.',
            ).comToque(() => ref.read(dadosProvider.notifier).dispensarRecusado(r)),
          ),
      ],
    );
  }
}

extension ComToque on Widget {
  Widget comToque(VoidCallback aoTocar) => GestureDetector(onTap: aoTocar, behavior: HitTestBehavior.opaque, child: this);
}

/// Etiqueta dos lançamentos que ainda não chegaram na nuvem ou que o gestor corrigiu.
class MarcasLancamento extends StatelessWidget {
  const MarcasLancamento({super.key, required this.pendente, required this.ajustado, this.placa});
  final bool pendente;
  final bool ajustado;
  final String? placa;

  @override
  Widget build(BuildContext context) {
    final cores = context.cores;
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        if (placa != null && placa!.isNotEmpty)
          Text(placaTexto(placa!), style: estiloNumero(13.5, cor: cores.textoFraco)),
        if (ajustado) const Etiqueta('Corrigido pelo gestor'),
        if (pendente) const Etiqueta('Não enviado', atencao: false),
      ],
    );
  }
}

/// Aviso no formulário quando o gestor já corrigiu o lançamento.
class AvisoAjustado extends StatelessWidget {
  const AvisoAjustado({super.key, required this.ajustes});
  final List<AjusteGestor> ajustes;

  @override
  Widget build(BuildContext context) {
    if (ajustes.isEmpty) return const SizedBox.shrink();
    final linhas = ajustes.map((a) => '${nomeDoCampo(a.campo)}: ${a.motivo}').toSet().join('\n');
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Aviso(
        icone: Icons.verified_user_outlined,
        titulo: 'O seu patrão corrigiu este lançamento',
        texto: '$linhas\nOs valores mostrados já são os corrigidos. Para mudar de novo, fale com ele.',
      ),
    );
  }
}

/// Campo para escolher em qual caminhão fica o lançamento (começa no atual).
class CampoCaminhao extends ConsumerWidget {
  const CampoCaminhao({super.key, required this.valor, required this.aoMudar, this.erro});
  final String? valor;
  final ValueChanged<String> aoMudar;
  final String? erro;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = assistirDados(ref);
    final opcoes = [...d.caminhoesAtivos];
    final atual = d.caminhaoPorId(valor);
    if (atual != null && !opcoes.any((c) => c.id == atual.id)) opcoes.add(atual);
    return DropdownButtonFormField<String>(
      initialValue: opcoes.any((c) => c.id == valor) ? valor : null,
      isExpanded: true,
      decoration: InputDecoration(labelText: 'Caminhão', errorText: erro),
      style: estiloNumero(19, peso: FontWeight.w600, cor: Theme.of(context).colorScheme.onSurface),
      items: [
        for (final c in opcoes)
          DropdownMenuItem(
            value: c.id,
            child: Text('${placaTexto(c.placa)}${(c.numeroFrota ?? '').isEmpty ? '' : '   frota ${c.numeroFrota}'}'),
          ),
      ],
      onChanged: (v) {
        if (v != null) aoMudar(v);
      },
    );
  }
}
