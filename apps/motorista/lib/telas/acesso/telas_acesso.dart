import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleo/nucleo.dart';
import 'package:visual/visual.dart';

import '../../acesso/acesso.dart';
import '../../dados/dados.dart';
import '../../servidor/servidor.dart';

/// Moldura das telas de acesso: título grande, explicação curta, os campos e
/// um botão principal embaixo. Uma ação por tela.
class PaginaAcesso extends StatelessWidget {
  const PaginaAcesso({
    super.key,
    required this.titulo,
    this.texto,
    required this.filhos,
    this.botao,
    this.aoTocar,
    this.ocupado = false,
    this.voltar = true,
  });

  final String titulo;
  final String? texto;
  final List<Widget> filhos;
  final String? botao;
  final VoidCallback? aoTocar;
  final bool ocupado;
  final bool voltar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: voltar),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
          children: [
            Text(titulo, style: context.textos.headlineSmall?.copyWith(fontSize: 30)),
            if (texto != null) ...[
              const SizedBox(height: 10),
              Text(texto!, style: TextStyle(fontSize: 17, height: 1.4, color: context.cores.textoFraco)),
            ],
            const SizedBox(height: 24),
            ...filhos,
          ],
        ),
      ),
      bottomNavigationBar: botao == null
          ? null
          : RodapeBotao(texto: ocupado ? 'Aguarde...' : botao!, aoTocar: ocupado ? null : aoTocar),
    );
  }
}

/// Faixa vermelha de erro, em português simples.
class MensagemErro extends StatelessWidget {
  const MensagemErro(this.texto, {super.key});
  final String? texto;

  @override
  Widget build(BuildContext context) {
    if (texto == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Aviso(texto: texto!, icone: Icons.error_outline),
    );
  }
}

String _aparelho() => 'motorista-app';

// ------------------------------------------------------------------ início

class TelaBoasVindas extends StatelessWidget {
  const TelaBoasVindas({super.key});

  @override
  Widget build(BuildContext context) {
    final cores = context.cores;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Placa(rotulo: 'Plataforma de Gestão de Frota', valor: 'Motorista', tamanhoValor: 44),
              const SizedBox(height: 24),
              Text(
                'Anote seus fretes, diesel, gastos e vales. O seu patrão vê tudo no painel, sem precisar mandar PDF.',
                style: TextStyle(fontSize: 18, height: 1.4, color: cores.textoFraco),
              ),
              const SizedBox(height: 12),
              Text(
                'Funciona sem internet: o que você lançar fica guardado e é enviado quando tiver sinal.',
                style: TextStyle(fontSize: 16, height: 1.4, color: cores.textoFraco),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TelaEntrar())),
                icon: const Icon(Icons.login),
                label: const Text('Entrar com CPF e senha'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TelaCriarConta())),
                icon: const Icon(Icons.person_add_alt),
                label: const Text('Criar minha conta'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TelaEsqueciSenha())),
                child: const Text('Esqueci a senha'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------- entrar (CPF)

class TelaEntrar extends ConsumerStatefulWidget {
  const TelaEntrar({super.key, this.depois});

  /// Chamado depois de entrar (quando a sessão venceu com o app em uso).
  final VoidCallback? depois;

  @override
  ConsumerState<TelaEntrar> createState() => _TelaEntrarState();
}

class _TelaEntrarState extends ConsumerState<TelaEntrar> {
  final _cpf = TextEditingController();
  final _senha = TextEditingController();
  String? _erro;
  String? _erroCpf;
  bool _ocupado = false;

  @override
  void dispose() {
    _cpf.dispose();
    _senha.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    setState(() {
      _erro = null;
      _erroCpf = cpfValido(_cpf.text) ? null : 'Confira o CPF: tem 11 números.';
    });
    if (_erroCpf != null) return;
    if (_senha.text.isEmpty) {
      setState(() => _erro = 'Digite a sua senha.');
      return;
    }
    setState(() => _ocupado = true);
    try {
      final s = ref.read(servidorProvider);
      await s.entrarComCpf(soDigitos(_cpf.text), _senha.text, _aparelho());
      if (!mounted) return;
      if (s.precisaTrocarSenha) {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => const TelaTrocarSenha()));
        if (!mounted) return;
      }
      widget.depois?.call();
      await ref.read(acessoProvider.notifier).recarregar();
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } on ErroServidor catch (e) {
      setState(() => _erro = e.mensagem);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PaginaAcesso(
      titulo: 'Entrar',
      texto: 'Use o CPF e a senha que você criou no cadastro.',
      botao: 'Entrar',
      aoTocar: _entrar,
      ocupado: _ocupado,
      filhos: [
        Campo(controle: _cpf, rotulo: 'CPF', tipo: TipoCampo.cpf, dica: '000.000.000-00', erro: _erroCpf, autofoco: true),
        const SizedBox(height: 16),
        Campo(controle: _senha, rotulo: 'Senha', tipo: TipoCampo.senha, acaoTeclado: TextInputAction.done),
        MensagemErro(_erro),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TelaEsqueciSenha())),
            child: const Text('Esqueci a senha'),
          ),
        ),
        const Nota('Perdeu o acesso ao e-mail? Peça para o seu patrão criar uma senha provisória pelo painel.'),
      ],
    );
  }
}

