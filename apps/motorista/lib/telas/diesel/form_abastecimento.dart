import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleo/nucleo.dart';
import 'package:visual/visual.dart';

import '../../componentes/comuns.dart';
import '../../dados/dados.dart';
import '../../dados/rascunho.dart';

class FormAbastecimento extends ConsumerStatefulWidget {
  const FormAbastecimento({super.key, this.editando});
  final Abastecimento? editando;

  @override
  ConsumerState<FormAbastecimento> createState() => _FormAbastecimentoState();
}

class _FormAbastecimentoState extends ConsumerState<FormAbastecimento> {
  final _cidade = TextEditingController();
  final _posto = TextEditingController();
  final _litros = TextEditingController();
  final _valor = TextEditingController();
  final _km = TextEditingController();
  late DateTime _data;
  bool _tanqueCheio = true;
  String? _caminhaoId;
  Rascunho? _rascunho;
  final Map<String, String?> _erros = {};

  bool get _novo => widget.editando == null;

  @override
  void initState() {
    super.initState();
    final a = widget.editando;
    _data = inicioDoDia(DateTime.now());
    if (a != null) {
      _data = a.data;
      _cidade.text = a.cidade;
      _posto.text = a.posto;
      _litros.text = textoDecimal(a.litros, casas: 3);
      _valor.text = textoDinheiro(a.valorCentavos);
      _km.text = textoInteiro(a.km);
      _tanqueCheio = a.tanqueCheio;
      _caminhaoId = a.caminhaoId;
    } else {
      _caminhaoId = ref.read(dadosProvider).requireValue.caminhaoAtualId;
      _carregarRascunho();
    }
  }

  Future<void> _carregarRascunho() async {
    final r = Rascunho(ref.read(armazenamentoProvider), 'abastecida');
    _rascunho = r;
    final m = await r.ler();
    if (m.isEmpty || !mounted) return;
    setState(() {
      String s(String k) => (m[k] as String?) ?? '';
      _cidade.text = s('cidade');
      _posto.text = s('posto');
      _litros.text = s('litros');
      _valor.text = s('valor');
      _km.text = s('km');
      final d = DateTime.tryParse(s('data'));
      if (d != null) _data = d;
      final t = m['tanqueCheio'];
      if (t is bool) _tanqueCheio = t;
    });
  }

  void _mudou([String? _]) {
    setState(() => _erros.clear());
    if (_novo) {
      _rascunho?.gravar({
        'cidade': _cidade.text,
        'posto': _posto.text,
        'litros': _litros.text,
        'valor': _valor.text,
        'km': _km.text,
        'data': _data.toIso8601String(),
        'tanqueCheio': _tanqueCheio,
      });
    }
  }

