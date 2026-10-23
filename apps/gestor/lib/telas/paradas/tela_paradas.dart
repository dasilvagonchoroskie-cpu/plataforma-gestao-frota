import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleo/nucleo.dart';
import 'package:visual/visual.dart';

import '../../componentes/comuns.dart';
import '../../dados/provedores.dart';
import '../../relatorio/compartilhar.dart';
import '../casca.dart';

/// Paradas (só quando a empresa liga): cada motorista no período, com o
/// maior intervalo sem descanso e o destaque do que passou do limite.
class TelaParadas extends ConsumerWidget {
  const TelaParadas({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = assistirEquipe(ref);
    final cores = context.cores;
    final periodo = ref.watch(periodoProvider).periodoOuMes;
    final agora = ref.read(relogioProvider)();
    final cfg = e.configParadas;
    final comParadas = {for (final p in e.paradas) p.motoristaId};
    final motoristas = e.motoristas.where((m) => m.ativo || comParadas.contains(m.id)).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Paradas'), actions: acoesPadrao(context, ref)),
      body: ListaCentral(
        largura: 900,
        children: [
          const SizedBox(height: 8),
          const FaixaPeriodo(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Nota(
              'O motorista registra no app quando para e quando volta. Só refeição, descanso e pernoite contam como '
              'descanso.${cfg.limiteMinutos == null ? '' : ' Fica em vermelho o intervalo sem descanso acima de '
                        '${limiteTexto(cfg.limiteMinutos!)} (o limite da empresa, em Configurações).'}',
            ),
          ),
          if (!cfg.ativas)
            const EstadoVazio(
              icone: Icons.pause_circle_outline,
              titulo: 'Registro de paradas desligado',
              texto: 'O dono liga em Configurações > Registro de paradas. Desligado, os motoristas não veem a aba.',
            )
          else if (motoristas.isEmpty)
            const EstadoVazio(
              icone: Icons.badge_outlined,
              titulo: 'Nenhum motorista ainda',
              texto: 'Cadastre os motoristas em Motoristas.',
            )
          else
            for (final m in motoristas)
              () {
                final r = e.resumoParadas(m.id, periodo, agora);
                final maior = r.maior;
                final acima = r.acimaDoLimite.length;
                final aberta = paradaAberta(e.paradasDe(m.id));
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: acima > 0 ? cores.negativo.withValues(alpha: 0.12) : null,
                    child: Icon(
                      aberta != null ? iconeDoMotivo(aberta.motivo) : Icons.badge_outlined,
                      color: acima > 0 ? cores.negativo : null,
                    ),
                  ),
                  title: Text(m.nome, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    [
                      if (aberta != null)
                        'parado agora: ${nomeDoMotivo(aberta.motivo, e.motivosParada).toLowerCase()} '
                            'desde ${horaTexto(aberta.inicioEm)}',
                      plural(r.paradas.length, 'parada', 'paradas'),
                      if (r.paradas.isNotEmpty) 'parado ${duracaoTexto(r.tempoParado)}',
                      if (acima > 0) plural(acima, 'vez acima do limite', 'vezes acima do limite'),
                    ].join('  ·  '),
                    style: TextStyle(color: acima > 0 ? cores.negativo : null),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        maior == null ? '–' : duracaoTexto(maior.duracao),
                        style: estiloNumero(19, cor: maior?.acimaDoLimite == true ? cores.negativo : null),
                      ),
                      Text('maior sem descanso', style: TextStyle(fontSize: 12, color: cores.textoFraco)),
                    ],
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => TelaParadasMotorista(motoristaId: m.id)),
                  ),
                );
              }(),
          const Padding(padding: EdgeInsets.fromLTRB(20, 16, 20, 0), child: Nota(avisoParadas)),
        ],
      ),
    );
  }
}

/// As paradas de um motorista no período.
class TelaParadasMotorista extends ConsumerWidget {
  const TelaParadasMotorista({super.key, required this.motoristaId});
  final String motoristaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = assistirEquipe(ref);
    return Scaffold(
      appBar: AppBar(
        title: Text('Paradas: ${e.motorista(motoristaId)?.primeiroNome ?? ''}'),
        actions: const [BotaoAtualizar(), SizedBox(width: 4)],
      ),
      body: ListaCentral(
        largura: 900,
        children: [
          const SizedBox(height: 8),
          const FaixaPeriodo(),
          CorpoParadasMotorista(motoristaId: motoristaId),
        ],
      ),
    );
  }
}

/// Resumo, botões de PDF e planilha e a lista de paradas do motorista no
/// período (também é a aba Paradas da tela do motorista).
class CorpoParadasMotorista extends ConsumerWidget {
  const CorpoParadasMotorista({super.key, required this.motoristaId});
  final String motoristaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = assistirEquipe(ref);
    final periodo = ref.watch(periodoProvider).periodoOuMes;
    final agora = ref.read(relogioProvider)();
    final d = e.dadosParadas(motoristaId, periodo, agora);
    final r = d.resumo;
    final lista = r.paradas.reversed.toList();
    final grupos = agruparPorDia<Parada>(lista, (p) => p.inicioEm);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Wrap(
            spacing: 10,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              FilledButton.tonalIcon(
                onPressed: () => executar(context, () => compartilharParadas(d, agora: agora)),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('PDF'),
              ),
              OutlinedButton.icon(
                onPressed: () => executar(context, () => compartilharParadas(d, agora: agora, planilha: true)),
                icon: const Icon(Icons.table_chart_outlined),
                label: const Text('Planilha'),
              ),
            ],
          ),
        ),
        Padding(padding: const EdgeInsets.fromLTRB(20, 12, 20, 4), child: CartaoResumoParadas(resumo: r)),
        if (lista.isEmpty)
          const EstadoVazio(
            icone: Icons.pause_circle_outline,
            titulo: 'Nenhuma parada neste período',
            texto: 'Quando o motorista registrar no app, aparece aqui na próxima vez que o celular dele tiver internet.',
          )
        else
          for (final g in grupos) ...[
            CabecalhoMes(titulo: tituloDoDia(g.dia, agora), resumo: plural(g.itens.length, 'parada', 'paradas')),
            for (var i = 0; i < g.itens.length; i++) ...[
              if (i > 0) const Divider(indent: 68, endIndent: 20),
              LinhaParada(
                parada: g.itens[i],
                motivos: e.motivosParada,
                agora: agora,
                placa: {for (final p in lista) p.caminhaoId}.length > 1 ? e.placa(g.itens[i].caminhaoId) : null,
              ),
            ],
          ],
        const SizedBox(height: 24),
      ],
    );
  }
}

/// PDF (para imprimir ou mandar) ou planilha das paradas do motorista.
Future<void> compartilharParadas(DadosParadas d, {required DateTime agora, bool planilha = false}) async {
  final arquivo = planilha
      ? arquivoCsv(nomeDoArquivoParadas(d, extensao: 'csv'), csvParadas(d, agora: agora))
      : Arquivo(nomeDoArquivoParadas(d), await gerarPdfParadas(d, await carregarFontes(), agora: agora), 'application/pdf');
  await compartilharArquivos([arquivo], assunto: 'Paradas de ${d.motorista}');
}
