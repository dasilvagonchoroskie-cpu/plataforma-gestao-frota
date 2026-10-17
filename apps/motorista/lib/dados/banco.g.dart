// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'banco.dart';

// ignore_for_file: type=lint
class $RegistrosTable extends Registros
    with TableInfo<$RegistrosTable, Registro> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RegistrosTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _tabelaMeta = const VerificationMeta('tabela');
  @override
  late final GeneratedColumn<String> tabela = GeneratedColumn<String>(
    'tabela',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dadosMeta = const VerificationMeta('dados');
  @override
  late final GeneratedColumn<String> dados = GeneratedColumn<String>(
    'dados',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [tabela, id, dados];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'registros';
  @override
  VerificationContext validateIntegrity(
    Insertable<Registro> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('tabela')) {
      context.handle(
        _tabelaMeta,
        tabela.isAcceptableOrUnknown(data['tabela']!, _tabelaMeta),
      );
    } else if (isInserting) {
      context.missing(_tabelaMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('dados')) {
      context.handle(
        _dadosMeta,
        dados.isAcceptableOrUnknown(data['dados']!, _dadosMeta),
      );
    } else if (isInserting) {
      context.missing(_dadosMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {tabela, id};
  @override
  Registro map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Registro(
      tabela: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tabela'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      dados: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dados'],
      )!,
    );
  }

  @override
  $RegistrosTable createAlias(String alias) {
    return $RegistrosTable(attachedDatabase, alias);
  }
}

class Registro extends DataClass implements Insertable<Registro> {
  final String tabela;
  final String id;
  final String dados;
  const Registro({required this.tabela, required this.id, required this.dados});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['tabela'] = Variable<String>(tabela);
    map['id'] = Variable<String>(id);
    map['dados'] = Variable<String>(dados);
    return map;
  }

  RegistrosCompanion toCompanion(bool nullToAbsent) {
    return RegistrosCompanion(
      tabela: Value(tabela),
      id: Value(id),
      dados: Value(dados),
    );
  }

  factory Registro.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Registro(
      tabela: serializer.fromJson<String>(json['tabela']),
      id: serializer.fromJson<String>(json['id']),
      dados: serializer.fromJson<String>(json['dados']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'tabela': serializer.toJson<String>(tabela),
      'id': serializer.toJson<String>(id),
      'dados': serializer.toJson<String>(dados),
    };
  }

  Registro copyWith({String? tabela, String? id, String? dados}) => Registro(
    tabela: tabela ?? this.tabela,
    id: id ?? this.id,
    dados: dados ?? this.dados,
  );
  Registro copyWithCompanion(RegistrosCompanion data) {
    return Registro(
      tabela: data.tabela.present ? data.tabela.value : this.tabela,
      id: data.id.present ? data.id.value : this.id,
      dados: data.dados.present ? data.dados.value : this.dados,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Registro(')
          ..write('tabela: $tabela, ')
          ..write('id: $id, ')
          ..write('dados: $dados')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(tabela, id, dados);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Registro &&
          other.tabela == this.tabela &&
          other.id == this.id &&
          other.dados == this.dados);
}

class RegistrosCompanion extends UpdateCompanion<Registro> {
  final Value<String> tabela;
  final Value<String> id;
  final Value<String> dados;
  final Value<int> rowid;
  const RegistrosCompanion({
    this.tabela = const Value.absent(),
    this.id = const Value.absent(),
    this.dados = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RegistrosCompanion.insert({
    required String tabela,
    required String id,
    required String dados,
    this.rowid = const Value.absent(),
  }) : tabela = Value(tabela),
       id = Value(id),
       dados = Value(dados);
  static Insertable<Registro> custom({
    Expression<String>? tabela,
    Expression<String>? id,
    Expression<String>? dados,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (tabela != null) 'tabela': tabela,
      if (id != null) 'id': id,
      if (dados != null) 'dados': dados,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RegistrosCompanion copyWith({
    Value<String>? tabela,
    Value<String>? id,
    Value<String>? dados,
    Value<int>? rowid,
  }) {
    return RegistrosCompanion(
      tabela: tabela ?? this.tabela,
      id: id ?? this.id,
      dados: dados ?? this.dados,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (tabela.present) {
      map['tabela'] = Variable<String>(tabela.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (dados.present) {
      map['dados'] = Variable<String>(dados.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RegistrosCompanion(')
          ..write('tabela: $tabela, ')
          ..write('id: $id, ')
          ..write('dados: $dados, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FilaEnvioTable extends FilaEnvio
    with TableInfo<$FilaEnvioTable, FilaEnvioData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FilaEnvioTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _tabelaMeta = const VerificationMeta('tabela');
  @override
  late final GeneratedColumn<String> tabela = GeneratedColumn<String>(
    'tabela',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _registroIdMeta = const VerificationMeta(
    'registroId',
  );
  @override
  late final GeneratedColumn<String> registroId = GeneratedColumn<String>(
    'registro_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dadosMeta = const VerificationMeta('dados');
  @override
  late final GeneratedColumn<String> dados = GeneratedColumn<String>(
    'dados',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versaoMeta = const VerificationMeta('versao');
  @override
  late final GeneratedColumn<int> versao = GeneratedColumn<int>(
    'versao',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _situacaoMeta = const VerificationMeta(
    'situacao',
  );
  @override
  late final GeneratedColumn<String> situacao = GeneratedColumn<String>(
    'situacao',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pendente'),
  );
  static const VerificationMeta _mensagemMeta = const VerificationMeta(
    'mensagem',
  );
  @override
  late final GeneratedColumn<String> mensagem = GeneratedColumn<String>(
    'mensagem',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _criadoEmMeta = const VerificationMeta(
    'criadoEm',
  );
  @override
  late final GeneratedColumn<DateTime> criadoEm = GeneratedColumn<DateTime>(
    'criado_em',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    seq,
    tabela,
    registroId,
    dados,
    versao,
    situacao,
    mensagem,
    criadoEm,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'fila_envio';
  @override
  VerificationContext validateIntegrity(
    Insertable<FilaEnvioData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('seq')) {
      context.handle(
        _seqMeta,
        seq.isAcceptableOrUnknown(data['seq']!, _seqMeta),
      );
    }
    if (data.containsKey('tabela')) {
      context.handle(
        _tabelaMeta,
        tabela.isAcceptableOrUnknown(data['tabela']!, _tabelaMeta),
      );
    } else if (isInserting) {
      context.missing(_tabelaMeta);
    }
    if (data.containsKey('registro_id')) {
      context.handle(
        _registroIdMeta,
        registroId.isAcceptableOrUnknown(data['registro_id']!, _registroIdMeta),
      );
    } else if (isInserting) {
      context.missing(_registroIdMeta);
    }
    if (data.containsKey('dados')) {
      context.handle(
        _dadosMeta,
        dados.isAcceptableOrUnknown(data['dados']!, _dadosMeta),
      );
    } else if (isInserting) {
      context.missing(_dadosMeta);
    }
    if (data.containsKey('versao')) {
      context.handle(
        _versaoMeta,
        versao.isAcceptableOrUnknown(data['versao']!, _versaoMeta),
      );
    }
    if (data.containsKey('situacao')) {
      context.handle(
        _situacaoMeta,
        situacao.isAcceptableOrUnknown(data['situacao']!, _situacaoMeta),
      );
    }
    if (data.containsKey('mensagem')) {
      context.handle(
        _mensagemMeta,
        mensagem.isAcceptableOrUnknown(data['mensagem']!, _mensagemMeta),
      );
    }
    if (data.containsKey('criado_em')) {
      context.handle(
        _criadoEmMeta,
        criadoEm.isAcceptableOrUnknown(data['criado_em']!, _criadoEmMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {seq};
  @override
  FilaEnvioData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FilaEnvioData(
      seq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seq'],
      )!,
      tabela: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tabela'],
      )!,
      registroId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}registro_id'],
      )!,
      dados: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dados'],
      )!,
      versao: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}versao'],
      )!,
      situacao: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}situacao'],
      )!,
      mensagem: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mensagem'],
      ),
      criadoEm: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}criado_em'],
      )!,
    );
  }

  @override
  $FilaEnvioTable createAlias(String alias) {
    return $FilaEnvioTable(attachedDatabase, alias);
  }
}

class FilaEnvioData extends DataClass implements Insertable<FilaEnvioData> {
  final int seq;
  final String tabela;
  final String registroId;
  final String dados;
  final int versao;
  final String situacao;
  final String? mensagem;
  final DateTime criadoEm;
  const FilaEnvioData({
    required this.seq,
    required this.tabela,
    required this.registroId,
    required this.dados,
    required this.versao,
    required this.situacao,
    this.mensagem,
    required this.criadoEm,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['seq'] = Variable<int>(seq);
    map['tabela'] = Variable<String>(tabela);
    map['registro_id'] = Variable<String>(registroId);
    map['dados'] = Variable<String>(dados);
    map['versao'] = Variable<int>(versao);
    map['situacao'] = Variable<String>(situacao);
    if (!nullToAbsent || mensagem != null) {
      map['mensagem'] = Variable<String>(mensagem);
    }
    map['criado_em'] = Variable<DateTime>(criadoEm);
    return map;
  }

  FilaEnvioCompanion toCompanion(bool nullToAbsent) {
    return FilaEnvioCompanion(
      seq: Value(seq),
      tabela: Value(tabela),
      registroId: Value(registroId),
      dados: Value(dados),
      versao: Value(versao),
      situacao: Value(situacao),
      mensagem: mensagem == null && nullToAbsent
          ? const Value.absent()
          : Value(mensagem),
      criadoEm: Value(criadoEm),
    );
  }

  factory FilaEnvioData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FilaEnvioData(
      seq: serializer.fromJson<int>(json['seq']),
      tabela: serializer.fromJson<String>(json['tabela']),
      registroId: serializer.fromJson<String>(json['registroId']),
      dados: serializer.fromJson<String>(json['dados']),
      versao: serializer.fromJson<int>(json['versao']),
      situacao: serializer.fromJson<String>(json['situacao']),
      mensagem: serializer.fromJson<String?>(json['mensagem']),
      criadoEm: serializer.fromJson<DateTime>(json['criadoEm']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'seq': serializer.toJson<int>(seq),
      'tabela': serializer.toJson<String>(tabela),
      'registroId': serializer.toJson<String>(registroId),
      'dados': serializer.toJson<String>(dados),
      'versao': serializer.toJson<int>(versao),
      'situacao': serializer.toJson<String>(situacao),
      'mensagem': serializer.toJson<String?>(mensagem),
      'criadoEm': serializer.toJson<DateTime>(criadoEm),
    };
  }

  FilaEnvioData copyWith({
    int? seq,
    String? tabela,
    String? registroId,
    String? dados,
    int? versao,
    String? situacao,
    Value<String?> mensagem = const Value.absent(),
    DateTime? criadoEm,
  }) => FilaEnvioData(
    seq: seq ?? this.seq,
    tabela: tabela ?? this.tabela,
    registroId: registroId ?? this.registroId,
    dados: dados ?? this.dados,
    versao: versao ?? this.versao,
    situacao: situacao ?? this.situacao,
    mensagem: mensagem.present ? mensagem.value : this.mensagem,
    criadoEm: criadoEm ?? this.criadoEm,
  );
  FilaEnvioData copyWithCompanion(FilaEnvioCompanion data) {
    return FilaEnvioData(
      seq: data.seq.present ? data.seq.value : this.seq,
      tabela: data.tabela.present ? data.tabela.value : this.tabela,
      registroId: data.registroId.present
          ? data.registroId.value
          : this.registroId,
      dados: data.dados.present ? data.dados.value : this.dados,
      versao: data.versao.present ? data.versao.value : this.versao,
      situacao: data.situacao.present ? data.situacao.value : this.situacao,
      mensagem: data.mensagem.present ? data.mensagem.value : this.mensagem,
      criadoEm: data.criadoEm.present ? data.criadoEm.value : this.criadoEm,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FilaEnvioData(')
          ..write('seq: $seq, ')
          ..write('tabela: $tabela, ')
          ..write('registroId: $registroId, ')
          ..write('dados: $dados, ')
          ..write('versao: $versao, ')
          ..write('situacao: $situacao, ')
          ..write('mensagem: $mensagem, ')
          ..write('criadoEm: $criadoEm')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    seq,
    tabela,
    registroId,
    dados,
    versao,
    situacao,
    mensagem,
    criadoEm,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FilaEnvioData &&
          other.seq == this.seq &&
          other.tabela == this.tabela &&
          other.registroId == this.registroId &&
          other.dados == this.dados &&
          other.versao == this.versao &&
          other.situacao == this.situacao &&
          other.mensagem == this.mensagem &&
          other.criadoEm == this.criadoEm);
}

class FilaEnvioCompanion extends UpdateCompanion<FilaEnvioData> {
  final Value<int> seq;
  final Value<String> tabela;
  final Value<String> registroId;
  final Value<String> dados;
  final Value<int> versao;
  final Value<String> situacao;
  final Value<String?> mensagem;
  final Value<DateTime> criadoEm;
  const FilaEnvioCompanion({
    this.seq = const Value.absent(),
    this.tabela = const Value.absent(),
    this.registroId = const Value.absent(),
    this.dados = const Value.absent(),
    this.versao = const Value.absent(),
    this.situacao = const Value.absent(),
    this.mensagem = const Value.absent(),
    this.criadoEm = const Value.absent(),
  });
  FilaEnvioCompanion.insert({
    this.seq = const Value.absent(),
    required String tabela,
    required String registroId,
    required String dados,
    this.versao = const Value.absent(),
    this.situacao = const Value.absent(),
    this.mensagem = const Value.absent(),
    this.criadoEm = const Value.absent(),
  }) : tabela = Value(tabela),
       registroId = Value(registroId),
       dados = Value(dados);
  static Insertable<FilaEnvioData> custom({
    Expression<int>? seq,
    Expression<String>? tabela,
    Expression<String>? registroId,
    Expression<String>? dados,
    Expression<int>? versao,
    Expression<String>? situacao,
    Expression<String>? mensagem,
    Expression<DateTime>? criadoEm,
  }) {
    return RawValuesInsertable({
      if (seq != null) 'seq': seq,
      if (tabela != null) 'tabela': tabela,
      if (registroId != null) 'registro_id': registroId,
      if (dados != null) 'dados': dados,
      if (versao != null) 'versao': versao,
      if (situacao != null) 'situacao': situacao,
      if (mensagem != null) 'mensagem': mensagem,
      if (criadoEm != null) 'criado_em': criadoEm,
    });
  }

  FilaEnvioCompanion copyWith({
    Value<int>? seq,
    Value<String>? tabela,
    Value<String>? registroId,
    Value<String>? dados,
    Value<int>? versao,
    Value<String>? situacao,
    Value<String?>? mensagem,
    Value<DateTime>? criadoEm,
  }) {
    return FilaEnvioCompanion(
      seq: seq ?? this.seq,
      tabela: tabela ?? this.tabela,
      registroId: registroId ?? this.registroId,
      dados: dados ?? this.dados,
      versao: versao ?? this.versao,
      situacao: situacao ?? this.situacao,
      mensagem: mensagem ?? this.mensagem,
      criadoEm: criadoEm ?? this.criadoEm,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (tabela.present) {
      map['tabela'] = Variable<String>(tabela.value);
    }
    if (registroId.present) {
      map['registro_id'] = Variable<String>(registroId.value);
    }
    if (dados.present) {
      map['dados'] = Variable<String>(dados.value);
    }
    if (versao.present) {
      map['versao'] = Variable<int>(versao.value);
    }
    if (situacao.present) {
      map['situacao'] = Variable<String>(situacao.value);
    }
    if (mensagem.present) {
      map['mensagem'] = Variable<String>(mensagem.value);
    }
    if (criadoEm.present) {
      map['criado_em'] = Variable<DateTime>(criadoEm.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FilaEnvioCompanion(')
          ..write('seq: $seq, ')
          ..write('tabela: $tabela, ')
          ..write('registroId: $registroId, ')
          ..write('dados: $dados, ')
          ..write('versao: $versao, ')
          ..write('situacao: $situacao, ')
          ..write('mensagem: $mensagem, ')
          ..write('criadoEm: $criadoEm')
          ..write(')'))
        .toString();
  }
}

class $EstadoTable extends Estado with TableInfo<$EstadoTable, EstadoData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EstadoTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _chaveMeta = const VerificationMeta('chave');
  @override
  late final GeneratedColumn<String> chave = GeneratedColumn<String>(
    'chave',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valorMeta = const VerificationMeta('valor');
  @override
  late final GeneratedColumn<String> valor = GeneratedColumn<String>(
    'valor',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [chave, valor];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'estado';
  @override
  VerificationContext validateIntegrity(
    Insertable<EstadoData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('chave')) {
      context.handle(
        _chaveMeta,
        chave.isAcceptableOrUnknown(data['chave']!, _chaveMeta),
      );
    } else if (isInserting) {
      context.missing(_chaveMeta);
    }
    if (data.containsKey('valor')) {
      context.handle(
        _valorMeta,
        valor.isAcceptableOrUnknown(data['valor']!, _valorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {chave};
  @override
  EstadoData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EstadoData(
      chave: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chave'],
      )!,
      valor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}valor'],
      ),
    );
  }

  @override
  $EstadoTable createAlias(String alias) {
    return $EstadoTable(attachedDatabase, alias);
  }
}

class EstadoData extends DataClass implements Insertable<EstadoData> {
  final String chave;
  final String? valor;
  const EstadoData({required this.chave, this.valor});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['chave'] = Variable<String>(chave);
    if (!nullToAbsent || valor != null) {
      map['valor'] = Variable<String>(valor);
    }
    return map;
  }

  EstadoCompanion toCompanion(bool nullToAbsent) {
    return EstadoCompanion(
      chave: Value(chave),
      valor: valor == null && nullToAbsent
          ? const Value.absent()
          : Value(valor),
    );
  }

  factory EstadoData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EstadoData(
      chave: serializer.fromJson<String>(json['chave']),
      valor: serializer.fromJson<String?>(json['valor']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'chave': serializer.toJson<String>(chave),
      'valor': serializer.toJson<String?>(valor),
    };
  }

  EstadoData copyWith({
    String? chave,
    Value<String?> valor = const Value.absent(),
  }) => EstadoData(
    chave: chave ?? this.chave,
    valor: valor.present ? valor.value : this.valor,
  );
  EstadoData copyWithCompanion(EstadoCompanion data) {
    return EstadoData(
      chave: data.chave.present ? data.chave.value : this.chave,
      valor: data.valor.present ? data.valor.value : this.valor,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EstadoData(')
          ..write('chave: $chave, ')
          ..write('valor: $valor')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(chave, valor);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EstadoData &&
          other.chave == this.chave &&
          other.valor == this.valor);
}

class EstadoCompanion extends UpdateCompanion<EstadoData> {
  final Value<String> chave;
  final Value<String?> valor;
  final Value<int> rowid;
  const EstadoCompanion({
    this.chave = const Value.absent(),
    this.valor = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EstadoCompanion.insert({
    required String chave,
    this.valor = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : chave = Value(chave);
  static Insertable<EstadoData> custom({
    Expression<String>? chave,
    Expression<String>? valor,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (chave != null) 'chave': chave,
      if (valor != null) 'valor': valor,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EstadoCompanion copyWith({
    Value<String>? chave,
    Value<String?>? valor,
    Value<int>? rowid,
  }) {
    return EstadoCompanion(
      chave: chave ?? this.chave,
      valor: valor ?? this.valor,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (chave.present) {
      map['chave'] = Variable<String>(chave.value);
    }
    if (valor.present) {
      map['valor'] = Variable<String>(valor.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EstadoCompanion(')
          ..write('chave: $chave, ')
          ..write('valor: $valor, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$BancoLocal extends GeneratedDatabase {
  _$BancoLocal(QueryExecutor e) : super(e);
  $BancoLocalManager get managers => $BancoLocalManager(this);
  late final $RegistrosTable registros = $RegistrosTable(this);
  late final $FilaEnvioTable filaEnvio = $FilaEnvioTable(this);
  late final $EstadoTable estado = $EstadoTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    registros,
    filaEnvio,
    estado,
  ];
}

typedef $$RegistrosTableCreateCompanionBuilder =
    RegistrosCompanion Function({
      required String tabela,
      required String id,
      required String dados,
      Value<int> rowid,
    });
typedef $$RegistrosTableUpdateCompanionBuilder =
    RegistrosCompanion Function({
      Value<String> tabela,
      Value<String> id,
      Value<String> dados,
      Value<int> rowid,
    });

class $$RegistrosTableFilterComposer
    extends Composer<_$BancoLocal, $RegistrosTable> {
  $$RegistrosTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get tabela => $composableBuilder(
    column: $table.tabela,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dados => $composableBuilder(
    column: $table.dados,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RegistrosTableOrderingComposer
    extends Composer<_$BancoLocal, $RegistrosTable> {
  $$RegistrosTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get tabela => $composableBuilder(
    column: $table.tabela,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dados => $composableBuilder(
    column: $table.dados,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RegistrosTableAnnotationComposer
    extends Composer<_$BancoLocal, $RegistrosTable> {
  $$RegistrosTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get tabela =>
      $composableBuilder(column: $table.tabela, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get dados =>
      $composableBuilder(column: $table.dados, builder: (column) => column);
}

class $$RegistrosTableTableManager
    extends
        RootTableManager<
          _$BancoLocal,
          $RegistrosTable,
          Registro,
          $$RegistrosTableFilterComposer,
          $$RegistrosTableOrderingComposer,
          $$RegistrosTableAnnotationComposer,
          $$RegistrosTableCreateCompanionBuilder,
          $$RegistrosTableUpdateCompanionBuilder,
          (Registro, BaseReferences<_$BancoLocal, $RegistrosTable, Registro>),
          Registro,
          PrefetchHooks Function()
        > {
  $$RegistrosTableTableManager(_$BancoLocal db, $RegistrosTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RegistrosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RegistrosTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RegistrosTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> tabela = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> dados = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RegistrosCompanion(
                tabela: tabela,
                id: id,
                dados: dados,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String tabela,
                required String id,
                required String dados,
                Value<int> rowid = const Value.absent(),
              }) => RegistrosCompanion.insert(
                tabela: tabela,
                id: id,
                dados: dados,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RegistrosTable, Registro>(table),
                  BaseReferences<_$BancoLocal, $RegistrosTable, Registro>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RegistrosTableProcessedTableManager =
    ProcessedTableManager<
      _$BancoLocal,
      $RegistrosTable,
      Registro,
      $$RegistrosTableFilterComposer,
      $$RegistrosTableOrderingComposer,
      $$RegistrosTableAnnotationComposer,
      $$RegistrosTableCreateCompanionBuilder,
      $$RegistrosTableUpdateCompanionBuilder,
      (Registro, BaseReferences<_$BancoLocal, $RegistrosTable, Registro>),
      Registro,
      PrefetchHooks Function()
    >;
typedef $$FilaEnvioTableCreateCompanionBuilder =
    FilaEnvioCompanion Function({
      Value<int> seq,
      required String tabela,
      required String registroId,
      required String dados,
      Value<int> versao,
      Value<String> situacao,
      Value<String?> mensagem,
      Value<DateTime> criadoEm,
    });
typedef $$FilaEnvioTableUpdateCompanionBuilder =
    FilaEnvioCompanion Function({
      Value<int> seq,
      Value<String> tabela,
      Value<String> registroId,
      Value<String> dados,
      Value<int> versao,
      Value<String> situacao,
      Value<String?> mensagem,
      Value<DateTime> criadoEm,
    });

class $$FilaEnvioTableFilterComposer
    extends Composer<_$BancoLocal, $FilaEnvioTable> {
  $$FilaEnvioTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tabela => $composableBuilder(
    column: $table.tabela,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get registroId => $composableBuilder(
    column: $table.registroId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dados => $composableBuilder(
    column: $table.dados,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get versao => $composableBuilder(
    column: $table.versao,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get situacao => $composableBuilder(
    column: $table.situacao,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mensagem => $composableBuilder(
    column: $table.mensagem,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get criadoEm => $composableBuilder(
    column: $table.criadoEm,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FilaEnvioTableOrderingComposer
    extends Composer<_$BancoLocal, $FilaEnvioTable> {
  $$FilaEnvioTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tabela => $composableBuilder(
    column: $table.tabela,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get registroId => $composableBuilder(
    column: $table.registroId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dados => $composableBuilder(
    column: $table.dados,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get versao => $composableBuilder(
    column: $table.versao,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get situacao => $composableBuilder(
    column: $table.situacao,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mensagem => $composableBuilder(
    column: $table.mensagem,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get criadoEm => $composableBuilder(
    column: $table.criadoEm,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FilaEnvioTableAnnotationComposer
    extends Composer<_$BancoLocal, $FilaEnvioTable> {
  $$FilaEnvioTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<String> get tabela =>
      $composableBuilder(column: $table.tabela, builder: (column) => column);

  GeneratedColumn<String> get registroId => $composableBuilder(
    column: $table.registroId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dados =>
      $composableBuilder(column: $table.dados, builder: (column) => column);

  GeneratedColumn<int> get versao =>
      $composableBuilder(column: $table.versao, builder: (column) => column);

  GeneratedColumn<String> get situacao =>
      $composableBuilder(column: $table.situacao, builder: (column) => column);

  GeneratedColumn<String> get mensagem =>
      $composableBuilder(column: $table.mensagem, builder: (column) => column);

  GeneratedColumn<DateTime> get criadoEm =>
      $composableBuilder(column: $table.criadoEm, builder: (column) => column);
}

class $$FilaEnvioTableTableManager
    extends
        RootTableManager<
          _$BancoLocal,
          $FilaEnvioTable,
          FilaEnvioData,
          $$FilaEnvioTableFilterComposer,
          $$FilaEnvioTableOrderingComposer,
          $$FilaEnvioTableAnnotationComposer,
          $$FilaEnvioTableCreateCompanionBuilder,
          $$FilaEnvioTableUpdateCompanionBuilder,
          (
            FilaEnvioData,
            BaseReferences<_$BancoLocal, $FilaEnvioTable, FilaEnvioData>,
          ),
          FilaEnvioData,
          PrefetchHooks Function()
        > {
  $$FilaEnvioTableTableManager(_$BancoLocal db, $FilaEnvioTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FilaEnvioTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FilaEnvioTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FilaEnvioTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> seq = const Value.absent(),
                Value<String> tabela = const Value.absent(),
                Value<String> registroId = const Value.absent(),
                Value<String> dados = const Value.absent(),
                Value<int> versao = const Value.absent(),
                Value<String> situacao = const Value.absent(),
                Value<String?> mensagem = const Value.absent(),
                Value<DateTime> criadoEm = const Value.absent(),
              }) => FilaEnvioCompanion(
                seq: seq,
                tabela: tabela,
                registroId: registroId,
                dados: dados,
                versao: versao,
                situacao: situacao,
                mensagem: mensagem,
                criadoEm: criadoEm,
              ),
          createCompanionCallback:
              ({
                Value<int> seq = const Value.absent(),
                required String tabela,
                required String registroId,
                required String dados,
                Value<int> versao = const Value.absent(),
                Value<String> situacao = const Value.absent(),
                Value<String?> mensagem = const Value.absent(),
                Value<DateTime> criadoEm = const Value.absent(),
              }) => FilaEnvioCompanion.insert(
                seq: seq,
                tabela: tabela,
                registroId: registroId,
                dados: dados,
                versao: versao,
                situacao: situacao,
                mensagem: mensagem,
                criadoEm: criadoEm,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$FilaEnvioTable, FilaEnvioData>(table),
                  BaseReferences<_$BancoLocal, $FilaEnvioTable, FilaEnvioData>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FilaEnvioTableProcessedTableManager =
    ProcessedTableManager<
      _$BancoLocal,
      $FilaEnvioTable,
      FilaEnvioData,
      $$FilaEnvioTableFilterComposer,
      $$FilaEnvioTableOrderingComposer,
      $$FilaEnvioTableAnnotationComposer,
      $$FilaEnvioTableCreateCompanionBuilder,
      $$FilaEnvioTableUpdateCompanionBuilder,
      (
        FilaEnvioData,
        BaseReferences<_$BancoLocal, $FilaEnvioTable, FilaEnvioData>,
      ),
      FilaEnvioData,
      PrefetchHooks Function()
    >;
typedef $$EstadoTableCreateCompanionBuilder =
    EstadoCompanion Function({
      required String chave,
      Value<String?> valor,
      Value<int> rowid,
    });
typedef $$EstadoTableUpdateCompanionBuilder =
    EstadoCompanion Function({
      Value<String> chave,
      Value<String?> valor,
      Value<int> rowid,
    });

class $$EstadoTableFilterComposer extends Composer<_$BancoLocal, $EstadoTable> {
  $$EstadoTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get chave => $composableBuilder(
    column: $table.chave,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get valor => $composableBuilder(
    column: $table.valor,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EstadoTableOrderingComposer
    extends Composer<_$BancoLocal, $EstadoTable> {
  $$EstadoTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get chave => $composableBuilder(
    column: $table.chave,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get valor => $composableBuilder(
    column: $table.valor,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EstadoTableAnnotationComposer
    extends Composer<_$BancoLocal, $EstadoTable> {
  $$EstadoTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get chave =>
      $composableBuilder(column: $table.chave, builder: (column) => column);

  GeneratedColumn<String> get valor =>
      $composableBuilder(column: $table.valor, builder: (column) => column);
}

class $$EstadoTableTableManager
    extends
        RootTableManager<
          _$BancoLocal,
          $EstadoTable,
          EstadoData,
          $$EstadoTableFilterComposer,
          $$EstadoTableOrderingComposer,
          $$EstadoTableAnnotationComposer,
          $$EstadoTableCreateCompanionBuilder,
          $$EstadoTableUpdateCompanionBuilder,
          (EstadoData, BaseReferences<_$BancoLocal, $EstadoTable, EstadoData>),
          EstadoData,
          PrefetchHooks Function()
        > {
  $$EstadoTableTableManager(_$BancoLocal db, $EstadoTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EstadoTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EstadoTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EstadoTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> chave = const Value.absent(),
                Value<String?> valor = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EstadoCompanion(chave: chave, valor: valor, rowid: rowid),
          createCompanionCallback:
              ({
                required String chave,
                Value<String?> valor = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EstadoCompanion.insert(
                chave: chave,
                valor: valor,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EstadoTable, EstadoData>(table),
                  BaseReferences<_$BancoLocal, $EstadoTable, EstadoData>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EstadoTableProcessedTableManager =
    ProcessedTableManager<
      _$BancoLocal,
      $EstadoTable,
      EstadoData,
      $$EstadoTableFilterComposer,
      $$EstadoTableOrderingComposer,
      $$EstadoTableAnnotationComposer,
      $$EstadoTableCreateCompanionBuilder,
      $$EstadoTableUpdateCompanionBuilder,
      (EstadoData, BaseReferences<_$BancoLocal, $EstadoTable, EstadoData>),
      EstadoData,
      PrefetchHooks Function()
    >;

class $BancoLocalManager {
  final _$BancoLocal _db;
  $BancoLocalManager(this._db);
  $$RegistrosTableTableManager get registros =>
      $$RegistrosTableTableManager(_db, _db.registros);
  $$FilaEnvioTableTableManager get filaEnvio =>
      $$FilaEnvioTableTableManager(_db, _db.filaEnvio);
  $$EstadoTableTableManager get estado =>
      $$EstadoTableTableManager(_db, _db.estado);
}
