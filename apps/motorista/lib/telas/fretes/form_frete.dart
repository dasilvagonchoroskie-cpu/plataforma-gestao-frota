import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleo/nucleo.dart';
import 'package:visual/visual.dart';

import '../../componentes/comuns.dart';
import '../../dados/dados.dart';
import '../../dados/rascunho.dart';
import '../caminhao/tela_caminhao.dart';

/// Anotar um frete novo ou mudar um já salvo.
class FormFrete extends ConsumerStatefulWidget {
  const FormFrete({super.key, this.editando});

  final Frete? editando;

  @override
  ConsumerState<FormFrete> createState() => _FormFreteState();
}

class _FormFreteState extends ConsumerState<FormFrete> {
  final _origem = TextEditingController();
  final _destino = TextEditingController();
  final _embarcador = TextEditingController();
  final _peso = TextEditingController();
  final _tonelada = TextEditingController();
  final _adiantamento = TextEditingController();
  final _saldo = TextEditingController();
  final _percentual = TextEditingController();
  final _pedagio = TextEditingController();
  final _pesoDescarga = TextEditingController();
  final _descontoQuebra = TextEditingController();

  late Frete _base;
  late DateTime _dataCarga;
  late bool _sobreBruto;
  String? _caminhaoId;
  Rascunho? _rascunho;
  String? _erroOrigem;
  String? _erroDestino;
  String? _erroCaminhao;

  /// Campos novos da Plataforma e os erros dos campos obrigatórios.
  Map<String, Object?> _extras = const {};
  final _erros = <String, String>{};

  /// Muda quando o rascunho chega (os campos novos se refazem com os valores dele).
  var _versaoExtras = 0;

  bool get _novo => widget.editando == null;

  List<TextEditingController> get _todos => [
    _origem,
    _destino,
    _embarcador,
    _peso,
    _tonelada,
    _adiantamento,
    _saldo,
    _percentual,
    _pedagio,
    _pesoDescarga,
    _descontoQuebra,
  ];

  @override
  void initState() {
    super.initState();
    final f = widget.editando ?? ref.read(dadosProvider.notifier).novoFrete();
    _base = f;
    _dataCarga = f.dataCarga;
    _sobreBruto = f.comissaoSobreBruto;
    _caminhaoId = f.caminhaoId.isEmpty ? null : f.caminhaoId;
    _origem.text = f.origem;
    _destino.text = f.destino;
    _embarcador.text = f.embarcador;
    _peso.text = textoInteiro(f.pesoCargaKg);
    _tonelada.text = textoDinheiro(f.valorToneladaCentavos);
    _adiantamento.text = textoDinheiro(f.adiantamentoCentavos);
    _saldo.text = textoDinheiro(f.saldoCentavos);
    _percentual.text = textoDecimal(f.percentualComissao);
    _pedagio.text = textoDinheiro(f.pedagioCentavos);
    _pesoDescarga.text = textoInteiro(f.pesoDescargaKg);
    _descontoQuebra.text = textoDinheiro(f.descontoQuebraCentavos);
    _extras = {...f.extras};
    if (_novo) _carregarRascunho();
  }

  Future<void> _carregarRascunho() async {
    final r = Rascunho(ref.read(armazenamentoProvider), 'frete');
    _rascunho = r;
    final m = await r.ler();
    if (m.isEmpty || !mounted) return;
    setState(() {
      String s(String k) => (m[k] as String?) ?? '';
      _origem.text = s('origem');
      _destino.text = s('destino');
      _embarcador.text = s('embarcador');
      _peso.text = s('peso');
      _tonelada.text = s('tonelada');
      _adiantamento.text = s('adiantamento');
      _saldo.text = s('saldo');
      if (s('percentual').isNotEmpty) _percentual.text = s('percentual');
      _pedagio.text = s('pedagio');
      _pesoDescarga.text = s('pesoDescarga');
      _descontoQuebra.text = s('descontoQuebra');
      final d = DateTime.tryParse(s('dataCarga'));
      if (d != null) _dataCarga = d;
      final b = m['sobreBruto'];
      if (b is bool) _sobreBruto = b;
      final x = m['extras'];
      if (x is Map) {
        _extras = x.cast<String, Object?>();
        _versaoExtras++;
      }
    });
  }

