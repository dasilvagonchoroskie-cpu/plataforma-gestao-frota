import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nucleo/nucleo.dart' show ajudaSenha, mensagemSenha, senhaAceita;

import 'basicos.dart';
import 'campos.dart';
import 'tema.dart';
import 'textos_legais.dart';

// Telas de conta usadas pelos dois apps: termos de uso, código de
// recuperação, recuperar o acesso com o código e confirmação digitada.

/// Mostra um texto legal (títulos com "# " e "## ", itens com "- ").
class TextoLegal extends StatelessWidget {
  const TextoLegal(this.texto, {super.key});
  final String texto;

  @override
  Widget build(BuildContext context) {
    final filhos = <Widget>[];
    for (final linha in texto.split('\n')) {
      if (linha.trim().isEmpty) continue;
      if (linha.startsWith('# ')) {
        filhos.add(Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(linha.substring(2), style: context.textos.headlineSmall),
        ));
      } else if (linha.startsWith('## ')) {
        filhos.add(Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 6),
          child: Text(linha.substring(3), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        ));
      } else if (linha.startsWith('- ')) {
        filhos.add(Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('•  ', style: TextStyle(fontSize: 16, height: 1.45)),
              Expanded(child: Text(linha.substring(2), style: const TextStyle(fontSize: 16, height: 1.45))),
            ],
          ),
        ));
      } else {
        filhos.add(Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(linha, style: const TextStyle(fontSize: 16, height: 1.45)),
        ));
      }
    }
    return SelectionArea(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: filhos),
    );
  }
}

class TelaTextoLegal extends StatelessWidget {
  const TelaTextoLegal({super.key, required this.titulo, required this.texto});
  final String titulo;
  final String texto;

  static Route<void> rota(String titulo, String texto) =>
      MaterialPageRoute(builder: (_) => TelaTextoLegal(titulo: titulo, texto: texto));

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(titulo)),
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 32), children: [TextoLegal(texto)]),
        ),
      );
}

/// Dois botões para abrir os Termos de Uso e a Política de Privacidade.
class LinksLegais extends StatelessWidget {
  const LinksLegais({super.key});

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 4,
        children: [
          TextButton(
            onPressed: () => Navigator.push(context, TelaTextoLegal.rota('Termos de Uso', termosDeUso)),
            child: const Text('Termos de Uso'),
          ),
          TextButton(
            onPressed: () => Navigator.push(context, TelaTextoLegal.rota('Política de Privacidade', politicaDePrivacidade)),
            child: const Text('Política de Privacidade'),
          ),
        ],
      );
}

/// Caixa de "li e aceito" com os links para ler os dois textos.
class CaixaAceite extends StatelessWidget {
  const CaixaAceite({super.key, required this.marcado, required this.aoMudar, this.erro = false});
  final bool marcado;
  final ValueChanged<bool> aoMudar;
  final bool erro;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CheckboxListTile(
            value: marcado,
            onChanged: (v) => aoMudar(v ?? false),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(
              'Li e aceito os Termos de Uso e a Política de Privacidade.',
              style: TextStyle(fontSize: 16, color: erro ? context.cores.negativo : null),
            ),
          ),
          const LinksLegais(),
        ],
      );
}

/// Pede o aceite dos Termos de Uso e da Política de Privacidade (primeiro
/// acesso ou versão nova). [aceitar] devolve a mensagem de erro ou nulo.
class TelaAceiteTermos extends StatefulWidget {
  const TelaAceiteTermos({super.key, required this.aceitar, required this.sair});
  final Future<String?> Function() aceitar;
  final VoidCallback sair;

  @override
  State<TelaAceiteTermos> createState() => _TelaAceiteTermosState();
}

class _TelaAceiteTermosState extends State<TelaAceiteTermos> {
  bool _marcado = false;
  bool _ocupado = false;
  bool _faltaMarcar = false;
  String? _erro;

