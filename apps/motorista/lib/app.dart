import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:visual/visual.dart';

import 'acesso/acesso.dart';
import 'componentes/comuns.dart';
import 'dados/dados.dart';
import 'dados/aparencia.dart';
import 'telas/acesso/telas_acesso.dart';
import 'telas/caminhao/tela_caminhao.dart';
import 'telas/casca.dart';
import 'telas/inicio/tela_escolher_modalidade.dart';

class AplicativoMotorista extends ConsumerWidget {
  const AplicativoMotorista({super.key, this.inicio});

  /// Tela inicial forçada (testes).
  final Widget? inicio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Frota Motorista',
      debugShowCheckedModeBanner: false,
      theme: temaClaro,
      darkTheme: temaEscuro,
      // Escuro como o cartaz; claro ou igual ao aparelho em Configurações.
      themeMode: ref.watch(aparenciaProvider).modo,
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

/// Decide a primeira tela: acesso (cadastro, código, aprovação) ou as abas.
class Raiz extends ConsumerWidget {
  const Raiz({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final acesso = ref.watch(acessoProvider);
    final dados = ref.watch(dadosProvider);
    return acesso.when(
      loading: () => const _Carregando(),
      error: (e, _) => TelaSemInternet(mensagem: '$e'),
      data: (a) {
        switch (a.etapa) {
          case Etapa.termosAbertura:
            return TelaAceiteTermos(
              naAbertura: true,
              aceitar: () => ref.read(acessoProvider.notifier).aceitarTermosNoAparelho(),
              sair: () => SystemNavigator.pop(),
            );
          case Etapa.boasVindas:
            return const TelaBoasVindas();
          case Etapa.completarCadastro:
            return TelaCompletarCadastro(email: a.email, voltar: false);
          case Etapa.codigoEmpresa:
            return TelaCodigoEmpresa(mensagem: a.mensagem);
          case Etapa.aguardando:
            return TelaAguardando(empresaNome: a.empresaNome);
          case Etapa.contaDeGestor:
            return const TelaContaGestor();
          case Etapa.trocarSenha:
            return const TelaTrocarSenha(voltar: false);
          case Etapa.termos:
            return TelaAceiteTermos(
              aceitar: () => ref.read(acessoProvider.notifier).aceitarTermos(versaoTermos),
              sair: () => ref.read(acessoProvider.notifier).sair(),
            );
          case Etapa.cadastrarEmail:
            return const TelaCadastrarEmail();
          case Etapa.bloqueada:
            return TelaAcessoEncerrado(empresaNome: a.empresaNome, motivo: a.mensagem);
          case Etapa.semInternet:
            return TelaSemInternet(mensagem: a.mensagem);
          case Etapa.pronto:
            if (!dados.hasValue) return const _Carregando();
            final d = assistirDados(ref);
            if (d.info.precisaEscolherModalidade) return const TelaEscolherModalidade();
            if (d.caminhaoAtual == null && d.usos.isEmpty) return const _PrimeiroCaminhao();
            return const Casca();
        }
      },
    );
  }
}

class _Carregando extends StatelessWidget {
  const _Carregando();

  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: CircularProgressIndicator()));
}

/// Primeira vez depois da aprovação: escolher o caminhão.
class _PrimeiroCaminhao extends StatelessWidget {
  const _PrimeiroCaminhao();

  @override
  Widget build(BuildContext context) => const TelaTrocarCaminhao(primeiraVez: true);
}
