import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleo/nucleo.dart';
import 'package:visual/visual.dart';

import '../../componentes/comuns.dart';
import '../../dados/dados.dart';
import '../caminhao/tela_caminhao.dart';

enum ModoViagem {
  /// Carreta nova: placa, onde e quando engatou.
  engatar,

  /// Fim da viagem: até onde levou, quando, as entregas.
  desengatar,

  /// Mudar o que já foi anotado (e anotar entregas durante a viagem).
  mudar,
}

/// Engatar, desengatar ou mudar uma viagem (Baú, Sider). Os campos e os nomes
/// seguem a configuração da empresa (o dono ajusta no painel).
class FormViagem extends ConsumerStatefulWidget {
  const FormViagem({super.key, this.modo = ModoViagem.engatar, this.viagem});

  final ModoViagem modo;
  final Viagem? viagem;

  @override
  ConsumerState<FormViagem> createState() => _FormViagemState();
}

class _FormViagemState extends ConsumerState<FormViagem> {
  final _placa = TextEditingController();
  final _engateLocal = TextEditingController();
  final _desengateLocal = TextEditingController();
  final _quantidade = TextEditingController();
  final _observacao = TextEditingController();

  late Viagem _base;
  late DateTime _engateEm;
  DateTime? _desengateEm;
  List<String> _cidades = const [];
  Map<String, Object?> _extras = const {};
  final _erros = <String, String>{};

  ModoViagem get _modo => widget.modo;
  bool get _novo => widget.viagem == null;

  /// O formulário mostra o desengate: ao desengatar e ao mudar uma viagem já fechada.
  bool get _comDesengate => _modo == ModoViagem.desengatar || (_modo == ModoViagem.mudar && !_base.emAndamento);

  /// Mostra os campos do engate: ao engatar e ao mudar.
  bool get _comEngate => _modo != ModoViagem.desengatar;

  /// Entregas: ao desengatar e ao mudar (durante a viagem também).
  bool get _comEntregas => _modo != ModoViagem.engatar;

  @override
  void initState() {
    super.initState();
    final agora = ref.read(relogioProvider)();
    final v = widget.viagem ?? ref.read(dadosProvider.notifier).novaViagem();
    _base = v;
    _placa.text = v.placaCarreta;
    _engateLocal.text = v.engateLocal;
    _engateEm = v.engateEm;
    _desengateLocal.text = v.desengateLocal;
    _desengateEm = v.desengateEm ?? (_modo == ModoViagem.desengatar ? agora : null);
    _quantidade.text = v.entregasQuantidade > 0 ? '${v.entregasQuantidade}' : '';
    _observacao.text = v.observacao ?? '';
    _cidades = [...v.entregasCidades];
    _extras = {...v.extras};
  }

  @override
  void dispose() {
    for (final c in [_placa, _engateLocal, _desengateLocal, _quantidade, _observacao]) {
      c.dispose();
    }
    super.dispose();
  }

  void _limparErro(String chave) {
    if (_erros.remove(chave) != null) setState(() {});
  }

  Viagem _montar() {
    final qtdDigitada = lerNumero(_quantidade.text).round();
    return _base.copyWith(
      caminhaoId: _base.caminhaoId.isEmpty ? (ref.read(dadosProvider).value?.caminhaoAtualId ?? '') : null,
      placaCarreta: normalizarPlaca(_placa.text),
      engateLocal: _engateLocal.text.trim(),
      engateEm: _engateEm,
      desengateLocal: _desengateLocal.text.trim(),
      desengateEm: _comDesengate ? _desengateEm : null,
      reabrir: !_comDesengate,
      // Sem número digitado, vale a quantidade de cidades anotadas.
      entregasQuantidade: _quantidade.text.trim().isEmpty ? _cidades.length : qtdDigitada,
      entregasCidades: _cidades,
      observacao: _observacao.text.trim(),
      extras: _extras,
    );
  }