// ----------------------------------------------------------- criar conta

/// Cadastro em três passos: e-mail, código que chega no e-mail, nome/CPF/senha.
class TelaCriarConta extends ConsumerStatefulWidget {
  const TelaCriarConta({super.key});

  @override
  ConsumerState<TelaCriarConta> createState() => _TelaCriarContaState();
}

class _TelaCriarContaState extends ConsumerState<TelaCriarConta> {
  final _email = TextEditingController();
  final _codigo = TextEditingController();
  int _passo = 0;
  String? _erro;
  bool _ocupado = false;

  @override
  void dispose() {
    _email.dispose();
    _codigo.dispose();
    super.dispose();
  }

  bool get _emailOk => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.text.trim());

  Future<void> _rodar(Future<void> Function() f) async {
    setState(() {
      _erro = null;
      _ocupado = true;
    });
    try {
      await f();
    } on ErroServidor catch (e) {
      setState(() => _erro = e.mensagem);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _pedirCodigo() async {
    if (!_emailOk) {
      setState(() => _erro = 'Este e-mail não parece certo. Confira.');
      return;
    }
    await _rodar(() async {
      await ref.read(servidorProvider).pedirCodigoCadastro(_email.text);
      setState(() => _passo = 1);
    });
  }

  Future<void> _confirmar() async {
    if (_codigo.text.trim().length < 6) {
      setState(() => _erro = 'Digite os 6 números que chegaram no e-mail.');
      return;
    }
    await _rodar(() async {
      await ref.read(servidorProvider).confirmarCodigoCadastro(_email.text, _codigo.text);
      if (!mounted) return;
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => TelaCompletarCadastro(email: _email.text.trim().toLowerCase())),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_passo == 0) {
      return PaginaAcesso(
        titulo: 'Criar conta',
        texto: 'Digite o seu e-mail. Vamos mandar um código de 6 números para confirmar que ele é seu.',
        botao: 'Mandar o código',
        aoTocar: _pedirCodigo,
        ocupado: _ocupado,
        filhos: [
          Campo(controle: _email, rotulo: 'E-mail', tipo: TipoCampo.email, dica: 'nome@gmail.com', autofoco: true),
          MensagemErro(_erro),
        ],
      );
    }
    return PaginaAcesso(
      titulo: 'Digite o código',
      texto: 'Mandamos um código para ${_email.text.trim()}. Olhe também na caixa de spam.',
      botao: 'Confirmar',
      aoTocar: _confirmar,
      ocupado: _ocupado,
      filhos: [
        Campo(controle: _codigo, rotulo: 'Código de 6 números', tipo: TipoCampo.numeros, autofoco: true),
        MensagemErro(_erro),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(onPressed: _ocupado ? null : _pedirCodigo, child: const Text('Mandar outro código')),
        ),
        TextButton(
          onPressed: () => setState(() {
            _passo = 0;
            _codigo.clear();
            _erro = null;
          }),
          child: const Text('Trocar o e-mail'),
        ),
      ],
    );
  }
}

