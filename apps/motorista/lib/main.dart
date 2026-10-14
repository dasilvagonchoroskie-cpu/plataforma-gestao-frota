import 'package:flutter/material.dart';

void main() => runApp(const AplicativoMotorista());

class AplicativoMotorista extends StatelessWidget {
  const AplicativoMotorista({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Plataforma de frota — motorista',
      theme: ThemeData(useMaterial3: true),
      home: const NavegacaoMotorista(),
    );
  }
}

class NavegacaoMotorista extends StatefulWidget {
  const NavegacaoMotorista({super.key});

  @override
  State<NavegacaoMotorista> createState() => _NavegacaoMotoristaState();
}

class _NavegacaoMotoristaState extends State<NavegacaoMotorista> {
  int _indice = 0;

  static const _titulos = ['Início', 'Lançamentos', 'Resumo', 'Configurações'];
  static const _icones = [
    Icons.home_outlined,
    Icons.add_box_outlined,
    Icons.summarize_outlined,
    Icons.settings_outlined,
  ];
  static const _telas = [
    _TelaDemonstrativa(
      titulo: 'Início',
      descricao: 'Resumo demonstrativo com valores fixos.',
      exemplos: ['Exemplo fixo: 2 fretes no período'],
    ),
    _TelaDemonstrativa(
      titulo: 'Lançamentos',
      descricao: 'Áreas previstas para os lançamentos do motorista.',
      exemplos: ['Fretes', 'Diesel', 'Gastos de viagem', 'Vales'],
    ),
    _TelaDemonstrativa(
      titulo: 'Resumo',
      descricao: 'Tela vazia de demonstração; nenhum cálculo foi implementado.',
      exemplos: ['Exemplo fixo: relatório ainda indisponível'],
    ),
    _TelaDemonstrativa(
      titulo: 'Configurações',
      descricao: 'Área reservada para as opções previstas na arquitetura.',
      exemplos: ['Troca de caminhão e sincronização ficam para fases futuras'],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titulos[_indice])),
      body: _telas[_indice],
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
