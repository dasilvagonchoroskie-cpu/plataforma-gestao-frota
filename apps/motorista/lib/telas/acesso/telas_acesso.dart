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
              const Center(child: LinksLegais()),
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
      await s.entrarComCpf(soDigitos(_cpf.text), _senha.text, await idDoAparelho(ref.read(armazenamentoProvider)));
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
        const Nota('Esqueceu a senha? Toque em "Esqueci a senha" para receber o link no seu e-mail, ou peça ao '
            'seu patrão uma senha provisória pelo painel.'),
      ],
    );
  }
}

// ----------------------------------------------------------- criar conta

/// Cadastro numa tela só: nome, CPF, senha e o e-mail para recuperar a senha
/// sozinho. Os termos já foram aceitos na abertura do app.
class TelaCriarConta extends ConsumerStatefulWidget {
  const TelaCriarConta({super.key});

  @override
  ConsumerState<TelaCriarConta> createState() => _TelaCriarContaState();
}

class _TelaCriarContaState extends ConsumerState<TelaCriarConta> {
  final _nome = TextEditingController();
  final _cpf = TextEditingController();
  final _senha = TextEditingController();
  final _email = TextEditingController();
  String? _erro;
  String? _erroNome;
  String? _erroCpf;
  String? _erroSenha;
  String? _erroEmail;
  bool _ocupado = false;

  @override
  void dispose() {
    _nome.dispose();
    _cpf.dispose();
    _senha.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _criar() async {
    final email = _email.text.trim().toLowerCase();
    setState(() {
      _erro = null;
      _erroNome = _nome.text.trim().length < 2 ? 'Escreva o seu nome.' : null;
      _erroCpf = cpfValido(_cpf.text) ? null : 'Confira o CPF: tem 11 números.';
      _erroSenha = senhaAceita(_senha.text) ? null : ajudaSenha;
      _erroEmail = emailValido(email) ? null : 'Digite o seu e-mail. É com ele que você recupera a senha.';
    });
    if (_erroNome != null || _erroCpf != null || _erroSenha != null || _erroEmail != null) return;
    setState(() => _ocupado = true);
    try {
      final s = ref.read(servidorProvider);
      final aparelho = await idDoAparelho(ref.read(armazenamentoProvider));
      final cpf = soDigitos(_cpf.text);
      await s.cadastrarMotorista(_nome.text, cpf, _senha.text, aparelho, termos: versaoTermos);
      await s.entrarComCpf(cpf, _senha.text, aparelho);
      String recado;
      try {
        await s.cadastrarEmail(email);
        recado = 'Conta criada. Mandamos um link para $email: abra o e-mail e toque em "Confirmar e-mail".';
      } on ErroServidor catch (e) {
        // A conta já existe: a tela seguinte pede o e-mail de novo.
        recado = 'Conta criada, mas o e-mail não foi cadastrado: ${e.mensagem}';
      }
      await ref.read(acessoProvider.notifier).recarregar();
      if (!mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst);
      mostrarMensagem(context, recado);
    } on ErroServidor catch (e) {
      setState(() => _erro = e.mensagem);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PaginaAcesso(
      titulo: 'Criar conta',
      texto: 'O seu nome, o CPF, uma senha e o seu e-mail. Depois você digita o código da empresa que o seu '
          'patrão mandar.',
      botao: 'Criar minha conta',
      aoTocar: _criar,
      ocupado: _ocupado,
      filhos: [
        Campo(controle: _nome, rotulo: 'Seu nome', maiusculas: TextCapitalization.words, erro: _erroNome, autofoco: true),
        const SizedBox(height: 16),
        Campo(controle: _cpf, rotulo: 'CPF', tipo: TipoCampo.cpf, dica: '000.000.000-00', erro: _erroCpf),
        const SizedBox(height: 16),
        Campo(
          controle: _senha,
          rotulo: 'Crie uma senha',
          tipo: TipoCampo.senha,
          erro: _erroSenha,
          ajuda: '$ajudaSenha Você vai entrar com o CPF e esta senha.',
        ),
        const SizedBox(height: 16),
        Campo(
          controle: _email,
          rotulo: 'E-mail (para recuperar a senha)',
          tipo: TipoCampo.email,
          erro: _erroEmail,
          ajuda: 'Se esquecer a senha, o link para criar outra chega neste e-mail. Assim você não depende do '
              'patrão.',
          acaoTeclado: TextInputAction.done,
        ),
        MensagemErro(_erro),
        const SizedBox(height: 12),
        const Nota('Criando a conta, você segue os Termos de Uso e a Política de Privacidade que aceitou.'),
        const LinksLegais(),
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
      _erroSenha = senhaAceita(_senha.text) ? null : mensagemSenha;
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
          ajuda: '$ajudaSenha Você vai usar com o CPF para entrar.',
          erro: _erroSenha,
          acaoTeclado: TextInputAction.done,
        ),
        MensagemErro(_erro),
      ],
    );
  }
}

// ------------------------------------------------------------ esqueci a senha

/// Esqueci a senha: o link para criar a senha nova vai para o e-mail que o
/// motorista confirmou no app. Sem e-mail, o patrão cria uma senha provisória.
class TelaEsqueciSenha extends ConsumerWidget {
  const TelaEsqueciSenha({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TelaPedirLinkSenha(
      porCpf: true,
      pedir: (cpf) => ref.read(servidorProvider).pedirLinkSenha(cpf),
      semEmail: 'Não cadastrou e-mail no app? Peça ao seu patrão ou ao gestor uma senha provisória '
          '(no painel: Motoristas, o seu nome, Redefinir o acesso).',
      extras: [
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const TelaEntrar())),
          child: const Text('Já tenho a senha provisória'),
        ),
      ],
    );
  }
}

