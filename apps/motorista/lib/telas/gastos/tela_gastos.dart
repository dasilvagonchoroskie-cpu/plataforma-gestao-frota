import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleo/nucleo.dart';
import 'package:visual/visual.dart';

import '../../componentes/comuns.dart';
import '../../dados/dados.dart';
import '../../dados/rascunho.dart';

class TelaGastos extends ConsumerWidget {
  const TelaGastos({super.key});

  void _novo(BuildContext context) => Navigator.push(context, MaterialPageRoute(builder: (_) => const FormGasto()));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dados = assistirDados(ref);
    final grupos = agruparPorMes<Gasto>(dados.gastos, (g) => g.data);

    return Scaffold(
      appBar: AppBar(title: const Text('Gastos')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'novo_gasto',
        onPressed: () => _novo(context),
        icon: const Icon(Icons.add),
        label: const Text('Novo gasto'),
      ),
      body: ListView(
        children: [
          const TopoCaminhao(),
          if (dados.gastos.isEmpty)
            EstadoVazio(
              icone: Icons.receipt_long_outlined,
              titulo: 'Nenhum gasto anotado',
              texto: 'Borracharia, manutenção, pedágio do bolso, chapa, lavagem. O diesel fica na aba Diesel.',
              acao: FilledButton.icon(
                onPressed: () => _novo(context),
                icon: const Icon(Icons.add),
                label: const Text('Anotar gasto'),
              ),
            )
          else ...[
            for (final g in grupos) ...[
              CabecalhoMes(titulo: g.titulo, resumo: reais(g.itens.fold<double>(0, (s, e) => s + e.valorCentavos))),
              for (var i = 0; i < g.itens.length; i++) ...[
                if (i > 0) const Divider(indent: 20, endIndent: 20),
                InkWell(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FormGasto(editando: g.itens[i]))),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 20, 12),
                    child: Row(
                      children: [
                        ColunaData(g.itens[i].data),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                g.itens[i].categoriaNome,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                              ),
                              if ((g.itens[i].observacao ?? '').isNotEmpty)
                                Text(g.itens[i].observacao!, maxLines: 1, overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 14, color: context.cores.textoFraco)),
                              const SizedBox(height: 4),
                              MarcasLancamento(
                                pendente: dados.estaPendente(Tabelas.gastos, g.itens[i].id),
                                ajustado: g.itens[i].ajustado,
                                placa: dados.placaDe(g.itens[i].caminhaoId),
                              ),
                            ],
                          ),
                        ),
                        Text(reais(g.itens[i].valorCentavos), style: estiloNumero(18)),
                      ],
                    ),
                  ),
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

class FormGasto extends ConsumerStatefulWidget {
  const FormGasto({super.key, this.editando});
  final Gasto? editando;

  @override
  ConsumerState<FormGasto> createState() => _FormGastoState();
}

class _FormGastoState extends ConsumerState<FormGasto> {
  final _valor = TextEditingController();
  final _observacao = TextEditingController();
  late DateTime _data;
  String? _categoriaId;
  String? _caminhaoId;
  String? _erroValor;
  String? _erroCategoria;
  String? _erroCaminhao;
  Rascunho? _rascunho;

  bool get _novo => widget.editando == null;

  @override
  void initState() {
    super.initState();
    _data = inicioDoDia(DateTime.now());
    final g = widget.editando;
    if (g != null) {
      _data = g.data;
      _valor.text = textoDinheiro(g.valorCentavos);
      _observacao.text = g.observacao ?? '';
      _categoriaId = g.categoriaId;
      _caminhaoId = g.caminhaoId;
    } else {
      _caminhaoId = ref.read(dadosProvider).requireValue.caminhaoAtualId;
      final r = Rascunho(ref.read(armazenamentoProvider), 'gasto');
      _rascunho = r;
      r.ler().then((m) {
        if (m.isEmpty || !mounted) return;
        setState(() {
          _valor.text = (m['valor'] as String?) ?? '';
          _observacao.text = (m['observacao'] as String?) ?? '';
          _categoriaId = m['categoria'] as String?;
          final d = DateTime.tryParse((m['data'] as String?) ?? '');
          if (d != null) _data = d;
        });
      });
    }
  }

  @override
  void dispose() {
    _valor.dispose();
    _observacao.dispose();
    super.dispose();
  }

  void _mudou([String? _]) {
    setState(() {
      _erroValor = null;
      _erroCategoria = null;
    });
    if (_novo) {
      _rascunho?.gravar({
        'valor': _valor.text,
        'observacao': _observacao.text,
        'categoria': _categoriaId,
        'data': _data.toIso8601String(),
      });
    }
  }

