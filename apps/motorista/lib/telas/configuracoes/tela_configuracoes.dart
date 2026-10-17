import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleo/nucleo.dart';
import 'package:visual/visual.dart';

import '../../acesso/acesso.dart';
import '../../componentes/comuns.dart';
import '../../config.dart';
import '../../dados/sincronizador.dart';
import '../../dados/dados.dart';
import '../acesso/telas_acesso.dart';
import '../caminhao/tela_caminhao.dart';

class TelaConfiguracoes extends ConsumerWidget {
  const TelaConfiguracoes({super.key});

  Future<void> _sair(BuildContext context, WidgetRef ref) async {
    final d = assistirDados(ref);
    final pendentes = d.quantidadePendente;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sair da conta?'),
        content: Text(
          pendentes > 0
              ? 'ATENÇÃO: ${plural(pendentes, 'lançamento ainda não foi enviado', 'lançamentos ainda não foram enviados')} '
                  'e vai se perder. Envie antes com internet. Quer sair mesmo assim?'
              : 'Os seus dados estão guardados na nuvem. Para voltar, é só entrar com o CPF e a senha.',
          style: const TextStyle(fontSize: 16.5, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: ctx.cores.negativo),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
    await ref.read(acessoProvider.notifier).sair();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = assistirDados(ref);
    final envio = ref.watch(sincronizadorProvider);
    final cores = context.cores;
    final c = d.caminhaoAtual;
    final config = d.info.configuracao;
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(d.info.nome.isEmpty ? 'Motorista' : d.info.nome, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            subtitle: Text(d.info.empresaNome.isEmpty ? 'Empresa' : d.info.empresaNome),
          ),
          const Divider(),
          ListTile(
            leading: c == null ? const Icon(Icons.local_shipping_outlined) : PlacaVeiculo(c.placa, tamanho: 14),
            title: const Text('Trocar de caminhão', style: TextStyle(fontSize: 17)),
            subtitle: Text(c == null ? 'Nenhum escolhido' : 'Agora: ${placaTexto(c.placa)}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TelaTrocarCaminhao())),
          ),
          ListTile(
            leading: const Icon(Icons.sync),
            title: const Text('Sincronizar agora', style: TextStyle(fontSize: 17)),
            subtitle: Text(envio.ocupado
                ? 'Enviando...'
                : (d.quantidadePendente == 0
                    ? 'Tudo enviado'
                    : plural(d.quantidadePendente, 'item aguardando internet', 'itens aguardando internet'))),
            onTap: envio.ocupado ? null : () => ref.read(sincronizadorProvider.notifier).sincronizar(),
          ),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Trocar a senha', style: TextStyle(fontSize: 17)),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TelaTrocarSenha())),
          ),
          ListTile(
            leading: const Icon(Icons.key_outlined),
            title: const Text('Código de recuperação', style: TextStyle(fontSize: 17)),
            subtitle: const Text('Gerar um código novo (o anterior para de valer)'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (ctx) => TelaCodigoRecuperacao(
                  voltar: true,
                  gerar: () => ref.read(servidorProvider).gerarCodigoRecuperacao(),
                  concluir: () => Navigator.pop(ctx),
                ),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Termos de Uso', style: TextStyle(fontSize: 17)),
            onTap: () => Navigator.push(context, TelaTextoLegal.rota('Termos de Uso', termosDeUso)),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Política de Privacidade', style: TextStyle(fontSize: 17)),
            onTap: () => Navigator.push(context, TelaTextoLegal.rota('Política de Privacidade', politicaDePrivacidade)),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Text('Como a empresa acerta com você', style: context.textos.titleMedium),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LinhaValor(rotulo: 'Comissão padrão', valor: '${percentualTexto(config.percentualComissaoPadrao)}%'),
                LinhaValor(
                  rotulo: 'Diesel e gastos',
                  valor: config.gastosDescontamDoLiquido ? 'por sua conta' : 'a empresa paga',
                ),
                LinhaValor(rotulo: 'Vale', valor: config.valeDescontaDoLiquido ? 'desconta' : 'não desconta'),
                const Nota('Quem muda essas regras é o dono da empresa, no painel.'),
              ],
            ),
          ),
          const Divider(height: 32),
          ListTile(
            leading: Icon(Icons.logout, color: cores.negativo),
            title: Text('Sair da conta', style: TextStyle(fontSize: 17, color: cores.negativo)),
            onTap: () => _sair(context, ref),
          ),
          ListTile(
            leading: Icon(Icons.delete_forever_outlined, color: cores.negativo),
            title: Text('Excluir minha conta', style: TextStyle(fontSize: 17, color: cores.negativo)),
            subtitle: const Text('Apaga a sua conta e os seus dados'),
            onTap: () => excluirMinhaConta(context, ref),
          ),
          const SizedBox(height: 12),
          Center(child: Text('Versão $versaoApp', style: TextStyle(color: cores.textoFraco))),
        ],
      ),
    );
  }
}