/// Conta sem e-mail (criada antes do e-mail ser obrigatório): cadastra antes
/// de continuar. Sem internet, dá para deixar para depois.
class TelaCadastrarEmail extends ConsumerStatefulWidget {
  const TelaCadastrarEmail({super.key});

  @override
  ConsumerState<TelaCadastrarEmail> createState() => _TelaCadastrarEmailState();
}

class _TelaCadastrarEmailState extends ConsumerState<TelaCadastrarEmail> {
  final _email = TextEditingController();
  String? _erro;
  bool _semInternet = false;
  bool _ocupado = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final email = _email.text.trim().toLowerCase();
    if (!emailValido(email)) {
      setState(() => _erro = 'Confira o e-mail.');
      return;
    }
    setState(() {
      _erro = null;
      _ocupado = true;
    });
    try {
      await ref.read(servidorProvider).cadastrarEmail(email);
      if (!mounted) return;
      mostrarMensagem(context, 'Mandamos um link para $email. Abra o e-mail e toque em "Confirmar e-mail".');
      await ref.read(acessoProvider.notifier).recarregar();
    } on ErroServidor catch (e) {
      if (mounted) {
        setState(() {
          _erro = e.mensagem;
          _semInternet = e.semInternet;
        });
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PaginaAcesso(
      titulo: 'Cadastre o seu e-mail',
      texto: 'Se um dia você esquecer a senha, o link para criar outra chega neste e-mail. Assim você não '
          'depende do patrão. Mandamos um link para confirmar.',
      botao: 'Mandar o link de confirmação',
      aoTocar: _enviar,
      ocupado: _ocupado,
      voltar: false,
      filhos: [
        Campo(
          controle: _email,
          rotulo: 'Seu e-mail',
          tipo: TipoCampo.email,
          autofoco: true,
          acaoTeclado: TextInputAction.done,
        ),
        MensagemErro(_erro),
        if (_semInternet) ...[
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => ref.read(acessoProvider.notifier).adiarEmail(),
            child: const Text('Fazer depois (sem internet agora)'),
          ),
        ],
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

/// Lembrete no Resumo enquanto o e-mail não é confirmado pelo link.
class AvisoConfirmarEmail extends ConsumerStatefulWidget {
  const AvisoConfirmarEmail({super.key});

  @override
  ConsumerState<AvisoConfirmarEmail> createState() => _AvisoConfirmarEmailState();
}

class _AvisoConfirmarEmailState extends ConsumerState<AvisoConfirmarEmail> {
  bool _ocupado = false;

  Future<void> _fazer(Future<void> Function() acao, String sucesso) async {
    setState(() => _ocupado = true);
    try {
      await acao();
      if (mounted) mostrarMensagem(context, sucesso);
    } on ErroServidor catch (e) {
      if (mounted) mostrarMensagem(context, e.mensagem);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.read(servidorProvider);
    final esperando = s.emailEsperando;
    if (s.emailConfirmado != null || esperando == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Aviso(
            icone: Icons.mark_email_unread_outlined,
            titulo: 'Confirme o seu e-mail',
            texto: 'Abra o e-mail que mandamos para $esperando e toque em "Confirmar e-mail". Sem isso, o link '
                'de senha esquecida não chega.',
          ),
          Wrap(
            alignment: WrapAlignment.end,
            children: [
              TextButton(
                onPressed: _ocupado
                    ? null
                    : () => _fazer(() => s.cadastrarEmail(esperando), 'Mandamos o link de novo para $esperando.'),
                child: const Text('Mandar de novo'),
              ),
              TextButton(
                onPressed: _ocupado
                    ? null
                    : () => _fazer(() async {
                          await s.atualizarConta();
                          if (s.emailConfirmado == null) {
                            throw const ErroServidor('Ainda não aparece confirmado. Toque no link do e-mail e tente de novo.');
                          }
                        }, 'E-mail confirmado.'),
                child: const Text('Já confirmei'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// E-mail para recuperar a senha: cadastrar ou trocar (vale depois de
/// confirmado pelo link que chega no e-mail).
class TelaEmailRecuperacao extends ConsumerStatefulWidget {
  const TelaEmailRecuperacao({super.key});

  @override
  ConsumerState<TelaEmailRecuperacao> createState() => _TelaEmailRecuperacaoState();
}

class _TelaEmailRecuperacaoState extends ConsumerState<TelaEmailRecuperacao> {
  final _email = TextEditingController();
  String? _erro;
  String? _enviado;
  bool _ocupado = false;

  @override
  void initState() {
    super.initState();
    // Confere na nuvem se o e-mail já foi confirmado pelo link.
    ref.read(servidorProvider).atualizarConta().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final email = _email.text.trim().toLowerCase();
    if (!emailValido(email)) {
      setState(() => _erro = 'Confira o e-mail.');
      return;
    }
    setState(() {
      _erro = null;
      _ocupado = true;
    });
    try {
      await ref.read(servidorProvider).cadastrarEmail(email);
      if (mounted) setState(() => _enviado = email);
    } on ErroServidor catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.read(servidorProvider);
    final confirmado = s.emailConfirmado;
    final esperando = _enviado ?? s.emailEsperando;
    return PaginaAcesso(
      titulo: 'E-mail para recuperar a senha',
      texto: 'Se esquecer a senha, o link para criar outra chega neste e-mail. Só você e a sua empresa veem.',
      botao: _enviado == null ? 'Mandar o link de confirmação' : null,
      aoTocar: _enviar,
      ocupado: _ocupado,
      filhos: [
        Aviso(
          icone: confirmado == null ? Icons.mail_outline : Icons.mark_email_read_outlined,
          texto: confirmado == null ? 'Nenhum e-mail confirmado ainda.' : 'E-mail confirmado: $confirmado',
        ),
        if (esperando != null) ...[
          const SizedBox(height: 12),
          Aviso(
            icone: Icons.hourglass_top,
            titulo: 'Falta confirmar',
            texto: 'Mandamos um link para $esperando. Abra o e-mail e toque em "Confirmar e-mail". '
                'Confira também a caixa de spam.',
          ),
        ],
        if (_enviado == null) ...[
          const SizedBox(height: 20),
          Campo(
            controle: _email,
            rotulo: confirmado == null ? 'Seu e-mail' : 'E-mail novo',
            tipo: TipoCampo.email,
            acaoTeclado: TextInputAction.done,
          ),
        ],
        MensagemErro(_erro),
      ],
    );
  }
}

/// Senha nova (depois da senha provisória do patrão ou nas configurações).
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
    if (!senhaAceita(_senha.text)) {
      setState(() => _erro = mensagemSenha);
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
      texto: 'Crie uma senha que só você saiba. $ajudaSenha',
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
      titulo: 'Código de entrada',
      texto: 'Digite o código que o seu patrão gerou para você no painel. Cada motorista tem o seu código, '
          'que vale por 7 dias e só funciona com o seu CPF.',
      botao: 'Entrar na empresa',
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
        const BotaoExcluirConta(),
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

// ------------------------------------------------- acesso encerrado e exclusão

/// A empresa deixou de usar a plataforma (fim do teste ou bloqueio).
class TelaAcessoEncerrado extends ConsumerWidget {
  const TelaAcessoEncerrado({super.key, required this.empresaNome, this.motivo});
  final String empresaNome;
  final String? motivo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PaginaAcesso(
      titulo: 'Acesso encerrado',
      texto: 'A ${empresaNome.isEmpty ? 'empresa' : empresaNome} não está mais usando a plataforma. '
          'Fale com o seu patrão.',
      botao: 'Verificar de novo',
      aoTocar: () => ref.read(acessoProvider.notifier).recarregar(conferir: true),
      voltar: false,
      filhos: [
        const Icon(Icons.lock_clock_outlined, size: 64),
        if (motivo != null && motivo!.isNotEmpty) ...[const SizedBox(height: 16), Nota('Motivo: $motivo')],
        const SizedBox(height: 24),
        TextButton.icon(
          onPressed: () => ref.read(acessoProvider.notifier).sair(),
          icon: const Icon(Icons.logout),
          label: const Text('Sair desta conta'),
        ),
        const BotaoExcluirConta(),
      ],
    );
  }
}

/// Excluir a própria conta (pede para digitar EXCLUIR).
Future<void> excluirMinhaConta(BuildContext context, WidgetRef ref) async {
  final ok = await confirmarDigitando(
    context,
    titulo: 'Excluir a sua conta?',
    texto: 'A sua conta (login, CPF e e-mail) é apagada na hora, e o CPF fica livre para uma conta nova. '
        'Se você está numa empresa, os seus lançamentos ficam com ela por até 15 dias, para guardar o que a lei '
        'obriga; depois são apagados. Não dá para desfazer.',
    palavra: 'EXCLUIR',
    botao: 'Excluir a conta',
  );
  if (!ok || !context.mounted) return;
  try {
    final recado = await ref.read(acessoProvider.notifier).excluirConta();
    if (context.mounted) {
      Navigator.of(context).popUntil((r) => r.isFirst);
      mostrarMensagem(context, recado);
    }
  } on ErroServidor catch (e) {
    if (context.mounted) mostrarMensagem(context, e.mensagem);
  }
}

class BotaoExcluirConta extends ConsumerWidget {
  const BotaoExcluirConta({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => TextButton.icon(
        onPressed: () => excluirMinhaConta(context, ref),
        style: TextButton.styleFrom(foregroundColor: context.cores.negativo),
        icon: const Icon(Icons.delete_forever_outlined),
        label: const Text('Excluir minha conta'),
      );
}