  void _mudou([String? _]) {
    setState(() {
      if (_origem.text.trim().isNotEmpty) _erroOrigem = null;
      if (_destino.text.trim().isNotEmpty) _erroDestino = null;
    });
    if (_novo) {
      _rascunho?.gravar({
        'origem': _origem.text,
        'destino': _destino.text,
        'embarcador': _embarcador.text,
        'peso': _peso.text,
        'tonelada': _tonelada.text,
        'adiantamento': _adiantamento.text,
        'saldo': _saldo.text,
        'percentual': _percentual.text,
        'pedagio': _pedagio.text,
        'pesoDescarga': _pesoDescarga.text,
        'descontoQuebra': _descontoQuebra.text,
        'dataCarga': _dataCarga.toIso8601String(),
        'sobreBruto': _sobreBruto,
        'extras': _extras,
      });
    }
  }

  @override
  void dispose() {
    for (final c in _todos) {
      c.dispose();
    }
    super.dispose();
  }

  Frete _montar() => _base.copyWith(
    caminhaoId: _caminhaoId ?? '',
    origem: _origem.text.trim(),
    destino: _destino.text.trim(),
    embarcador: _embarcador.text.trim(),
    dataCarga: _dataCarga,
    pesoCargaKg: lerNumero(_peso.text),
    valorToneladaCentavos: lerCentavos(_tonelada.text),
    adiantamentoCentavos: lerCentavos(_adiantamento.text),
    saldoCentavos: lerCentavos(_saldo.text),
    percentualComissao: lerNumero(_percentual.text),
    pedagioCentavos: lerCentavos(_pedagio.text),
    comissaoSobreBruto: _sobreBruto,
    pesoDescargaKg: lerNumero(_pesoDescarga.text),
    descontoQuebraCentavos: lerCentavos(_descontoQuebra.text),
    extras: _extras,
  );