/// Nome, CPF e senha (depois do e-mail confirmado).
class TelaCompletarCadastro extends ConsumerStatefulWidget {
  const TelaCompletarCadastro({super.key, required this.email, this.voltar = true});
  final String email;
  final bool voltar;

  @override
  ConsumerState<TelaCompletarCadastro> createState() => _TelaCompletarCadastroState();
}

class _TelaCompletarCadastroState extends ConsumerState<TelaCompletarCadastro> {
  final _nome = TextEditingController();
  final _cpf = TextEditingController();
  final _senha = TextEditingController();
  String? _erro;
  String? _erroNome;
  String? _erroCpf;
  String? _erroSenha;
  bool _ocupado = false;

  @override
  void dispose() {
    _nome.dispose();
    _cpf.dispose();
    _senha.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    setState(() {
      _erro = null;
      _erroNome = _nome.text.trim().length < 2 ? 'Escreva o seu nome.' : null;
      _erroCpf = cpfValido(_cpf.text) ? null : 'O CPF não está certo. Confira os números.';
      _erroSenha = _senha.text.length < 6 ? 'A senha precisa ter pelo menos 6 letras ou números.' : null;
    });
    if (_erroNome != null || _erroCpf != null || _erroSenha != null) return;
    setState(() => _ocupado = true);
    try {
      final s = ref.read(servidorProvider);
      await s.definirSenha(_senha.text);
      await s.completarCadastro(_nome.text.trim(), soDigitos(_cpf.text));
      await ref.read(acessoProvider.notifier).recarregar();
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } on ErroServidor catch (e) {
      setState(() => _erro = e.mensagem);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PaginaAcesso(
      titulo: 'Seus dados',
      texto: 'E-mail confirmado: ${widget.email}. Agora o seu nome, o CPF e uma senha para entrar.',
      botao: 'Criar conta',
      aoTocar: _salvar,
      ocupado: _ocupado,
      voltar: widget.voltar,
      filhos: [
        Campo(controle: _nome, rotulo: 'Nome completo', erro: _erroNome, maiusculas: TextCapitalization.words, autofoco: true),
        const SizedBox(height: 16),
        Campo(controle: _cpf, rotulo: 'CPF', tipo: TipoCampo.cpf, dica: '000.000.000-00', erro: _erroCpf),
        const SizedBox(height: 16),
        Campo(
          controle: _senha,
          rotulo: 'Crie uma senha',
          tipo: TipoCampo.senha,
          ajuda: 'Pelo menos 6 letras ou números. Você vai usar com o CPF para entrar.',
          erro: _erroSenha,
          acaoTeclado: TextInputAction.done,
        ),
        MensagemErro(_erro),
      ],
    );
  }
}

// ------------------------------------------------------------ esqueci a senha

class TelaEsqueciSenha extends ConsumerStatefulWidget {
  const TelaEsqueciSenha({super.key});

  @override
  ConsumerState<TelaEsqueciSenha> createState() => _TelaEsqueciSenhaState();
}

class _TelaEsqueciSenhaState extends ConsumerState<TelaEsqueciSenha> {
  final _email = TextEditingController();
  final _codigo = TextEditingController();
  int _passo = 0;
  String? _erro;
  bool _ocupado = false;

  @override
  void dispose() {
    _email.dispose();
    _codigo.dispose();
    super.dispose();
  }

