import 'package:flutter/material.dart';

void main() => runApp(const AplicativoGestor());

class AplicativoGestor extends StatelessWidget {
  const AplicativoGestor({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Plataforma de frota — gestor',
      theme: ThemeData(useMaterial3: true),
      home: const NavegacaoGestor(),
    );
  }
}

class NavegacaoGestor extends StatefulWidget {
  const NavegacaoGestor({super.key});

  @override
  State<NavegacaoGestor> createState() => _NavegacaoGestorState();
}

class _NavegacaoGestorState extends State<NavegacaoGestor> {
  int _indice = 0;

  static const _titulos = [
    'Painel',
    'Motoristas',
    'Caminhões',
    'Lançamentos',
    'Relatórios',
  ];
  static const _icones = [
    Icons.dashboard_outlined,
    Icons.people_outline,
    Icons.local_shipping_outlined,
    Icons.receipt_long_outlined,
    Icons.assessment_outlined,
  ];
  static const _telas = [
    _TelaDemonstrativa(
      titulo: 'Painel',
      descricao: 'Visão demonstrativa com números fixos, sem cálculos.',
      exemplos: ['Exemplo fixo: 2 motoristas', 'Exemplo fixo: 1 caminhão'],
    ),
    _TelaDemonstrativa(
      titulo: 'Motoristas',
      descricao: 'Tela reservada para a gestão de motoristas.',
      exemplos: ['Exemplo fixo: lista demonstrativa vazia'],
    ),
    _TelaDemonstrativa(
      titulo: 'Caminhões',
      descricao: 'Tela reservada para a gestão de caminhões.',
      exemplos: ['Exemplo fixo: lista demonstrativa vazia'],
    ),
    _TelaDemonstrativa(
      titulo: 'Lançamentos',
      descricao: 'Tela reservada para consultar os lançamentos.',
      exemplos: ['Exemplo fixo: nenhum registro real'],
    ),
    _TelaDemonstrativa(
      titulo: 'Relatórios',
      descricao: 'Tela reservada para relatórios futuros.',
      exemplos: ['PDF e CSV não implementados nesta etapa'],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final larguraAmpla = MediaQuery.sizeOf(context).width >= 700;
    final conteudo = _telas[_indice];

    if (larguraAmpla) {
      return Scaffold(
        appBar: AppBar(title: Text('Gestor — ${_titulos[_indice]}')),
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _indice,
              labelType: NavigationRailLabelType.all,
              onDestinationSelected: (indice) => setState(() => _indice = indice),
              destinations: [
                for (var i = 0; i < _titulos.length; i++)
                  NavigationRailDestination(
                    icon: Icon(_icones[i]),
                    label: Text(_titulos[i]),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: conteudo),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(_titulos[_indice])),
      body: conteudo,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indice,
        onDestinationSelected: (indice) => setState(() => _indice = indice),
        destinations: [
          for (var i = 0; i < _titulos.length; i++)
            NavigationDestination(
              icon: Icon(_icones[i]),
              label: _titulos[i],
            ),
        ],
      ),
    );
  }
}

class _TelaDemonstrativa extends StatelessWidget {
  const _TelaDemonstrativa({
    required this.titulo,
    required this.descricao,
    required this.exemplos,
  });

  final String titulo;
  final String descricao;
  final List<String> exemplos;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(titulo, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        Text(descricao),
        const SizedBox(height: 16),
        const Text('DADOS DE EXEMPLO — não são dados reais.'),
        for (final exemplo in exemplos)
          Card(child: ListTile(title: Text(exemplo))),
      ],
    );
  }
}
