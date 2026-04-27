// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sketch_catalog_database.dart';

// ignore_for_file: type=lint
mixin _$SketchDaoMixin on DatabaseAccessor<SketchCatalogDatabase> {
  $SketchEntriesTable get sketchEntries => attachedDatabase.sketchEntries;
  SketchDaoManager get managers => SketchDaoManager(this);
}

class SketchDaoManager {
  final _$SketchDaoMixin _db;
  SketchDaoManager(this._db);
  $$SketchEntriesTableTableManager get sketchEntries =>
      $$SketchEntriesTableTableManager(_db.attachedDatabase, _db.sketchEntries);
}

class $SketchEntriesTable extends SketchEntries
    with TableInfo<$SketchEntriesTable, SketchEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SketchEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 120,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameNormalizedMeta = const VerificationMeta(
    'nameNormalized',
  );
  @override
  late final GeneratedColumn<String> nameNormalized = GeneratedColumn<String>(
    'name_normalized',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _languageMeta = const VerificationMeta(
    'language',
  );
  @override
  late final GeneratedColumn<String> language = GeneratedColumn<String>(
    'language',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('p5js'),
  );
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
    'code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    nameNormalized,
    language,
    code,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sketches';
  @override
  VerificationContext validateIntegrity(
    Insertable<SketchEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('name_normalized')) {
      context.handle(
        _nameNormalizedMeta,
        nameNormalized.isAcceptableOrUnknown(
          data['name_normalized']!,
          _nameNormalizedMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_nameNormalizedMeta);
    }
    if (data.containsKey('language')) {
      context.handle(
        _languageMeta,
        language.isAcceptableOrUnknown(data['language']!, _languageMeta),
      );
    }
    if (data.containsKey('code')) {
      context.handle(
        _codeMeta,
        code.isAcceptableOrUnknown(data['code']!, _codeMeta),
      );
    } else if (isInserting) {
      context.missing(_codeMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {nameNormalized},
  ];
  @override
  SketchEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SketchEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      nameNormalized: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name_normalized'],
      )!,
      language: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}language'],
      )!,
      code: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}code'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $SketchEntriesTable createAlias(String alias) {
    return $SketchEntriesTable(attachedDatabase, alias);
  }
}

