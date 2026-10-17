import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nucleo/nucleo.dart';

import 'entrada.dart';
import 'tema.dart';

enum TipoCampo { texto, dinheiro, inteiro, decimal, decimal3, cpf, placa, codigo, email, senha, numeros }

/// Campo de digitacao com o teclado e a mascara certos para cada tipo.
class Campo extends StatefulWidget {
  const Campo({
    super.key,
    required this.controle,
    required this.rotulo,
    this.tipo = TipoCampo.texto,
    this.dica,
    this.ajuda,
    this.erro,
    this.sufixo,
    this.aoMudar,
    this.sugestoes = const [],
    this.maiusculas = TextCapitalization.sentences,
    this.acaoTeclado = TextInputAction.next,
    this.autofoco = false,
  });

  final TextEditingController controle;
  final String rotulo;
  final TipoCampo tipo;
  final String? dica;
  final String? ajuda;
  final String? erro;
  final String? sufixo;
  final ValueChanged<String>? aoMudar;

  /// Sugestoes que aparecem enquanto digita (cidades, empresas).
  final List<String> sugestoes;
  final TextCapitalization maiusculas;
  final TextInputAction acaoTeclado;
  final bool autofoco;

  @override
  State<Campo> createState() => _CampoState();
}

class _CampoState extends State<Campo> {
  final _foco = FocusNode();
  bool _mostrarSenha = false;

  bool get _ehTextoLivre => widget.tipo == TipoCampo.texto;

  @override
  void dispose() {
    _foco.dispose();
    super.dispose();
  }

  TextInputType get _teclado {
    switch (widget.tipo) {
      case TipoCampo.texto:
      case TipoCampo.placa:
      case TipoCampo.codigo:
      case TipoCampo.senha:
        return TextInputType.text;
      case TipoCampo.email:
        return TextInputType.emailAddress;
      case TipoCampo.dinheiro:
      case TipoCampo.inteiro:
      case TipoCampo.cpf:
      case TipoCampo.numeros:
        return TextInputType.number;
      case TipoCampo.decimal:
      case TipoCampo.decimal3:
        return const TextInputType.numberWithOptions(decimal: true);
    }
  }