  @override
  void dispose() {
    for (final c in [_cidade, _posto, _litros, _valor, _km]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _salvar() async {
    final litros = lerNumero(_litros.text);
    final km = lerNumero(_km.text);
    setState(() {
      _erros.clear();
      _erros['caminhao'] = _caminhaoId == null ? 'Escolha o caminhão.' : null;
      _erros['cidade'] = _cidade.text.trim().isEmpty ? 'Falta a cidade.' : null;
      _erros['litros'] = litros <= 0 ? 'Faltam os litros.' : null;
      _erros['km'] = km <= 0 ? 'Falta o km do painel.' : null;
    });
    if (_erros.values.any((e) => e != null)) {
      mostrarMensagem(context, 'Confira os campos marcados.');
      return;
    }
    final base = widget.editando;
    final notifier = ref.read(dadosProvider.notifier);
    final d = ref.read(dadosProvider).requireValue;
    final item = base?.copyWith(
          caminhaoId: _caminhaoId,
          data: _data,
          cidade: _cidade.text.trim(),
          posto: _posto.text.trim(),
          litros: litros,
          valorCentavos: lerCentavos(_valor.text),
          kmOdometro: km,
          tanqueCheio: _tanqueCheio,
        ) ??
        Abastecimento(
          id: novoId(),
          motoristaId: d.info.motoristaId ?? '',
          caminhaoId: _caminhaoId!,
          data: _data,
          cidade: _cidade.text.trim(),
          posto: _posto.text.trim(),
          litros: litros,
          valorCentavos: lerCentavos(_valor.text),
          kmOdometro: km,
          tanqueCheio: _tanqueCheio,
          criadoNoAparelhoEm: DateTime.now(),
        );
    await notifier.salvarAbastecimento(item);
    await _rascunho?.limpar();
    if (!mounted) return;
    final mensageiro = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    mensageiro.showSnackBar(SnackBar(content: Text(_novo ? 'Abastecida salva.' : 'Alteração salva.')));
  }

  Future<void> _apagar() async {
    final a = widget.editando!;
    final ok = await confirmarExclusao(
      context,
      titulo: 'Apagar esta abastecida?',
      detalhe: '${dataTexto(a.data)}, ${a.cidade}, km ${semCasas(a.km)}. O seu patrão vai ver que foi apagada.',
    );
    if (!ok || !mounted) return;
    final mensageiro = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    await ref.read(dadosProvider.notifier).apagarAbastecimento(a);
    mensageiro.showSnackBar(const SnackBar(content: Text('Abastecida apagada.')));
  }

  @override
  Widget build(BuildContext context) {
    final dados = assistirDados(ref);
    final cores = context.cores;
    final litros = lerNumero(_litros.text);
    final valor = lerCentavos(_valor.text);
    final km = lerNumero(_km.text);
    final ajustes = _novo ? const <AjusteGestor>[] : dados.ajustesDe(widget.editando!.id);
    final bloqueado = ajustes.isNotEmpty;
    final previa = calcularMedia(
      dados.abastecimentos,
      km: km,
      litros: litros,
      tanqueCheio: _tanqueCheio,
      caminhaoId: _caminhaoId,
      idIgnorar: widget.editando?.id ?? '',
    );
    const espaco = SizedBox(height: 14);

    return Scaffold(
      appBar: AppBar(
        title: Text(_novo ? 'Nova abastecida' : 'Mudar abastecida'),
        actions: [
          if (!_novo && !bloqueado)
            IconButton(tooltip: 'Apagar', icon: const Icon(Icons.delete_outline), onPressed: _apagar),
        ],
      ),
      bottomNavigationBar:
          bloqueado ? null : RodapeBotao(texto: _novo ? 'Salvar abastecida' : 'Salvar alteração', aoTocar: _salvar),
      body: AbsorbPointer(
        absorbing: bloqueado,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            AvisoAjustado(ajustes: ajustes),
            CampoCaminhao(valor: _caminhaoId, erro: _erros['caminhao'], aoMudar: (v) => setState(() => _caminhaoId = v)),
            espaco,
            CampoData(
              rotulo: 'Data',
              valor: _data,
              aoMudar: (v) {
                _data = v;
                _mudou();
              },
            ),
            espaco,
            Campo(
              controle: _cidade,
              rotulo: 'Cidade',
              erro: _erros['cidade'],
              maiusculas: TextCapitalization.words,
              sugestoes: dados.cidadesUsadas,
              aoMudar: _mudou,
            ),
            espaco,
            Campo(
              controle: _posto,
              rotulo: 'Posto',
              ajuda: 'Opcional',
              maiusculas: TextCapitalization.words,
              sugestoes: dados.postosUsados,
              aoMudar: _mudou,
            ),
            espaco,
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Campo(
                    controle: _litros,
                    rotulo: 'Litros',
                    tipo: TipoCampo.decimal3,
                    sufixo: 'L',
                    erro: _erros['litros'],
                    aoMudar: _mudou,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Campo(controle: _valor, rotulo: 'Valor pago', tipo: TipoCampo.dinheiro, aoMudar: _mudou)),
              ],
            ),
            if (litros > 0 && valor > 0)
              Padding(padding: const EdgeInsets.only(top: 6, left: 4), child: Nota('Litro a ${reais(valor / litros)}')),
            espaco,
            Campo(
              controle: _km,
              rotulo: 'Km do painel (hodômetro)',
              tipo: TipoCampo.inteiro,
              sufixo: 'km',
              erro: _erros['km'],
              aoMudar: _mudou,
            ),
            const SizedBox(height: 18),
            Material(
              color: cores.campoFundo,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Theme.of(context).colorScheme.outline),
              ),
              child: SwitchListTile(
                value: _tanqueCheio,
                onChanged: (v) {
                  _tanqueCheio = v;
                  _mudou();
                },
                title: const Text('Encheu o tanque', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                subtitle: const Text('A média só sai entre dois tanques cheios'),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              ),
            ),
            const TituloSecao('Média'),
            if (previa.media != null) ...[
              LinhaValor(
                rotulo: 'Média desta abastecida',
                valor: '${umaCasa(previa.media!)} km/L',
                destaque: true,
                corValor: cores.positivo,
              ),
              LinhaValor(rotulo: 'Km rodados', valor: '${semCasas(previa.kmRodados!)} km'),
              Nota('Contando desde o km ${semCasas(previa.kmReferencia!)}, somando '
                  '${plural(previa.abastecidasContadas, 'abastecida', 'abastecidas')} = ${umaCasa(previa.litrosContados)} L.'),
            ] else
              Nota(previa.motivo),
          ],
        ),
      ),
    );
  }
}