  Future<void> _salvar() async {
    final f = _montar();
    final m = ref.read(dadosProvider).requireValue.modalidade;
    // O que o dono marcou como obrigatório (campos de fábrica que podem sumir).
    final preenchido = <String, bool>{
      'embarcador': f.embarcador.isNotEmpty,
      'peso_carga_kg': f.pesoCargaKg > 0,
      'valor_tonelada_centavos': f.valorToneladaCentavos > 0,
      'adiantamento_centavos': f.adiantamentoCentavos > 0,
      'saldo_centavos': f.saldoCentavos > 0,
      'pedagio_centavos': f.pedagioCentavos > 0,
      'percentual_comissao': _percentual.text.trim().isNotEmpty,
      'peso_descarga_kg': f.pesoDescargaKg > 0,
      'desconto_quebra_centavos': f.descontoQuebraCentavos > 0,
    };
    setState(() {
      _erroOrigem = f.origem.isEmpty ? 'Falta ${m.rotulo('origem', 'de onde saiu a carga').toLowerCase()}.' : null;
      _erroDestino = f.destino.isEmpty ? 'Falta ${m.rotulo('destino', 'para onde vai a carga').toLowerCase()}.' : null;
      _erroCaminhao = f.caminhaoId.isEmpty ? 'Escolha o caminhão.' : null;
      _erros
        ..clear()
        ..addAll({
          for (final e in preenchido.entries)
            if (m.visivel(e.key) && m.obrigatorio(e.key) && !e.value)
              e.key: 'Preencha ${m.rotulo(e.key, '').toLowerCase()}.',
        })
        ..addAll(errosDosExtras(m.extras(), _extras));
    });
    if (_erroOrigem != null || _erroDestino != null || _erroCaminhao != null || _erros.isNotEmpty) {
      mostrarMensagem(context, 'Preencha o que está marcado para salvar.');
      return;
    }
    if (f.percentualComissao > 100) {
      mostrarMensagem(context, 'A comissão não pode passar de 100%.');
      return;
    }
    await ref.read(dadosProvider.notifier).salvarFrete(f);
    await _rascunho?.limpar();
    if (!mounted) return;
    final mensageiro = ScaffoldMessenger.of(context);
    Navigator.pop(context, true);
    mensageiro
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(_novo ? 'Frete salvo.' : 'Alteração salva.')));
  }

  Widget _dupla(Widget a, Widget b) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: a),
      const SizedBox(width: 12),
      Expanded(child: b),
    ],
  );

  /// Um ou dois campos lado a lado (o dono pode esconder um deles).
  Widget _par(List<Widget> campos) {
    if (campos.isEmpty) return const SizedBox.shrink();
    if (campos.length == 1) return campos.first;
    return _dupla(campos[0], campos[1]);
  }

  @override
  Widget build(BuildContext context) {
    final dados = assistirDados(ref);
    final m = dados.modalidade;
    String rotulo(String chave, String padrao) => m.rotulo(chave, padrao);
    bool ver(String chave) => m.visivel(chave);
    String? opcional(String chave, String? padrao) => m.obrigatorio(chave) ? null : padrao;
    final f = _montar();
    final ajustes = _novo ? const <AjusteGestor>[] : dados.ajustesDe(_base.id);
    final bloqueado = ajustes.isNotEmpty;
    const espaco = SizedBox(height: 14);

    if (_novo && dados.caminhaoAtual == null && dados.caminhoesAtivos.isEmpty && _caminhaoId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Novo frete')),
        body: EstadoVazio(
          icone: Icons.local_shipping_outlined,
          titulo: 'Escolha o caminhão primeiro',
          texto: 'Os lançamentos ficam ligados ao caminhão em que você está.',
          acao: FilledButton(
            onPressed: () =>
                Navigator.push(context, MaterialPageRoute(builder: (_) => const TelaTrocarCaminhao(primeiraVez: true))),
            child: const Text('Escolher o caminhão'),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(_novo ? 'Novo frete' : 'Mudar frete')),
      bottomNavigationBar: bloqueado
          ? null
          : RodapeBotao(texto: _novo ? 'Salvar frete' : 'Salvar alteração', aoTocar: _salvar),
      body: AbsorbPointer(
        absorbing: bloqueado,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          children: [
            AvisoAjustado(ajustes: ajustes),
            if (_novo)
              const Nota(
                'Preencha o que já sabe agora. O saldo e a descarga você completa depois. '
                'O que digitar fica guardado mesmo se o app fechar.',
              ),
            const TituloSecao('Carga', espacoAcima: 16),
            CampoCaminhao(valor: _caminhaoId, erro: _erroCaminhao, aoMudar: (v) => setState(() => _caminhaoId = v)),
            espaco,
            CampoData(
              rotulo: rotulo('data_carga', 'Data da carga'),
              valor: _dataCarga,
              aoMudar: (v) {
                _dataCarga = v;
                _mudou();
              },
            ),
            espaco,
            Campo(
              controle: _origem,
              rotulo: rotulo('origem', 'Origem (de onde saiu)'),
              erro: _erroOrigem,
              maiusculas: TextCapitalization.words,
              sugestoes: dados.cidadesUsadas,
              aoMudar: _mudou,
            ),
            espaco,
            Campo(
              controle: _destino,
              rotulo: rotulo('destino', 'Destino (para onde vai)'),
              erro: _erroDestino,
              maiusculas: TextCapitalization.words,
              sugestoes: dados.cidadesUsadas,
              aoMudar: _mudou,
            ),
            if (ver('embarcador')) ...[
              espaco,
              Campo(
                controle: _embarcador,
                rotulo: rotulo('embarcador', 'Embarcador ou cliente'),
                ajuda: opcional('embarcador', 'Opcional'),
                erro: _erros['embarcador'],
                maiusculas: TextCapitalization.words,
                sugestoes: dados.embarcadoresUsados,
                aoMudar: _mudou,
              ),
            ],
            if (ver('peso_carga_kg') || ver('valor_tonelada_centavos')) ...[
              const TituloSecao('Peso e preço'),
              _par([
                if (ver('peso_carga_kg'))
                  Campo(
                    controle: _peso,
                    rotulo: rotulo('peso_carga_kg', 'Peso na carga'),
                    tipo: TipoCampo.inteiro,
                    sufixo: 'kg',
                    dica: '33.040',
                    erro: _erros['peso_carga_kg'],
                    aoMudar: _mudou,
                  ),
                if (ver('valor_tonelada_centavos'))
                  Campo(
                    controle: _tonelada,
                    rotulo: rotulo('valor_tonelada_centavos', 'Valor da tonelada'),
                    tipo: TipoCampo.dinheiro,
                    erro: _erros['valor_tonelada_centavos'],
                    aoMudar: _mudou,
                  ),
              ]),
            ],
            if (ver('adiantamento_centavos') || ver('saldo_centavos') || ver('pedagio_centavos'))
              const TituloSecao('Pagamento'),
            _par([
              if (ver('adiantamento_centavos'))
                Campo(
                  controle: _adiantamento,
                  rotulo: rotulo('adiantamento_centavos', 'Adiantamento'),
                  tipo: TipoCampo.dinheiro,
                  erro: _erros['adiantamento_centavos'],
                  aoMudar: _mudou,
                ),
              if (ver('saldo_centavos'))
                Campo(
                  controle: _saldo,
                  rotulo: rotulo('saldo_centavos', 'Saldo'),
                  tipo: TipoCampo.dinheiro,
                  ajuda: opcional('saldo_centavos', 'Quando cair'),
                  erro: _erros['saldo_centavos'],
                  aoMudar: _mudou,
                ),
            ]),
            if (ver('pedagio_centavos')) ...[
              espaco,
              Campo(
                controle: _pedagio,
                rotulo: rotulo('pedagio_centavos', 'Pedágio no cartão ou tag'),
                tipo: TipoCampo.dinheiro,
                ajuda: 'O que a empresa pagou de pedágio. Pedágio do seu bolso vai em Gastos.',
                erro: _erros['pedagio_centavos'],
                aoMudar: _mudou,
              ),
            ],
            if (ver('percentual_comissao')) ...[
              const TituloSecao('Comissão'),
              Campo(
                controle: _percentual,
                rotulo: rotulo('percentual_comissao', 'Sua comissão'),
                tipo: TipoCampo.decimal,
                sufixo: '%',
                erro: _erros['percentual_comissao'],
                aoMudar: _mudou,
              ),
              const SizedBox(height: 12),
              Text('A comissão é sobre', style: TextStyle(fontSize: 15, color: context.cores.textoFraco)),
              const SizedBox(height: 6),
              EscolhaDupla(
                valor: _sobreBruto,
                textoSim: 'Frete + pedágio',
                textoNao: 'Só o frete',
                aoMudar: (v) {
                  _sobreBruto = v;
                  _mudou();
                },
              ),
            ],
            if (ver('peso_descarga_kg') || ver('desconto_quebra_centavos')) ...[
              const TituloSecao('Descarga'),
              const Nota('Pode completar depois, quando descarregar.'),
              const SizedBox(height: 10),
              _par([
                if (ver('peso_descarga_kg'))
                  Campo(
                    controle: _pesoDescarga,
                    rotulo: rotulo('peso_descarga_kg', 'Peso na descarga'),
                    tipo: TipoCampo.inteiro,
                    sufixo: 'kg',
                    erro: _erros['peso_descarga_kg'],
                    aoMudar: _mudou,
                  ),
                if (ver('desconto_quebra_centavos'))
                  Campo(
                    controle: _descontoQuebra,
                    rotulo: rotulo('desconto_quebra_centavos', 'Desconto de quebra'),
                    tipo: TipoCampo.dinheiro,
                    erro: _erros['desconto_quebra_centavos'],
                    aoMudar: _mudou,
                  ),
              ]),
            ],
            if (m.extras().isNotEmpty) ...[
              const TituloSecao('Mais informações'),
              CamposExtras(
                key: ValueKey(_versaoExtras),
                campos: m.extras(),
                valores: _extras,
                erros: _erros,
                sugestoesCidades: dados.cidadesUsadas,
                aoMudar: (v) {
                  _extras = v;
                  _erros.removeWhere((k, _) => v.containsKey(k));
                  _mudou();
                },
              ),
            ],
            const TituloSecao('Conferência'),
            Conferencia(frete: f),
          ],
        ),
      ),
    );
  }
}