  List<TextInputFormatter> get _mascaras {
    switch (widget.tipo) {
      case TipoCampo.texto:
        return [LengthLimitingTextInputFormatter(80)];
      case TipoCampo.email:
        return [LengthLimitingTextInputFormatter(120), FilteringTextInputFormatter.deny(RegExp(r'\s'))];
      case TipoCampo.senha:
        return [LengthLimitingTextInputFormatter(72)];
      case TipoCampo.cpf:
        return const [FormatadorCpf()];
      case TipoCampo.placa:
        return const [FormatadorPlaca()];
      case TipoCampo.codigo:
        return const [FormatadorCodigo()];
      case TipoCampo.numeros:
        return [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)];
      case TipoCampo.dinheiro:
        return const [FormatadorDinheiro()];
      case TipoCampo.inteiro:
        return const [FormatadorInteiro()];
      case TipoCampo.decimal:
        return const [FormatadorDecimal(casas: 2)];
      case TipoCampo.decimal3:
        return const [FormatadorDecimal(casas: 3)];
    }
  }

  InputDecoration _decoracao() => InputDecoration(
        labelText: widget.rotulo,
        hintText: widget.dica ?? (widget.tipo == TipoCampo.dinheiro ? '0,00' : null),
        helperText: widget.erro == null ? widget.ajuda : null,
        helperMaxLines: 3,
        errorText: widget.erro,
        errorMaxLines: 3,
        prefixText: widget.tipo == TipoCampo.dinheiro ? 'R\$ ' : null,
        suffixText: widget.sufixo,
        suffixIcon: widget.tipo == TipoCampo.senha
            ? IconButton(
                tooltip: _mostrarSenha ? 'Esconder a senha' : 'Mostrar a senha',
                icon: Icon(_mostrarSenha ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                onPressed: () => setState(() => _mostrarSenha = !_mostrarSenha),
              )
            : null,
      );

  TextStyle get _estilo => switch (widget.tipo) {
        TipoCampo.texto || TipoCampo.email || TipoCampo.senha => const TextStyle(fontSize: 18),
        TipoCampo.codigo || TipoCampo.placa || TipoCampo.numeros =>
          estiloNumero(24, peso: FontWeight.w700).copyWith(letterSpacing: 4),
        _ => estiloNumero(20, peso: FontWeight.w500),
      };

  Widget _campo(TextEditingController c, FocusNode f, {VoidCallback? aoEnviar}) => TextField(
        controller: c,
        focusNode: f,
        autofocus: widget.autofoco,
        keyboardType: _teclado,
        inputFormatters: _mascaras,
        textCapitalization: _ehTextoLivre
            ? widget.maiusculas
            : (widget.tipo == TipoCampo.placa || widget.tipo == TipoCampo.codigo
                ? TextCapitalization.characters
                : TextCapitalization.none),
        obscureText: widget.tipo == TipoCampo.senha && !_mostrarSenha,
        autocorrect: _ehTextoLivre,
        enableSuggestions: _ehTextoLivre,
        autofillHints: switch (widget.tipo) {
          TipoCampo.email => const [AutofillHints.email],
          TipoCampo.senha => const [AutofillHints.password],
          _ => null,
        },
        textInputAction: widget.acaoTeclado,
        style: _estilo,
        decoration: _decoracao(),
        onChanged: widget.aoMudar,
        onSubmitted: (_) => aoEnviar?.call(),
      );

  @override
  Widget build(BuildContext context) {
    if (widget.sugestoes.isEmpty) return _campo(widget.controle, _foco);
    return LayoutBuilder(
      builder: (context, limites) => RawAutocomplete<String>(
        textEditingController: widget.controle,
        focusNode: _foco,
        optionsBuilder: (valor) {
          final q = valor.text.trim().toLowerCase();
          if (q.isEmpty) return const Iterable<String>.empty();
          return widget.sugestoes
              .where((s) => s.toLowerCase().contains(q) && s.toLowerCase() != q)
              .take(5);
        },
        onSelected: (s) => widget.aoMudar?.call(s),
        fieldViewBuilder: (context, c, f, aoEnviar) => _campo(c, f, aoEnviar: aoEnviar),
        optionsViewBuilder: (context, aoEscolher, opcoes) => Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(12),
            color: Theme.of(context).colorScheme.surface,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: 260, maxWidth: limites.maxWidth),
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 6),
                shrinkWrap: true,
                children: [
                  for (final o in opcoes)
                    ListTile(
                      title: Text(o, style: const TextStyle(fontSize: 16.5)),
                      leading: const Icon(Icons.history, size: 20),
                      dense: true,
                      onTap: () => aoEscolher(o),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Campo de data: toca e abre o calendário.
class CampoData extends StatelessWidget {
  const CampoData({super.key, required this.rotulo, required this.valor, required this.aoMudar, this.erro});

  final String rotulo;
  final DateTime valor;
  final ValueChanged<DateTime> aoMudar;
  final String? erro;

  Future<void> _escolher(BuildContext context) async {
    final agora = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: valor.toLocal(),
      firstDate: DateTime(2015),
      lastDate: DateTime(agora.year + 1, 12, 31),
      locale: const Locale('pt', 'BR'),
      helpText: rotulo,
      cancelText: 'Cancelar',
      confirmText: 'Pronto',
    );
    if (d != null) aoMudar(inicioDoDia(d));
  }

  @override
  Widget build(BuildContext context) {
    final ehHoje = inicioDoDia(valor) == inicioDoDia(DateTime.now());
    return InkWell(
      onTap: () => _escolher(context),
      borderRadius: BorderRadius.circular(10),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: rotulo,
          errorText: erro,
          suffixIcon: const Icon(Icons.calendar_today_outlined, size: 20),
        ),
        child: Text(
          ehHoje ? '${dataTexto(valor)}  (hoje)' : '${dataTexto(valor)}  (${diaSemana(valor)})',
          style: estiloNumero(19, peso: FontWeight.w500),
        ),
      ),
    );
  }
}

/// Opcao grande para escolher entre duas ou mais respostas.
class OpcaoEscolha<T> extends StatelessWidget {
  const OpcaoEscolha({
    super.key,
    required this.valor,
    required this.escolhido,
    required this.titulo,
    this.descricao,
    required this.aoEscolher,
  });

  final T valor;
  final T escolhido;
  final String titulo;
  final String? descricao;
  final ValueChanged<T> aoEscolher;

  @override
  Widget build(BuildContext context) {
    final marcado = valor == escolhido;
    final esquema = Theme.of(context).colorScheme;
    final cores = context.cores;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: marcado ? esquema.primaryContainer.withValues(alpha: 0.55) : cores.campoFundo,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: marcado ? esquema.primary : esquema.outline, width: marcado ? 2 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => aoEscolher(valor),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 16, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  marcado ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: marcado ? esquema.primary : cores.textoFraco,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titulo, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                      if (descricao != null) ...[
                        const SizedBox(height: 3),
                        Text(descricao!, style: TextStyle(fontSize: 15, height: 1.35, color: cores.textoFraco)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Duas opcoes curtas lado a lado.
class EscolhaDupla extends StatelessWidget {
  const EscolhaDupla({
    super.key,
    required this.valor,
    required this.textoSim,
    required this.textoNao,
    required this.aoMudar,
  });

  final bool valor;
  final String textoSim;
  final String textoNao;
  final ValueChanged<bool> aoMudar;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<bool>(
        showSelectedIcon: false,
        segments: [
          ButtonSegment(value: true, label: Text(textoSim)),
          ButtonSegment(value: false, label: Text(textoNao)),
        ],
        selected: {valor},
        onSelectionChanged: (s) => aoMudar(s.first),
      ),
    );
  }
}