  List<CampoModalidade> _extrasDaTela(Modalidade m) => [
    if (_comEngate) ...m.extras(etapa: EtapasViagem.engate),
    if (_comEntregas) ...m.extras(etapa: EtapasViagem.entregas),
    if (_comDesengate) ...m.extras(etapa: EtapasViagem.desengate),
  ];

  Future<void> _salvar() async {
    final dados = ref.read(dadosProvider).requireValue;
    final m = dados.modalidade;
    final v = _montar();
    String nome(String chave, String padrao) => m.rotulo(chave, padrao).toLowerCase();
    bool exige(String chave, {bool padrao = false}) => m.visivel(chave) && m.obrigatorio(chave, padrao: padrao);

    _erros.clear();
    if (_comEngate) {
      if (!placaValida(v.placaCarreta)) _erros['placa_carreta'] = 'Placa errada. Exemplos: ABC1D23 ou ABC-1234.';
      if (exige('engate_local', padrao: true) && v.engateLocal.isEmpty) {
        _erros['engate_local'] = 'Falta ${nome('engate_local', 'onde engatou')}.';
      }
      if (v.engateEm.isAfter(ref.read(relogioProvider)().add(const Duration(hours: 1)))) {
        _erros['engate_em'] = 'O engate não pode ser no futuro.';
      }
    }
    if (_comDesengate) {
      if (exige('desengate_local', padrao: true) && v.desengateLocal.isEmpty) {
        _erros['desengate_local'] = 'Falta ${nome('desengate_local', 'até onde levou')}.';
      }
      if (v.desengateEm == null) {
        _erros['desengate_em'] = 'Falta ${nome('desengate_em', 'quando desengatou')}.';
      } else if (v.desengateEm!.isBefore(v.engateEm)) {
        _erros['desengate_em'] = 'O desengate não pode ser antes do engate (${dataHoraTexto(v.engateEm)}).';
      }
      if (exige('observacao') && (v.observacao ?? '').isEmpty) _erros['observacao'] = 'Preencha a observação.';
    }
    if (_comEntregas && (_comDesengate || _modo == ModoViagem.mudar)) {
      final fechando = _comDesengate;
      if (fechando && exige('entregas_quantidade') && _quantidade.text.trim().isEmpty && _cidades.isEmpty) {
        _erros['entregas_quantidade'] = 'Falta ${nome('entregas_quantidade', 'quantas entregas')}.';
      }
      if (fechando && exige('entregas_cidades') && _cidades.isEmpty) {
        _erros['entregas_cidades'] = 'Ponha pelo menos uma cidade.';
      }
    }
    final extras = _extrasDaTela(m);
    _erros.addAll(
      errosDosExtras([
        for (final c in extras)
          if (c.etapa != EtapasViagem.entregas || _comDesengate) c,
      ], v.extras),
    );
    if (v.caminhaoId.isEmpty) _erros['caminhao'] = 'Escolha o caminhão (cavalo).';
    setState(() {});
    if (_erros.isNotEmpty) {
      mostrarMensagem(context, 'Preencha o que está marcado para salvar.');
      return;
    }
    await ref.read(dadosProvider.notifier).salvarViagem(v);
    if (!mounted) return;
    final mensageiro = ScaffoldMessenger.of(context);
    Navigator.pop(context, true);
    mensageiro
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(switch (_modo) {
            ModoViagem.engatar => 'Carreta ${placaTexto(v.placaCarreta)} engatada.',
            ModoViagem.desengatar => 'Viagem fechada.',
            ModoViagem.mudar => 'Alteração salva.',
          }),
        ),
      );
  }

  Future<void> _apagar() async {
    final v = _base;
    final ok = await confirmarExclusao(
      context,
      titulo: 'Apagar esta viagem?',
      detalhe:
          'Carreta ${placaTexto(v.placaCarreta)}, engate de ${dataHoraTexto(v.engateEm)}. '
          'O seu patrão vai ver que foi apagada.',
    );
    if (!ok || !mounted) return;
    final mensageiro = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    await ref.read(dadosProvider.notifier).apagarViagem(v);
    mensageiro.showSnackBar(const SnackBar(content: Text('Viagem apagada.')));
  }

  @override
  Widget build(BuildContext context) {
    final dados = assistirDados(ref);
    final m = dados.modalidade;
    final cores = context.cores;
    const espaco = SizedBox(height: 14);
    String rotulo(String chave, String padrao) => m.rotulo(chave, padrao);
    bool ver(String chave) => m.visivel(chave);
    String? ajuda(String chave, {bool padrao = false}) => m.obrigatorio(chave, padrao: padrao) ? null : 'Opcional';

    final aberta = dados.viagemEmAndamento;
    if (_modo == ModoViagem.engatar && _novo) {
      if (dados.caminhaoAtual == null) {
        return Scaffold(
          appBar: AppBar(title: const Text('Engatar carreta')),
          body: EstadoVazio(
            icone: Icons.local_shipping_outlined,
            titulo: 'Escolha o cavalo primeiro',
            texto: 'A viagem fica ligada ao caminhão (cavalo) que você dirige.',
            acao: FilledButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TelaTrocarCaminhao(primeiraVez: true)),
              ),
              child: const Text('Escolher o caminhão'),
            ),
          ),
        );
      }
      if (aberta != null) {
        return Scaffold(
          appBar: AppBar(title: const Text('Engatar carreta')),
          body: EstadoVazio(
            icone: Icons.link_off,
            titulo: 'A carreta ${placaTexto(aberta.placaCarreta)} ainda está engatada',
            texto: 'Cada carreta é uma viagem. Desengate esta antes de engatar outra.',
            acao: FilledButton(
              onPressed: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => FormViagem(modo: ModoViagem.desengatar, viagem: aberta),
                ),
              ),
              child: const Text('Desengatar agora'),
            ),
          ),
        );
      }
    }

    final titulo = switch (_modo) {
      ModoViagem.engatar => 'Engatar carreta',
      ModoViagem.desengatar => 'Desengatar carreta',
      ModoViagem.mudar => 'Mudar viagem',
    };
    final botao = switch (_modo) {
      ModoViagem.engatar => 'Engatar',
      ModoViagem.desengatar => 'Desengatar e fechar a viagem',
      ModoViagem.mudar => 'Salvar alteração',
    };
    final extras = _extrasDaTela(m);

    return Scaffold(
      appBar: AppBar(
        title: Text(titulo),
        actions: [
          if (_modo == ModoViagem.mudar && !_novo)
            IconButton(tooltip: 'Apagar', icon: const Icon(Icons.delete_outline), onPressed: _apagar),
          const SizedBox(width: 4),
        ],
      ),
      bottomNavigationBar: RodapeBotao(texto: botao, aoTocar: _salvar),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          if (_modo == ModoViagem.engatar)
            const Nota('Cada carreta é uma viagem. Quando desengatar, abra a viagem e toque em "Desengatar".'),
          if (_modo == ModoViagem.desengatar)
            Aviso(
              icone: Icons.local_shipping_outlined,
              titulo: 'Carreta ${placaTexto(_base.placaCarreta)}',
              texto:
                  'Engatou ${_base.engateLocal.isEmpty ? '' : 'em ${_base.engateLocal}, '}${dataHoraTexto(_base.engateEm)}.',
            ),
          if (_erros['caminhao'] != null) ...[
            const SizedBox(height: 8),
            Text(_erros['caminhao']!, style: TextStyle(color: cores.negativo, fontSize: 15)),
          ],
          if (_comEngate) ...[
            TituloSecao('Engate', espacoAcima: 16),
            Campo(
              controle: _placa,
              rotulo: rotulo('placa_carreta', 'Placa da carreta'),
              tipo: TipoCampo.placa,
              dica: 'ABC1D23',
              erro: _erros['placa_carreta'],
              sugestoes: dados.carretasUsadas,
              aoMudar: (_) => _limparErro('placa_carreta'),
            ),
            espaco,
            if (ver('engate_local')) ...[
              Campo(
                controle: _engateLocal,
                rotulo: rotulo('engate_local', 'Onde engatou'),
                ajuda: ajuda('engate_local', padrao: true),
                erro: _erros['engate_local'],
                maiusculas: TextCapitalization.words,
                sugestoes: dados.cidadesUsadas,
                aoMudar: (_) => _limparErro('engate_local'),
              ),
              espaco,
            ],
            CampoDataHora(
              rotulo: rotulo('engate_em', 'Quando engatou'),
              valor: _engateEm,
              erro: _erros['engate_em'],
              aoMudar: (d) => setState(() {
                _engateEm = d;
                _erros.remove('engate_em');
              }),
            ),
          ],
          if (_comEntregas && (ver('entregas_quantidade') || ver('entregas_cidades'))) ...[
            const TituloSecao('Entregas'),
            if (_modo == ModoViagem.mudar && _base.emAndamento)
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Nota('Pode anotar as entregas durante a viagem e completar no desengate.'),
              ),
            if (ver('entregas_cidades')) ...[
              CampoCidades(
                rotulo: rotulo('entregas_cidades', 'Cidades das entregas'),
                valor: _cidades,
                erro: _erros['entregas_cidades'],
                sugestoes: dados.cidadesUsadas,
                aoMudar: (l) => setState(() {
                  _cidades = l;
                  _erros.remove('entregas_cidades');
                }),
              ),
              espaco,
            ],
            if (ver('entregas_quantidade')) ...[
              Campo(
                controle: _quantidade,
                rotulo: rotulo('entregas_quantidade', 'Quantas entregas'),
                tipo: TipoCampo.inteiro,
                ajuda: _cidades.isEmpty
                    ? ajuda('entregas_quantidade')
                    : 'Em branco: ${_cidades.length}, uma por cidade',
                erro: _erros['entregas_quantidade'],
                aoMudar: (_) => _limparErro('entregas_quantidade'),
              ),
              espaco,
            ],
          ],
          if (_comDesengate) ...[
            const TituloSecao('Desengate'),
            if (ver('desengate_local')) ...[
              Campo(
                controle: _desengateLocal,
                rotulo: rotulo('desengate_local', 'Até onde levou'),
                ajuda: ajuda('desengate_local', padrao: true),
                erro: _erros['desengate_local'],
                maiusculas: TextCapitalization.words,
                sugestoes: dados.cidadesUsadas,
                aoMudar: (_) => _limparErro('desengate_local'),
              ),
              espaco,
            ],
            CampoDataHora(
              rotulo: rotulo('desengate_em', 'Quando desengatou'),
              valor: _desengateEm,
              erro: _erros['desengate_em'],
              aoMudar: (d) => setState(() {
                _desengateEm = d;
                _erros.remove('desengate_em');
              }),
            ),
            espaco,
            if (ver('observacao')) ...[
              Campo(
                controle: _observacao,
                rotulo: rotulo('observacao', 'Observação'),
                ajuda: ajuda('observacao'),
                erro: _erros['observacao'],
                aoMudar: (_) => _limparErro('observacao'),
              ),
              espaco,
            ],
          ],
          if (extras.isNotEmpty) ...[
            const TituloSecao('Mais informações'),
            CamposExtras(
              campos: extras,
              valores: _extras,
              erros: _erros,
              sugestoesCidades: dados.cidadesUsadas,
              aoMudar: (v) => setState(() {
                _extras = v;
                _erros.removeWhere((k, _) => v.containsKey(k));
              }),
            ),
          ],
          if (_modo == ModoViagem.mudar && _base.emAndamento) ...[
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => FormViagem(modo: ModoViagem.desengatar, viagem: _montar()),
                ),
              ),
              icon: const Icon(Icons.link_off),
              label: const Text('Desengatar esta carreta'),
            ),
          ],
        ],
      ),
    );
  }
}
