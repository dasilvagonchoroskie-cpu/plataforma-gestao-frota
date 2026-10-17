import '../modelos.dart';

/// Aplica os ajustes do gestor num registro (mapa com os nomes das colunas):
/// cada campo fica com o último valor corrigido, e 'campos_ajustados' lista
/// o que mudou. É a mesma conta das views *_efetivos do banco, para o app do
/// motorista mostrar igual ao painel sem precisar de internet.
Map<String, Object?> aplicarAjustes(Map<String, Object?> registro, Iterable<AjusteGestor> ajustes) {
  final id = registro['id']?.toString();
  final doRegistro = ajustes.where((a) => a.registroId == id && !a.apagado).toList()
    ..sort((a, b) {
      final c = a.criadoEm.compareTo(b.criadoEm);
      return c != 0 ? c : a.id.compareTo(b.id);
    });
  if (doRegistro.isEmpty) return registro;
  final r = Map<String, Object?>.from(registro);
  final campos = <String>{};
  for (final a in doRegistro) {
    r[a.campo] = a.valorNovo;
    campos.add(a.campo);
  }
  r['campos_ajustados'] = campos.toList()..sort();
  return r;
}

/// Nome que aparece na tela para cada campo que o gestor pode corrigir.
const nomesDosCampos = <String, String>{
  'origem': 'origem',
  'destino': 'destino',
  'embarcador': 'embarcador',
  'data_carga': 'data da carga',
  'peso_carga_kg': 'peso da carga',
  'peso_descarga_kg': 'peso da descarga',
  'valor_tonelada_centavos': 'valor da tonelada',
  'adiantamento_centavos': 'adiantamento',
  'saldo_centavos': 'saldo',
  'pedagio_centavos': 'pedágio',
  'desconto_quebra_centavos': 'desconto da quebra',
  'percentual_comissao': 'comissão',
  'comissao_sobre_bruto': 'base da comissão',
  'caminhao_id': 'caminhão',
  'data': 'data',
  'cidade': 'cidade',
  'posto': 'posto',
  'litros': 'litros',
  'km_odometro': 'km',
  'valor_centavos': 'valor',
  'tanque_cheio': 'tanque cheio',
  'categoria_id': 'categoria',
  'observacao': 'observação',
};

String nomeDoCampo(String campo) => nomesDosCampos[campo] ?? campo;

/// "saldo e pedágio corrigidos pelo gestor"
String textoCamposAjustados(List<String> campos) {
  if (campos.isEmpty) return '';
  final nomes = campos.map(nomeDoCampo).toList();
  final lista = nomes.length == 1
      ? nomes.first
      : '${nomes.sublist(0, nomes.length - 1).join(', ')} e ${nomes.last}';
  return '$lista ${nomes.length == 1 ? 'corrigido' : 'corrigidos'} pelo gestor';
}
