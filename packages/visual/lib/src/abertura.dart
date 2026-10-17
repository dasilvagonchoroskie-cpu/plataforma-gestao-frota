import 'package:flutter/material.dart';

import 'tema.dart';

/// Tela de quando o app não consegue nem começar (erro do celular ao ligar a
/// conexão com a nuvem). Melhor que ficar parado no logo sem dizer nada.
class AppFalhaAoAbrir extends StatelessWidget {
  const AppFalhaAoAbrir({super.key, required this.nomeApp, required this.erro});

  final String nomeApp;
  final String erro;

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: temaClaro,
        darkTheme: temaEscuro,
        home: Scaffold(
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text('O $nomeApp não conseguiu abrir',
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                const Text(
                  'Feche o app e abra de novo. Se continuar assim, tire um print desta tela e mande para o suporte.',
                  style: TextStyle(fontSize: 17, height: 1.4),
                ),
                const SizedBox(height: 20),
                SelectableText(erro, style: const TextStyle(fontSize: 13, height: 1.3)),
              ],
            ),
          ),
        ),
      );
}

/// Escreve no registro do Android quando a primeira tela aparece. A esteira
/// abre o APK num emulador e confere esta linha.
void avisarQueAbriu(String app) =>
    WidgetsBinding.instance.addPostFrameCallback((_) => debugPrint('FROTA_ABRIU $app'));