  Future<void> _rodar(Future<void> Function() f) async {
    setState(() {
      _erro = null;
      _ocupado = true;
    });
    try {
      await f();
    } on ErroServidor catch (e) {
      setState(() => _erro = e.mensagem);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_passo == 0) {
      return PaginaAcesso(
        titulo: 'Esqueci a senha',
        texto: 'Digite o e-mail do seu cadastro. Se ele estiver certo, chega um código para criar uma senha nova.',
        botao: 'Mandar o código',
        ocupado: _ocupado,
        aoTocar: () => _rodar(() async {
          await ref.read(servidorProvider).pedirCodigoSenha(_email.text);
          setState(() => _passo = 1);
        }),
        filhos: [
          Campo(controle: _email, rotulo: 'E-mail', tipo: TipoCampo.email, autofoco: true),
          MensagemErro(_erro),
          const SizedBox(height: 16),
          const Nota('Perdeu o acesso ao e-mail? Peça para o seu patrão criar uma senha provisória pelo painel.'),
        ],
      );
    }
    return PaginaAcesso(
      titulo: 'Digite o código',
      texto: 'Se o e-mail ${_email.text.trim()} tiver cadastro, o código chegou lá. Olhe também no spam.',
      botao: 'Continuar',
      ocupado: _ocupado,
      aoTocar: () => _rodar(() async {
        await ref.read(servidorProvider).confirmarCodigoSenha(_email.text, _codigo.text);
        if (!mounted) return;
        await Navigator.pushReplacement(this.context, MaterialPageRoute(builder: (_) => const TelaTrocarSenha()));
      }),
      filhos: [
        Campo(controle: _codigo, rotulo: 'Código de 6 números', tipo: TipoCampo.numeros, autofoco: true),
        MensagemErro(_erro),
      ],
    );
  }
}

/// Senha nova (depois do código ou da senha provisória do gestor).
class TelaTrocarSenha extends ConsumerStatefulWidget {
  const TelaTrocarSenha({super.key, this.voltar = true});
  final bool voltar;

  @override
  ConsumerState<TelaTrocarSenha> createState() => _TelaTrocarSenhaState();
}

class _TelaTrocarSenhaState extends ConsumerState<TelaTrocarSenha> {
  final _senha = TextEditingController();
  String? _erro;
  bool _ocupado = false;

  @override
  void dispose() {
    _senha.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (_senha.text.length < 6) {
      setState(() => _erro = 'A senha precisa ter pelo menos 6 letras ou números.');
      return;
    }
    setState(() {
      _erro = null;
      _ocupado = true;
    });
    try {
      await ref.read(servidorProvider).definirSenha(_senha.text);
      if (!mounted) return;
      mostrarMensagem(context, 'Senha nova salva.');
      await ref.read(acessoProvider.notifier).recarregar();
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } on ErroServidor catch (e) {
      setState(() => _erro = e.mensagem);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PaginaAcesso(
      titulo: 'Senha nova',
      texto: 'Crie uma senha que só você saiba. Pelo menos 6 letras ou números.',
      botao: 'Salvar a senha',
      aoTocar: _salvar,
      ocupado: _ocupado,
      voltar: widget.voltar,
      filhos: [
        Campo(controle: _senha, rotulo: 'Senha nova', tipo: TipoCampo.senha, autofoco: true, acaoTeclado: TextInputAction.done),
        MensagemErro(_erro),
      ],
    );
  }
}

// ----------------------------------------------------- entrada na empresa

class TelaCodigoEmpresa extends ConsumerStatefulWidget {
  const TelaCodigoEmpresa({super.key, this.mensagem});
  final String? mensagem;

  @override
  ConsumerState<TelaCodigoEmpresa> createState() => _TelaCodigoEmpresaState();
}

class _TelaCodigoEmpresaState extends ConsumerState<TelaCodigoEmpresa> {
  final _codigo = TextEditingController();
  String? _erro;
  bool _ocupado = false;