/// Conta ao vivo do frete: o que entrou, o combinado, a quebra e a sua parte.
class Conferencia extends StatelessWidget {
  const Conferencia({super.key, required this.frete});
  final Frete frete;

  @override
  Widget build(BuildContext context) {
    final f = frete;
    final cores = context.cores;
    final contratado = f.valorContratadoCentavos;
    final dif = f.diferencaDoContratadoCentavos;
    final quebra = f.quebraKg;

    String? mensagem;
    Color? corMensagem;
    if (f.freteRealCentavos > 0 && contratado > 0 && !f.aguardandoSaldo) {
      if (dif.abs() < 1) {
        mensagem = 'Bateu certinho com o combinado.';
        corMensagem = cores.positivo;
      } else if (dif > 0) {
        mensagem = 'Entrou ${reais(dif)} a mais que o combinado. Confira.';
        corMensagem = cores.atencao;
      } else {
        mensagem = 'Desconto da transportadora: ${reais(dif.abs())} (INSS, SEST/SENAT, seguro, pedágio, quebra).';
        corMensagem = cores.textoFraco;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LinhaValor(rotulo: 'Frete real (o que entrou)', valor: reais(f.freteRealCentavos)),
        if (f.descontoQuebraCentavos > 0)
          LinhaValor(rotulo: 'Sem a quebra teria dado', valor: reais(f.freteSemQuebraCentavos)),
        LinhaValor(
          rotulo: 'Valor contratado',
          valor: contratado > 0 ? reais(contratado) : '—',
          detalhe: contratado > 0
              ? '${toneladas(f.pesoCargaKg)} t × ${reais(f.valorToneladaCentavos)}'
              : 'Peso vezes o valor da tonelada',
        ),
        LinhaValor(
          rotulo: f.comissaoSobreBruto ? 'Base da comissão (bruto)' : 'Base da comissão (o que entrou)',
          valor: f.baseComissaoCentavos > 0 ? reais(f.baseComissaoCentavos) : '—',
        ),
        LinhaValor(
          rotulo: 'Sua parte (${percentualTexto(f.percentualComissao)}%)',
          valor: reais(f.minhaParteCentavos),
          destaque: true,
          corValor: cores.positivo,
        ),
        if (mensagem != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Nota(mensagem, cor: corMensagem),
          ),
        if (quebra != null) ...[
          const SizedBox(height: 12),
          Aviso(
            icone: Icons.scale_outlined,
            titulo: 'Quebra de ${semCasas(quebra)} kg',
            texto:
                'Carregou ${toneladas(f.pesoCargaKg)} t e descarregou ${toneladas(f.pesoDescargaKg)} t. '
                'Pelo valor da tonelada, a quebra vale ${reais(f.valorQuebraIntegralCentavos)}. '
                '${f.descontoQuebraCentavos > 0 ? 'Cobraram ${reais(f.descontoQuebraCentavos)}.' : 'Não descontaram.'}'
                '${f.descontoQuebraCentavos > f.valorQuebraIntegralCentavos + 1 && f.valorQuebraIntegralCentavos > 0 ? ' Atenção: cobraram ${reais(f.descontoQuebraCentavos - f.valorQuebraIntegralCentavos)} a mais do que a quebra vale.' : ''}',
          ),
        ],
      ],
    );
  }
}
