import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:visual/visual.dart';

import 'dados/link_email.dart';
import 'dados/provedores.dart';
import 'servidor/servidor.dart';
import 'telas/acesso/telas_acesso.dart';
import 'telas/casca.dart';
import 'telas/plataforma/tela_plataforma.dart';

class AplicativoGestor extends StatelessWidget {
  const AplicativoGestor({super.key, this.inicio});

  /// Tela inicial forçada (testes).
  final Widget? inicio;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Frota Gestor',
      debugShowCheckedModeBanner: false,
      theme: temaClaro,
      darkTheme: temaEscuro,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: mq.textScaler.clamp(minScaleFactor: 1.0, maxScaleFactor: 1.3)),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: inicio ?? const Raiz(),
    );
  }
}

/// Decide a primeira tela: entrar, completar o cadastro ou o painel.
class Raiz extends ConsumerWidget {
  const Raiz({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Link do e-mail (senha nova ou confirmar e-mail): resolve antes de tudo.
    final link = ref.watch(linkDoEmailProvider);
    if (link != null) return TelaLinkDoEmail(link: link);
    final acesso = ref.watch(acessoProvider);
    return acesso.when(
      loading: () => const Carregando(),
      error: (e, _) => TelaSemInternet(
        mensagem: traduzirErro(e).mensagem,
        tentarDeNovo: () => ref.read(acessoProvider.notifier).recarregar(),
      ),
      data: (a) {
        switch (a.etapa) {
          case Etapa.termosAbertura:
            return TelaAceiteTermos(
              naAbertura: true,
              aceitar: () => ref.read(acessoProvider.notifier).aceitarTermosNoAparelho(),
              sair: () => SystemNavigator.pop(),
            );
          case Etapa.entrar:
            return const TelaEntrar();
          case Etapa.completarCadastro:
            return TelaCompletarCadastro(email: a.email);
          case Etapa.contaMotorista:
            return TelaSemAcesso(motorista: true, email: a.email);
          case Etapa.naoAutorizado:
            return TelaSemAcesso(motorista: false, email: a.email);
          case Etapa.trocarSenha:
            return const TelaNovaSenha(primeiroAcesso: true);
          case Etapa.termos:
            return TelaAceiteTermos(
              aceitar: () => ref.read(acessoProvider.notifier).aceitarTermos(versaoTermos),
              sair: () => ref.read(acessoProvider.notifier).sair(),
            );
          case Etapa.bloqueada:
            return TelaAcessoEncerrado(estado: a);
          case Etapa.pronto:
            return const _ComDados();
          case Etapa.plataforma:
            return const TelaPlataforma(sozinha: true);
        }
      },
    );
  }
}

/// Carrega os dados da empresa antes de abrir o painel.
class _ComDados extends ConsumerWidget {
  const _ComDados();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final equipe = ref.watch(equipeProvider);
    if (equipe.hasValue) return const Casca();
    if (equipe.hasError) {
      return TelaSemInternet(
        mensagem: traduzirErro(equipe.error!).mensagem,
        tentarDeNovo: () => ref.invalidate(equipeProvider),
      );
    }
    return const Carregando(texto: 'Buscando os dados da empresa...');
  }
}

class Carregando extends StatelessWidget {
  const Carregando({super.key, this.texto});
  final String? texto;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (texto != null) ...[const SizedBox(height: 16), Text(texto!, style: const TextStyle(fontSize: 16))],
        ],
      ),
    ),
  );
}