  @override
  void dispose() {
    _codigo.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (_codigo.text.length != 6) {
      setState(() => _erro = 'O código tem 6 letras e números.');
      return;
    }
    setState(() {
      _erro = null;
      _ocupado = true;
    });
    try {
      final r = await ref.read(servidorProvider).pedirEntrada(_codigo.text);
      if (r['ok'] != true) {
        setState(() => _erro = '${r['mensagem'] ?? 'Código não encontrado.'}');
        return;
      }
      await ref.read(acessoProvider.notifier).recarregar();
    } on ErroServidor catch (e) {
      setState(() => _erro = e.mensagem);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PaginaAcesso(
      titulo: 'Código da empresa',
      texto: 'Peça o código para o seu patrão (ele vê no painel e manda pelo WhatsApp).',
      botao: 'Pedir para entrar',
      aoTocar: _enviar,
      ocupado: _ocupado,
      voltar: false,
      filhos: [
        if (widget.mensagem != null) ...[Aviso(texto: widget.mensagem!), const SizedBox(height: 16)],
        Campo(controle: _codigo, rotulo: 'Código (6 letras e números)', tipo: TipoCampo.codigo, dica: 'ABC234', autofoco: true),
        MensagemErro(_erro),
        const SizedBox(height: 24),
        TextButton.icon(
          onPressed: () => ref.read(acessoProvider.notifier).sair(),
          icon: const Icon(Icons.logout),
          label: const Text('Sair desta conta'),
        ),
      ],
    );
  }
}

class TelaAguardando extends ConsumerStatefulWidget {
  const TelaAguardando({super.key, required this.empresaNome});
  final String empresaNome;

  @override
  ConsumerState<TelaAguardando> createState() => _TelaAguardandoState();
}

class _TelaAguardandoState extends ConsumerState<TelaAguardando> {
  bool _ocupado = false;

  Future<void> _verificar() async {
    setState(() => _ocupado = true);
    await ref.read(acessoProvider.notifier).recarregar();
    if (mounted) setState(() => _ocupado = false);
  }

  @override
  Widget build(BuildContext context) {
    return PaginaAcesso(
      titulo: 'Aguardando aprovação do seu patrão',
      texto: 'O pedido para entrar na ${widget.empresaNome.isEmpty ? 'empresa' : widget.empresaNome} foi enviado. '
          'Quando ele aprovar no painel, o app abre sozinho.',
      botao: 'Já fui aprovado, verificar',
      aoTocar: _verificar,
      ocupado: _ocupado,
      voltar: false,
      filhos: [
        const Icon(Icons.hourglass_top, size: 64),
        const SizedBox(height: 24),
        TextButton.icon(
          onPressed: () => ref.read(acessoProvider.notifier).sair(),
          icon: const Icon(Icons.logout),
          label: const Text('Sair desta conta'),
        ),
      ],
    );
  }
}

class TelaSemInternet extends ConsumerWidget {
  const TelaSemInternet({super.key, this.mensagem});
  final String? mensagem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PaginaAcesso(
      titulo: 'Precisa de internet agora',
      texto: 'Só na primeira vez o app precisa de internet, para buscar os seus dados. Depois funciona sem sinal.',
      botao: 'Tentar de novo',
      aoTocar: () => ref.read(acessoProvider.notifier).recarregar(),
      voltar: false,
      filhos: [
        const Icon(Icons.wifi_off, size: 64),
        if (mensagem != null) ...[const SizedBox(height: 16), Nota(mensagem!)],
      ],
    );
  }
}

class TelaContaGestor extends ConsumerWidget {
  const TelaContaGestor({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PaginaAcesso(
      titulo: 'Esta conta é de gestor',
      texto: 'Contas de dono ou gestor usam o painel da empresa (no computador ou no app do gestor). '
          'Para lançar como motorista, crie uma conta de motorista com outro e-mail.',
      botao: 'Sair desta conta',
      aoTocar: () => ref.read(acessoProvider.notifier).sair(),
      voltar: false,
      filhos: const [Icon(Icons.admin_panel_settings_outlined, size: 64)],
    );
  }
}