class SketchEntry extends DataClass implements Insertable<SketchEntry> {
  final String id;
  final String name;
  final String nameNormalized;
  final String language;
  final String code;
  final int createdAt;
  final int updatedAt;
  const SketchEntry({
    required this.id,
    required this.name,
    required this.nameNormalized,
    required this.language,
    required this.code,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['name_normalized'] = Variable<String>(nameNormalized);
    map['language'] = Variable<String>(language);
    map['code'] = Variable<String>(code);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  SketchEntriesCompanion toCompanion(bool nullToAbsent) {
    return SketchEntriesCompanion(
      id: Value(id),
      name: Value(name),
      nameNormalized: Value(nameNormalized),
      language: Value(language),
      code: Value(code),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory SketchEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SketchEntry(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      nameNormalized: serializer.fromJson<String>(json['nameNormalized']),
      language: serializer.fromJson<String>(json['language']),
      code: serializer.fromJson<String>(json['code']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'nameNormalized': serializer.toJson<String>(nameNormalized),
      'language': serializer.toJson<String>(language),
      'code': serializer.toJson<String>(code),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  SketchEntry copyWith({
    String? id,
    String? name,
    String? nameNormalized,
    String? language,
    String? code,
    int? createdAt,
    int? updatedAt,
  }) => SketchEntry(
    id: id ?? this.id,
    name: name ?? this.name,
    nameNormalized: nameNormalized ?? this.nameNormalized,
    language: language ?? this.language,
    code: code ?? this.code,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  SketchEntry copyWithCompanion(SketchEntriesCompanion data) {
    return SketchEntry(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      nameNormalized: data.nameNormalized.present
          ? data.nameNormalized.value
          : this.nameNormalized,
      language: data.language.present ? data.language.value : this.language,
      code: data.code.present ? data.code.value : this.code,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SketchEntry(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('nameNormalized: $nameNormalized, ')
          ..write('language: $language, ')
          ..write('code: $code, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    nameNormalized,
    language,
    code,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SketchEntry &&
          other.id == this.id &&
          other.name == this.name &&
          other.nameNormalized == this.nameNormalized &&
          other.language == this.language &&
          other.code == this.code &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class SketchEntriesCompanion extends UpdateCompanion<SketchEntry> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> nameNormalized;
  final Value<String> language;
  final Value<String> code;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const SketchEntriesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.nameNormalized = const Value.absent(),
    this.language = const Value.absent(),
    this.code = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SketchEntriesCompanion.insert({
    required String id,
    required String name,
    required String nameNormalized,
    this.language = const Value.absent(),
    required String code,
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       nameNormalized = Value(nameNormalized),
       code = Value(code),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<SketchEntry> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? nameNormalized,
    Expression<String>? language,
    Expression<String>? code,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (nameNormalized != null) 'name_normalized': nameNormalized,
      if (language != null) 'language': language,
      if (code != null) 'code': code,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SketchEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? nameNormalized,
    Value<String>? language,
    Value<String>? code,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return SketchEntriesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      nameNormalized: nameNormalized ?? this.nameNormalized,
      language: language ?? this.language,
      code: code ?? this.code,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (nameNormalized.present) {
      map['name_normalized'] = Variable<String>(nameNormalized.value);
    }
    if (language.present) {
      map['language'] = Variable<String>(language.value);
    }
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SketchEntriesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('nameNormalized: $nameNormalized, ')
          ..write('language: $language, ')
          ..write('code: $code, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$SketchCatalogDatabase extends GeneratedDatabase {
  _$SketchCatalogDatabase(QueryExecutor e) : super(e);
  $SketchCatalogDatabaseManager get managers =>
      $SketchCatalogDatabaseManager(this);
  late final $SketchEntriesTable sketchEntries = $SketchEntriesTable(this);
  late final SketchDao sketchDao = SketchDao(this as SketchCatalogDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [sketchEntries];
}

typedef $$SketchEntriesTableCreateCompanionBuilder =
    SketchEntriesCompanion Function({
      required String id,
      required String name,
      required String nameNormalized,
      Value<String> language,
      required String code,
      required int createdAt,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$SketchEntriesTableUpdateCompanionBuilder =
    SketchEntriesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> nameNormalized,
      Value<String> language,
      Value<String> code,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$SketchEntriesTableFilterComposer
    extends Composer<_$SketchCatalogDatabase, $SketchEntriesTable> {
  $$SketchEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nameNormalized => $composableBuilder(
    column: $table.nameNormalized,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SketchEntriesTableOrderingComposer
    extends Composer<_$SketchCatalogDatabase, $SketchEntriesTable> {
  $$SketchEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nameNormalized => $composableBuilder(
    column: $table.nameNormalized,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SketchEntriesTableAnnotationComposer
    extends Composer<_$SketchCatalogDatabase, $SketchEntriesTable> {
  $$SketchEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get nameNormalized => $composableBuilder(
    column: $table.nameNormalized,
    builder: (column) => column,
  );

  GeneratedColumn<String> get language =>
      $composableBuilder(column: $table.language, builder: (column) => column);

  GeneratedColumn<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SketchEntriesTableTableManager
    extends
        RootTableManager<
          _$SketchCatalogDatabase,
          $SketchEntriesTable,
          SketchEntry,
          $$SketchEntriesTableFilterComposer,
          $$SketchEntriesTableOrderingComposer,
          $$SketchEntriesTableAnnotationComposer,
          $$SketchEntriesTableCreateCompanionBuilder,
          $$SketchEntriesTableUpdateCompanionBuilder,
          (
            SketchEntry,
            BaseReferences<
              _$SketchCatalogDatabase,
              $SketchEntriesTable,
              SketchEntry
            >,
          ),
          SketchEntry,
          PrefetchHooks Function()
        > {
  $$SketchEntriesTableTableManager(
    _$SketchCatalogDatabase db,
    $SketchEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SketchEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SketchEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SketchEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> nameNormalized = const Value.absent(),
                Value<String> language = const Value.absent(),
                Value<String> code = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SketchEntriesCompanion(
                id: id,
                name: name,
                nameNormalized: nameNormalized,
                language: language,
                code: code,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String nameNormalized,
                Value<String> language = const Value.absent(),
                required String code,
                required int createdAt,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => SketchEntriesCompanion.insert(
                id: id,
                name: name,
                nameNormalized: nameNormalized,
                language: language,
                code: code,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SketchEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$SketchCatalogDatabase,
      $SketchEntriesTable,
      SketchEntry,
      $$SketchEntriesTableFilterComposer,
      $$SketchEntriesTableOrderingComposer,
      $$SketchEntriesTableAnnotationComposer,
      $$SketchEntriesTableCreateCompanionBuilder,
      $$SketchEntriesTableUpdateCompanionBuilder,
      (
        SketchEntry,
        BaseReferences<
          _$SketchCatalogDatabase,
          $SketchEntriesTable,
          SketchEntry
        >,
      ),
      SketchEntry,
      PrefetchHooks Function()
    >;

class $SketchCatalogDatabaseManager {
  final _$SketchCatalogDatabase _db;
  $SketchCatalogDatabaseManager(this._db);
  $$SketchEntriesTableTableManager get sketchEntries =>
      $$SketchEntriesTableTableManager(_db, _db.sketchEntries);
}