  Future<void> _aceitar() async {
    if (!_marcado) {
      setState(() => _faltaMarcar = true);
      return;
    }
    setState(() {
      _ocupado = true;
      _erro = null;
    });
    final erro = await widget.aceitar();
    if (mounted) {
      setState(() {
        _ocupado = false;
        _erro = erro;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
          children: [
            Text('Termos de Uso e Privacidade', style: context.textos.headlineSmall?.copyWith(fontSize: 28)),
            const SizedBox(height: 10),
            Text(
              'Para continuar, leia e aceite os Termos de Uso e a Política de Privacidade. Eles explicam o que a '
              'plataforma faz, quem vê os seus dados, por quanto tempo ficam guardados e como excluir a conta.',
              style: TextStyle(fontSize: 17, height: 1.4, color: context.cores.textoFraco),
            ),
            const SizedBox(height: 16),
            Card(
              child: Column(children: [
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('Termos de Uso', style: TextStyle(fontSize: 17)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(context, TelaTextoLegal.rota('Termos de Uso', termosDeUso)),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Política de Privacidade', style: TextStyle(fontSize: 17)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                      context, TelaTextoLegal.rota('Política de Privacidade', politicaDePrivacidade)),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              value: _marcado,
              onChanged: (v) => setState(() {
                _marcado = v ?? false;
                _faltaMarcar = false;
              }),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(
                'Li e aceito os Termos de Uso e a Política de Privacidade.',
                style: TextStyle(fontSize: 16, color: _faltaMarcar ? context.cores.negativo : null),
              ),
            ),
            if (_erro != null) ...[const SizedBox(height: 12), Aviso(texto: _erro!, icone: Icons.error_outline)],
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _ocupado ? null : widget.sair,
              icon: const Icon(Icons.logout),
              label: const Text('Não aceito, sair da conta'),
            ),
          ],
        ),
      ),
      bottomNavigationBar: RodapeBotao(texto: _ocupado ? 'Aguarde...' : 'Aceitar e continuar', aoTocar: _ocupado ? null : _aceitar),
    );
  }
}

/// O código de recuperação em letras grandes, com botão para copiar.
class CartaoCodigoRecuperacao extends StatelessWidget {
  const CartaoCodigoRecuperacao(this.codigo, {super.key});
  final String codigo;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
        decoration: BoxDecoration(
          color: Paleta.verdePlaca,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Column(
          children: [
            SelectableText(
              codigo,
              textAlign: TextAlign.center,
              style: estiloNumero(32, peso: FontWeight.w700, cor: Colors.white).copyWith(letterSpacing: 2),
            ),
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: codigo));
                if (context.mounted) mostrarMensagem(context, 'Código copiado.');
              },
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              icon: const Icon(Icons.copy),
              label: const Text('Copiar'),
            ),
          ],
        ),
      );
}

/// Gera e mostra o código de recuperação. Com [codigoPronto], só mostra.
class TelaCodigoRecuperacao extends StatefulWidget {
  const TelaCodigoRecuperacao({
    super.key,
    required this.gerar,
    required this.concluir,
    this.codigoPronto,
    this.voltar = false,
    this.comoEntrar = 'o seu CPF',
  });

  /// Gera o código no servidor (lança exceção com a mensagem se falhar).
  final Future<String> Function() gerar;
  final VoidCallback concluir;
  final String? codigoPronto;
  final bool voltar;

  /// Como a pessoa se identifica ao recuperar ("o seu CPF" ou "o seu e-mail").
  final String comoEntrar;

  @override
  State<TelaCodigoRecuperacao> createState() => _TelaCodigoRecuperacaoState();
}

class _TelaCodigoRecuperacaoState extends State<TelaCodigoRecuperacao> {
  late String? _codigo = widget.codigoPronto;
  bool _anotado = false;
  bool _faltaMarcar = false;
  bool _ocupado = false;
  String? _erro;

  Future<void> _gerar() async {
    setState(() {
      _ocupado = true;
      _erro = null;
    });
    try {
      final c = await widget.gerar();
      if (mounted) setState(() => _codigo = c);
    } catch (e) {
      if (mounted) setState(() => _erro = '$e');
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  void _continuar() {
    if (!_anotado) {
      setState(() => _faltaMarcar = true);
      return;
    }
    widget.concluir();
  }

  @override
  Widget build(BuildContext context) {
    final cores = context.cores;
    final temCodigo = _codigo != null;
    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: widget.voltar),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
          children: [
            Text('Código de recuperação', style: context.textos.headlineSmall?.copyWith(fontSize: 28)),
            const SizedBox(height: 10),
            Text(
              'Se um dia esquecer a senha, você cria outra com ${widget.comoEntrar} e este código, sem depender de '
              'ninguém. Anote num papel ou tire um print e guarde em lugar seguro. Não mande para ninguém.',
              style: TextStyle(fontSize: 17, height: 1.4, color: cores.textoFraco),
            ),
            const SizedBox(height: 20),
            if (temCodigo) ...[
              CartaoCodigoRecuperacao(_codigo!),
              const SizedBox(height: 12),
              CheckboxListTile(
                value: _anotado,
                onChanged: (v) => setState(() {
                  _anotado = v ?? false;
                  _faltaMarcar = false;
                }),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text('Já anotei o código em lugar seguro.',
                    style: TextStyle(fontSize: 16, color: _faltaMarcar ? cores.negativo : null)),
              ),
              const Nota('Gerar um código novo depois (em Configurações) faz este parar de valer.'),
            ] else
              const Nota('O código aparece uma vez só. Depois dá para gerar outro em Configurações.'),
            if (_erro != null) ...[const SizedBox(height: 12), Aviso(texto: _erro!, icone: Icons.error_outline)],
          ],
        ),
      ),
      bottomNavigationBar: RodapeBotao(
        texto: _ocupado ? 'Aguarde...' : (temCodigo ? 'Continuar' : 'Gerar o meu código'),
        aoTocar: _ocupado ? null : (temCodigo ? _continuar : _gerar),
      ),
    );
  }
}

/// Esqueci a senha: identificação (CPF ou e-mail), código de recuperação e
/// senha nova. [recuperar] devolve o código novo; [entrar] faz o login.
class TelaRecuperarComCodigo extends StatefulWidget {
  const TelaRecuperarComCodigo({
    super.key,
    required this.porCpf,
    required this.recuperar,
    required this.entrar,
    this.semCodigo,
  });

