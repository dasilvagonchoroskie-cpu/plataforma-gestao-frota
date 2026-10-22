import 'package:flutter/material.dart';

import 'basicos.dart';
import 'campos.dart';
import 'tema.dart';
import 'textos_legais.dart';

// Telas de conta usadas pelos dois apps: termos de uso, pedir o link para
// criar a senha nova e confirmação digitada.

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

/// Pede o aceite dos Termos de Uso e da Política de Privacidade. Com
/// [naAbertura], é a primeira tela do app (antes de entrar): sem aceitar não
/// dá para usar, e "Não aceito" fecha o app. Sem ela, é o aceite de uma conta
/// já logada (versão nova) e "Não aceito" sai da conta.
/// [aceitar] devolve a mensagem de erro ou nulo.
class TelaAceiteTermos extends StatefulWidget {
  const TelaAceiteTermos({super.key, required this.aceitar, required this.sair, this.naAbertura = false});
  final Future<String?> Function() aceitar;
  final VoidCallback sair;
  final bool naAbertura;

  @override
  State<TelaAceiteTermos> createState() => _TelaAceiteTermosState();
}

class _TelaAceiteTermosState extends State<TelaAceiteTermos> {
  bool _marcado = false;
  bool _ocupado = false;
  bool _faltaMarcar = false;
  bool _recusou = false;
  String? _erro;

  void _naoAceito() {
    if (widget.naAbertura) setState(() => _recusou = true);
    widget.sair();
  }

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
              '${widget.naAbertura ? 'Antes de começar' : 'Para continuar'}, leia e aceite os Termos de Uso e a '
              'Política de Privacidade. Eles explicam o que a plataforma faz, quem vê os seus dados, por quanto '
              'tempo ficam guardados e como excluir a conta.',
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
              onPressed: _ocupado ? null : _naoAceito,
              icon: Icon(widget.naAbertura ? Icons.close : Icons.logout),
              label: Text(widget.naAbertura ? 'Não aceito' : 'Não aceito, sair da conta'),
            ),
            if (_recusou)
              const Aviso(
                icone: Icons.block,
                texto: 'Sem aceitar, não dá para usar. Se mudar de ideia, marque a caixa e toque em '
                    '"Aceitar e continuar".',
              ),
          ],
        ),
      ),
      bottomNavigationBar: RodapeBotao(texto: _ocupado ? 'Aguarde...' : 'Aceitar e continuar', aoTocar: _ocupado ? null : _aceitar),
    );
  }
}

/// Esqueci a senha: a pessoa informa o CPF (motorista) ou o e-mail (dono e
/// gestor) e recebe no e-mail um link para criar a senha nova.
/// [pedir] devolve a mensagem do servidor (ou lança a exceção com o erro).
class TelaPedirLinkSenha extends StatefulWidget {
  const TelaPedirLinkSenha({
    super.key,
    required this.porCpf,
    required this.pedir,
    required this.semEmail,
    this.extras = const [],
  });

  final bool porCpf;
  final Future<String> Function(String identificador) pedir;

  /// O que fazer quando não tem acesso ao e-mail (texto curto).
  final String semEmail;

  /// Botões a mais embaixo (ex.: "Já tenho a senha provisória").
  final List<Widget> extras;

  @override
  State<TelaPedirLinkSenha> createState() => _TelaPedirLinkSenhaState();
}

class _TelaPedirLinkSenhaState extends State<TelaPedirLinkSenha> {
  final _ident = TextEditingController();
  String? _erro;
  String? _enviado;
  bool _ocupado = false;

  @override
  void dispose() {
    _ident.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final ident = widget.porCpf ? _ident.text.replaceAll(RegExp(r'[^0-9]'), '') : _ident.text.trim().toLowerCase();
    final certo = widget.porCpf ? ident.length == 11 : RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(ident);
    if (!certo) {
      setState(() => _erro = widget.porCpf ? 'Confira o CPF: tem 11 números.' : 'Confira o e-mail.');
      return;
    }
    setState(() {
      _erro = null;
      _ocupado = true;
    });
    try {
      final mensagem = await widget.pedir(ident);
      if (mounted) setState(() => _enviado = mensagem);
    } catch (e) {
      if (mounted) setState(() => _erro = '$e');
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enviado = _enviado != null;
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
              children: [
                Text('Esqueci a senha', style: context.textos.headlineSmall?.copyWith(fontSize: 28)),
                const SizedBox(height: 10),
                Text(
                  widget.porCpf
                      ? 'Digite o seu CPF. Mandamos um link para o e-mail que você cadastrou no app. '
                          'Abrindo o link, você cria a senha nova.'
                      : 'Digite o seu e-mail. Mandamos um link para ele. Abrindo o link, você cria a senha nova.',
                  style: TextStyle(fontSize: 17, height: 1.4, color: context.cores.textoFraco),
                ),
                const SizedBox(height: 24),
                if (enviado) ...[
                  Aviso(icone: Icons.mark_email_read_outlined, titulo: 'Pedido feito', texto: _enviado!),
                  const SizedBox(height: 12),
                  const Nota('O link vale por 1 hora e só funciona uma vez. Não chegou? Confira a caixa de spam '
                      'ou peça de novo daqui a um minuto.'),
                ] else
                  Campo(
                    controle: _ident,
                    rotulo: widget.porCpf ? 'CPF' : 'E-mail',
                    tipo: widget.porCpf ? TipoCampo.cpf : TipoCampo.email,
                    dica: widget.porCpf ? '000.000.000-00' : null,
                    autofoco: true,
                    acaoTeclado: TextInputAction.done,
                  ),
                if (_erro != null) ...[const SizedBox(height: 16), Aviso(texto: _erro!, icone: Icons.error_outline)],
                const SizedBox(height: 20),
                Aviso(icone: Icons.help_outline, titulo: 'Não tem acesso ao e-mail?', texto: widget.semEmail),
                ...widget.extras,
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: RodapeBotao(
        texto: enviado ? 'Voltar' : (_ocupado ? 'Aguarde...' : 'Mandar o link'),
        aoTocar: enviado ? () => Navigator.pop(context) : (_ocupado ? null : _enviar),
      ),
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
