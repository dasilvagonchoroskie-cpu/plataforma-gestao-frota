import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:visual/visual.dart';

import 'app.dart';
import 'config.dart';
import 'dados/aparelho.dart';
import 'dados/link_email.dart';
import 'dados/provedores.dart';
import 'servidor/servidor.dart';
import 'web/endereco.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Link do e-mail (criar senha nova ou confirmar e-mail): só no painel web.
  final link = kIsWeb ? LinkDoEmail.doEndereco(Uri.base) : null;
  if (link != null) limparLinkDoEndereco();
  final Aparelho aparelho;
  try {
    await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseChavePublica);
    aparelho = await AparelhoPreferencias.abrir();
  } catch (e) {
    runApp(AppFalhaAoAbrir(nomeApp: 'Frota Gestor', erro: '$e'));
    return;
  }
  runApp(
    ProviderScope(
      overrides: [
        servidorProvider.overrideWithValue(ServidorSupabase(Supabase.instance.client)),
        aparelhoProvider.overrideWithValue(aparelho),
        linkDoEmailProvider.overrideWith(() => LinkAberto(link)),
      ],
      child: const AplicativoGestor(),
    ),
  );
  avisarQueAbriu('gestor');
}