  final bool porCpf;
  final Future<String> Function(String identificador, String codigo, String senha) recuperar;
  final Future<void> Function(String identificador, String senha) entrar;

  /// O que fazer quando a pessoa não tem o código (texto curto).
  final String? semCodigo;

  @override
  State<TelaRecuperarComCodigo> createState() => _TelaRecuperarComCodigoState();
}

class _TelaRecuperarComCodigoState extends State<TelaRecuperarComCodigo> {
  final _ident = TextEditingController();
  final _codigo = TextEditingController();
  final _senha = TextEditingController();
  String? _erro;
  bool _ocupado = false;

  @override
  void dispose() {
    _ident.dispose();
    _codigo.dispose();
    _senha.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final ident = widget.porCpf ? _ident.text.replaceAll(RegExp(r'[^0-9]'), '') : _ident.text.trim().toLowerCase();
    String? erro;
    if (widget.porCpf ? ident.length != 11 : !ident.contains('@')) {
      erro = widget.porCpf ? 'Confira o CPF: tem 11 números.' : 'Confira o e-mail.';
    } else if (_codigo.text.replaceAll('-', '').length != 12) {
      erro = 'O código de recuperação tem 12 letras e números.';
    } else if (!senhaAceita(_senha.text)) {
      erro = mensagemSenha;
    }
    setState(() => _erro = erro);
    if (erro != null) return;
    setState(() => _ocupado = true);
    try {
      final novo = await widget.recuperar(ident, _codigo.text, _senha.text);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (ctx) => TelaCodigoRecuperacao(
            codigoPronto: novo,
            gerar: () async => novo,
            concluir: () => Navigator.pop(ctx),
            comoEntrar: widget.porCpf ? 'o seu CPF' : 'o seu e-mail',
          ),
        ),
      );
      await widget.entrar(ident, _senha.text);
    } catch (e) {
      if (mounted) setState(() => _erro = '$e');
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
          children: [
            Text('Criar senha nova', style: context.textos.headlineSmall?.copyWith(fontSize: 28)),
            const SizedBox(height: 10),
            Text(
              'Use o código de recuperação que você anotou quando criou a conta.',
              style: TextStyle(fontSize: 17, height: 1.4, color: context.cores.textoFraco),
            ),
            const SizedBox(height: 24),
            Campo(
              controle: _ident,
              rotulo: widget.porCpf ? 'CPF' : 'E-mail',
              tipo: widget.porCpf ? TipoCampo.cpf : TipoCampo.email,
              dica: widget.porCpf ? '000.000.000-00' : null,
              autofoco: true,
            ),
            const SizedBox(height: 16),
            Campo(controle: _codigo, rotulo: 'Código de recuperação', tipo: TipoCampo.recuperacao, dica: 'ABCD-EFGH-JKLM'),
            const SizedBox(height: 16),
            Campo(
              controle: _senha,
              rotulo: 'Senha nova',
              tipo: TipoCampo.senha,
              ajuda: ajudaSenha,
              acaoTeclado: TextInputAction.done,
            ),
            if (_erro != null) ...[const SizedBox(height: 16), Aviso(texto: _erro!, icone: Icons.error_outline)],
            if (widget.semCodigo != null) ...[const SizedBox(height: 20), Nota(widget.semCodigo!)],
          ],
        ),
      ),
      bottomNavigationBar: RodapeBotao(texto: _ocupado ? 'Aguarde...' : 'Criar a senha nova', aoTocar: _ocupado ? null : _enviar),
    );
  }
}

/// Confirmação de ação sem volta: a pessoa digita [palavra] para liberar.
Future<bool> confirmarDigitando(
  BuildContext context, {
  required String titulo,
  required String texto,
  required String palavra,
  String botao = 'Excluir',
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (_) => _DialogoDigitar(titulo: titulo, texto: texto, palavra: palavra, botao: botao),
  );
  return r ?? false;
}

class _DialogoDigitar extends StatefulWidget {
  const _DialogoDigitar({required this.titulo, required this.texto, required this.palavra, required this.botao});
  final String titulo;
  final String texto;
  final String palavra;
  final String botao;

  @override
  State<_DialogoDigitar> createState() => _DialogoDigitarState();
}

class _DialogoDigitarState extends State<_DialogoDigitar> {
  final _controle = TextEditingController();

  static String _normal(String t) => t.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  @override
  void dispose() {
    _controle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final igual = _normal(_controle.text) == _normal(widget.palavra);
    return AlertDialog(
      title: Text(widget.titulo),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.texto, style: const TextStyle(fontSize: 16, height: 1.35)),
            const SizedBox(height: 14),
            Text('Para confirmar, digite: ${widget.palavra}', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(controller: _controle, autofocus: true, onChanged: (_) => setState(() {})),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        FilledButton(
          onPressed: igual ? () => Navigator.pop(context, true) : null,
          style: FilledButton.styleFrom(backgroundColor: context.cores.negativo),
          child: Text(widget.botao),
        ),
      ],
    );
  }
}