  Future<void> _salvar() async {
    final valor = lerCentavos(_valor.text);
    setState(() {
      _erroValor = valor <= 0 ? 'Falta o valor do gasto.' : null;
      _erroCategoria = _categoriaId == null ? 'Escolha o que foi.' : null;
      _erroCaminhao = _caminhaoId == null ? 'Escolha o caminhão.' : null;
    });
    if (_erroValor != null || _erroCategoria != null || _erroCaminhao != null) return;
    final d = ref.read(dadosProvider).requireValue;
    final base = widget.editando;
    final gasto = base?.copyWith(
          caminhaoId: _caminhaoId,
          data: _data,
          categoriaId: _categoriaId,
          valorCentavos: valor,
          observacao: _observacao.text.trim(),
        ) ??
        Gasto(
          id: novoId(),
          motoristaId: d.info.motoristaId ?? '',
          caminhaoId: _caminhaoId!,
          data: _data,
          categoriaId: _categoriaId!,
          valorCentavos: valor,
          observacao: _observacao.text.trim().isEmpty ? null : _observacao.text.trim(),
          criadoNoAparelhoEm: DateTime.now(),
        );
    await ref.read(dadosProvider.notifier).salvarGasto(gasto);
    await _rascunho?.limpar();
    if (!mounted) return;
    final mensageiro = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    mensageiro.showSnackBar(SnackBar(content: Text(_novo ? 'Gasto salvo.' : 'Alteração salva.')));
  }

  Future<void> _apagar() async {
    final g = widget.editando!;
    final ok = await confirmarExclusao(
      context,
      titulo: 'Apagar este gasto?',
      detalhe: '${dataTexto(g.data)}, ${g.categoriaNome}, ${reais(g.valorCentavos)}. O seu patrão vai ver que foi apagado.',
    );
    if (!ok || !mounted) return;
    final mensageiro = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    await ref.read(dadosProvider.notifier).apagarGasto(g);
    mensageiro.showSnackBar(const SnackBar(content: Text('Gasto apagado.')));
  }

  @override
  Widget build(BuildContext context) {
    final dados = assistirDados(ref);
    final categorias = dados.categoriasAtivas;
    final ajustes = _novo ? const <AjusteGestor>[] : dados.ajustesDe(widget.editando!.id);
    final bloqueado = ajustes.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(_novo ? 'Novo gasto' : 'Mudar gasto'),
        actions: [
          if (!_novo && !bloqueado) IconButton(tooltip: 'Apagar', icon: const Icon(Icons.delete_outline), onPressed: _apagar),
        ],
      ),
      bottomNavigationBar: bloqueado ? null : RodapeBotao(texto: _novo ? 'Salvar gasto' : 'Salvar alteração', aoTocar: _salvar),
      body: AbsorbPointer(
        absorbing: bloqueado,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            AvisoAjustado(ajustes: ajustes),
            CampoCaminhao(valor: _caminhaoId, erro: _erroCaminhao, aoMudar: (v) => setState(() => _caminhaoId = v)),
            const SizedBox(height: 14),
            CampoData(
              rotulo: 'Data',
              valor: _data,
              aoMudar: (v) {
                _data = v;
                _mudou();
              },
            ),
            const SizedBox(height: 14),
            Campo(controle: _valor, rotulo: 'Valor', tipo: TipoCampo.dinheiro, erro: _erroValor, aoMudar: _mudou),
            const SizedBox(height: 18),
            Text('O que foi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                color: _erroCategoria == null ? null : context.cores.negativo)),
            const SizedBox(height: 8),
            if (categorias.isEmpty)
              const Nota('As categorias chegam da empresa na primeira vez que o celular tiver internet.'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in categorias)
                  ChoiceChip(
                    label: Text(c.nome),
                    selected: c.id == _categoriaId,
                    showCheckmark: false,
                    onSelected: (_) {
                      _categoriaId = c.id;
                      _mudou();
                    },
                  ),
              ],
            ),
            if (_erroCategoria != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(_erroCategoria!, style: TextStyle(color: context.cores.negativo, fontSize: 13.5)),
              ),
            const SizedBox(height: 18),
            Campo(controle: _observacao, rotulo: 'Observação', ajuda: 'Opcional', aoMudar: _mudou),
            const SizedBox(height: 20),
            const Nota('Diesel vai na aba Diesel. Pedágio pago no cartão ou tag da empresa vai no próprio frete.'),
          ],
        ),
      ),
    );
  }
}
