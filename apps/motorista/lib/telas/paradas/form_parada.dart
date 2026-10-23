import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleo/nucleo.dart';
import 'package:visual/visual.dart';

import '../../componentes/comuns.dart';
import '../../dados/dados.dart';

/// Corrigir uma parada já registrada: motivo e horários. Mudou o horário, a
/// parada fica marcada como "horário informado depois" (o patrão vê).
class FormParada extends ConsumerStatefulWidget {
  const FormParada({super.key, required this.parada});
  final Parada parada;

  @override
  ConsumerState<FormParada> createState() => _FormParadaState();
}

class _FormParadaState extends ConsumerState<FormParada> {
  final _descricao = TextEditingController();
  late String _motivo;
  late DateTime _inicio;
  DateTime? _fim;
  final _erros = <String, String>{};

  Parada get _base => widget.parada;

  @override
  void initState() {
    super.initState();
    _motivo = _base.motivo;
    _inicio = _base.inicioEm;
    _fim = _base.fimEm;
    _descricao.text = _base.descricao ?? '';
  }

  @override
  void dispose() {
    _descricao.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    final agora = ref.read(relogioProvider)();
    _erros.clear();
    if (_inicio.isAfter(agora)) _erros['inicio'] = 'A parada não pode começar no futuro.';
    if (_fim != null && _fim!.isBefore(ateOMinuto(_inicio))) {
      _erros['fim'] = 'A saída não pode ser antes da parada (${dataHoraTexto(_inicio)}).';
    } else if (_fim != null && _fim!.isAfter(agora)) {
      _erros['fim'] = 'Esse horário ainda não chegou.';
    }
    setState(() {});
    if (_erros.isNotEmpty) {
      mostrarMensagem(context, 'Confira o que está marcado para salvar.');
      return;
    }
    // Saída no mesmo minuto da parada: fica igual ao começo.
    if (_fim != null && _fim!.isBefore(_inicio)) _fim = _inicio;
    final mudouHorario = !_inicio.isAtSameMomentAs(_base.inicioEm) ||
        (_fim == null) != (_base.fimEm == null) ||
        (_fim != null && _base.fimEm != null && !_fim!.isAtSameMomentAs(_base.fimEm!));
    final p = Parada(
      id: _base.id,
      empresaId: _base.empresaId,
      motoristaId: _base.motoristaId,
      caminhaoId: _base.caminhaoId,
      motivo: _motivo,
      descricao: _motivo == 'outro' ? _descricao.text.trim() : null,
      inicioEm: _inicio,
      fimEm: _fim,
      ajustado: _base.ajustado,
      criadoNoAparelhoEm: _base.criadoNoAparelhoEm,
    );
    await ref.read(dadosProvider.notifier).corrigirParada(p, mudouHorario: mudouHorario);
    if (!mounted) return;
    final mensageiro = ScaffoldMessenger.of(context);
    Navigator.pop(context, true);
    mensageiro
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Parada corrigida.')));
  }

  Future<void> _apagar() async {
    final motivos = ref.read(dadosProvider).value?.info.paradas.motivos ?? const [];
    final ok = await confirmarExclusao(
      context,
      titulo: 'Apagar esta parada?',
      detalhe:
          '${nomeDoMotivo(_base.motivo, motivos)}, ${dataHoraTexto(_base.inicioEm)}. '
          'O seu patrão vai ver que foi apagada.',
    );
    if (!ok || !mounted) return;
    final mensageiro = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    await ref.read(dadosProvider.notifier).apagarParada(_base);
    mensageiro.showSnackBar(const SnackBar(content: Text('Parada apagada.')));
  }

  @override
  Widget build(BuildContext context) {
    final dados = assistirDados(ref);
    final motivos = [
      ...dados.info.paradas.motivosAtivos,
      // Motivo que saiu do catálogo continua aparecendo na parada antiga.
      if (!dados.info.paradas.motivosAtivos.any((m) => m.codigo == _base.motivo))
        MotivoParada(codigo: _base.motivo, nome: nomeDoMotivo(_base.motivo, dados.info.paradas.motivos)),
    ];
    const espaco = SizedBox(height: 14);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Parada'),
        actions: [
          IconButton(tooltip: 'Apagar', icon: const Icon(Icons.delete_outline), onPressed: _apagar),
          const SizedBox(width: 4),
        ],
      ),
      bottomNavigationBar: RodapeBotao(texto: 'Salvar', aoTocar: _salvar),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          if (_base.ajustado)
            const Padding(
              padding: EdgeInsets.only(bottom: 14),
              child: Nota('O horário desta parada foi informado depois (não foi o do toque).'),
            ),
          DropdownButtonFormField<String>(
            initialValue: _motivo,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Motivo'),
            items: [
              for (final m in motivos)
                DropdownMenuItem(
                  value: m.codigo,
                  child: Row(
                    children: [
                      Icon(iconeDoMotivo(m.codigo), size: 22),
                      const SizedBox(width: 10),
                      Flexible(child: Text(m.nome, overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                ),
            ],
            onChanged: (v) => setState(() => _motivo = v ?? _motivo),
          ),
          if (_motivo == 'outro') ...[
            espaco,
            TextField(
              controller: _descricao,
              maxLength: 120,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Qual foi o motivo?'),
            ),
          ],
          espaco,
          CampoDataHora(
            rotulo: 'Parou em',
            valor: _inicio,
            erro: _erros['inicio'],
            aoMudar: (d) => setState(() {
              _inicio = d;
              _erros.remove('inicio');
            }),
          ),
          espaco,
          CampoDataHora(
            rotulo: 'Saiu em',
            valor: _fim,
            textoVazio: 'Ainda parado',
            erro: _erros['fim'],
            aoMudar: (d) => setState(() {
              _fim = d;
              _erros.remove('fim');
            }),
          ),
          if (_fim != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: LinhaValor(rotulo: 'Duração', valor: duracaoTexto(_fim!.difference(_inicio))),
            ),
          espaco,
          if (dados.estaPendente(Tabelas.paradas, _base.id))
            const Nota('Esta parada ainda não foi enviada. Vai quando tiver internet.'),
        ],
      ),
    );
  }
}
