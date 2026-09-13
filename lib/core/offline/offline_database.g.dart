// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'offline_database.dart';

// ignore_for_file: type=lint
class $CachedResponsesTable extends CachedResponses
    with TableInfo<$CachedResponsesTable, CachedResponse> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedResponsesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _cacheKeyMeta = const VerificationMeta(
    'cacheKey',
  );
  @override
  late final GeneratedColumn<String> cacheKey = GeneratedColumn<String>(
    'cache_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accountKeyMeta = const VerificationMeta(
    'accountKey',
  );
  @override
  late final GeneratedColumn<String> accountKey = GeneratedColumn<String>(
    'account_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _methodMeta = const VerificationMeta('method');
  @override
  late final GeneratedColumn<String> method = GeneratedColumn<String>(
    'method',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('GET'),
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _queryJsonMeta = const VerificationMeta(
    'queryJson',
  );
  @override
  late final GeneratedColumn<String> queryJson = GeneratedColumn<String>(
    'query_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _bodyJsonMeta = const VerificationMeta(
    'bodyJson',
  );
  @override
  late final GeneratedColumn<String> bodyJson = GeneratedColumn<String>(
    'body_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusCodeMeta = const VerificationMeta(
    'statusCode',
  );
  @override
  late final GeneratedColumn<int> statusCode = GeneratedColumn<int>(
    'status_code',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(200),
  );
  static const VerificationMeta _storedAtMeta = const VerificationMeta(
    'storedAt',
  );
  @override
  late final GeneratedColumn<DateTime> storedAt = GeneratedColumn<DateTime>(
    'stored_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _expiresAtMeta = const VerificationMeta(
    'expiresAt',
  );
  @override
  late final GeneratedColumn<DateTime> expiresAt = GeneratedColumn<DateTime>(
    'expires_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    cacheKey,
    accountKey,
    method,
    path,
    queryJson,
    bodyJson,
    statusCode,
    storedAt,
    expiresAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_responses';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedResponse> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('cache_key')) {
      context.handle(
        _cacheKeyMeta,
        cacheKey.isAcceptableOrUnknown(data['cache_key']!, _cacheKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_cacheKeyMeta);
    }
    if (data.containsKey('account_key')) {
      context.handle(
        _accountKeyMeta,
        accountKey.isAcceptableOrUnknown(data['account_key']!, _accountKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_accountKeyMeta);
    }
    if (data.containsKey('method')) {
      context.handle(
        _methodMeta,
        method.isAcceptableOrUnknown(data['method']!, _methodMeta),
      );
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('query_json')) {
      context.handle(
        _queryJsonMeta,
        queryJson.isAcceptableOrUnknown(data['query_json']!, _queryJsonMeta),
      );
    }
    if (data.containsKey('body_json')) {
      context.handle(
        _bodyJsonMeta,
        bodyJson.isAcceptableOrUnknown(data['body_json']!, _bodyJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyJsonMeta);
    }
    if (data.containsKey('status_code')) {
      context.handle(
        _statusCodeMeta,
        statusCode.isAcceptableOrUnknown(data['status_code']!, _statusCodeMeta),
      );
    }
    if (data.containsKey('stored_at')) {
      context.handle(
        _storedAtMeta,
        storedAt.isAcceptableOrUnknown(data['stored_at']!, _storedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_storedAtMeta);
    }
    if (data.containsKey('expires_at')) {
      context.handle(
        _expiresAtMeta,
        expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {cacheKey};
  @override
  CachedResponse map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedResponse(
      cacheKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cache_key'],
      )!,
      accountKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_key'],
      )!,
      method: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}method'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      queryJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}query_json'],
      )!,
      bodyJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body_json'],
      )!,
      statusCode: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}status_code'],
      )!,
      storedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}stored_at'],
      )!,
      expiresAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}expires_at'],
      ),
    );
  }

  @override
  $CachedResponsesTable createAlias(String alias) {
    return $CachedResponsesTable(attachedDatabase, alias);
  }
}

class CachedResponse extends DataClass implements Insertable<CachedResponse> {
  final String cacheKey;
  final String accountKey;
  final String method;
  final String path;
  final String queryJson;
  final String bodyJson;
  final int statusCode;
  final DateTime storedAt;
  final DateTime? expiresAt;
  const CachedResponse({
    required this.cacheKey,
    required this.accountKey,
    required this.method,
    required this.path,
    required this.queryJson,
    required this.bodyJson,
    required this.statusCode,
    required this.storedAt,
    this.expiresAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['cache_key'] = Variable<String>(cacheKey);
    map['account_key'] = Variable<String>(accountKey);
    map['method'] = Variable<String>(method);
    map['path'] = Variable<String>(path);
    map['query_json'] = Variable<String>(queryJson);
    map['body_json'] = Variable<String>(bodyJson);
    map['status_code'] = Variable<int>(statusCode);
    map['stored_at'] = Variable<DateTime>(storedAt);
    if (!nullToAbsent || expiresAt != null) {
      map['expires_at'] = Variable<DateTime>(expiresAt);
    }
    return map;
  }

  CachedResponsesCompanion toCompanion(bool nullToAbsent) {
    return CachedResponsesCompanion(
      cacheKey: Value(cacheKey),
      accountKey: Value(accountKey),
      method: Value(method),
      path: Value(path),
      queryJson: Value(queryJson),
      bodyJson: Value(bodyJson),
      statusCode: Value(statusCode),
      storedAt: Value(storedAt),
      expiresAt: expiresAt == null && nullToAbsent
          ? const Value.absent()
          : Value(expiresAt),
    );
  }

  factory CachedResponse.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedResponse(
      cacheKey: serializer.fromJson<String>(json['cacheKey']),
      accountKey: serializer.fromJson<String>(json['accountKey']),
      method: serializer.fromJson<String>(json['method']),
      path: serializer.fromJson<String>(json['path']),
      queryJson: serializer.fromJson<String>(json['queryJson']),
      bodyJson: serializer.fromJson<String>(json['bodyJson']),
      statusCode: serializer.fromJson<int>(json['statusCode']),
      storedAt: serializer.fromJson<DateTime>(json['storedAt']),
      expiresAt: serializer.fromJson<DateTime?>(json['expiresAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'cacheKey': serializer.toJson<String>(cacheKey),
      'accountKey': serializer.toJson<String>(accountKey),
      'method': serializer.toJson<String>(method),
      'path': serializer.toJson<String>(path),
      'queryJson': serializer.toJson<String>(queryJson),
      'bodyJson': serializer.toJson<String>(bodyJson),
      'statusCode': serializer.toJson<int>(statusCode),
      'storedAt': serializer.toJson<DateTime>(storedAt),
      'expiresAt': serializer.toJson<DateTime?>(expiresAt),
    };
  }

  CachedResponse copyWith({
    String? cacheKey,
    String? accountKey,
    String? method,
    String? path,
    String? queryJson,
    String? bodyJson,
    int? statusCode,
    DateTime? storedAt,
    Value<DateTime?> expiresAt = const Value.absent(),
  }) => CachedResponse(
    cacheKey: cacheKey ?? this.cacheKey,
    accountKey: accountKey ?? this.accountKey,
    method: method ?? this.method,
    path: path ?? this.path,
    queryJson: queryJson ?? this.queryJson,
    bodyJson: bodyJson ?? this.bodyJson,
    statusCode: statusCode ?? this.statusCode,
    storedAt: storedAt ?? this.storedAt,
    expiresAt: expiresAt.present ? expiresAt.value : this.expiresAt,
  );
  CachedResponse copyWithCompanion(CachedResponsesCompanion data) {
    return CachedResponse(
      cacheKey: data.cacheKey.present ? data.cacheKey.value : this.cacheKey,
      accountKey: data.accountKey.present
          ? data.accountKey.value
          : this.accountKey,
      method: data.method.present ? data.method.value : this.method,
      path: data.path.present ? data.path.value : this.path,
      queryJson: data.queryJson.present ? data.queryJson.value : this.queryJson,
      bodyJson: data.bodyJson.present ? data.bodyJson.value : this.bodyJson,
      statusCode: data.statusCode.present
          ? data.statusCode.value
          : this.statusCode,
      storedAt: data.storedAt.present ? data.storedAt.value : this.storedAt,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedResponse(')
          ..write('cacheKey: $cacheKey, ')
          ..write('accountKey: $accountKey, ')
          ..write('method: $method, ')
          ..write('path: $path, ')
          ..write('queryJson: $queryJson, ')
          ..write('bodyJson: $bodyJson, ')
          ..write('statusCode: $statusCode, ')
          ..write('storedAt: $storedAt, ')
          ..write('expiresAt: $expiresAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    cacheKey,
    accountKey,
    method,
    path,
    queryJson,
    bodyJson,
    statusCode,
    storedAt,
    expiresAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedResponse &&
          other.cacheKey == this.cacheKey &&
          other.accountKey == this.accountKey &&
          other.method == this.method &&
          other.path == this.path &&
          other.queryJson == this.queryJson &&
          other.bodyJson == this.bodyJson &&
          other.statusCode == this.statusCode &&
          other.storedAt == this.storedAt &&
          other.expiresAt == this.expiresAt);
}

class CachedResponsesCompanion extends UpdateCompanion<CachedResponse> {
  final Value<String> cacheKey;
  final Value<String> accountKey;
  final Value<String> method;
  final Value<String> path;
  final Value<String> queryJson;
  final Value<String> bodyJson;
  final Value<int> statusCode;
  final Value<DateTime> storedAt;
  final Value<DateTime?> expiresAt;
  final Value<int> rowid;
  const CachedResponsesCompanion({
    this.cacheKey = const Value.absent(),
    this.accountKey = const Value.absent(),
    this.method = const Value.absent(),
    this.path = const Value.absent(),
    this.queryJson = const Value.absent(),
    this.bodyJson = const Value.absent(),
    this.statusCode = const Value.absent(),
    this.storedAt = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedResponsesCompanion.insert({
    required String cacheKey,
    required String accountKey,
    this.method = const Value.absent(),
    required String path,
    this.queryJson = const Value.absent(),
    required String bodyJson,
    this.statusCode = const Value.absent(),
    required DateTime storedAt,
    this.expiresAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : cacheKey = Value(cacheKey),
       accountKey = Value(accountKey),
       path = Value(path),
       bodyJson = Value(bodyJson),
       storedAt = Value(storedAt);
  static Insertable<CachedResponse> custom({
    Expression<String>? cacheKey,
    Expression<String>? accountKey,
    Expression<String>? method,
    Expression<String>? path,
    Expression<String>? queryJson,
    Expression<String>? bodyJson,
    Expression<int>? statusCode,
    Expression<DateTime>? storedAt,
    Expression<DateTime>? expiresAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (cacheKey != null) 'cache_key': cacheKey,
      if (accountKey != null) 'account_key': accountKey,
      if (method != null) 'method': method,
      if (path != null) 'path': path,
      if (queryJson != null) 'query_json': queryJson,
      if (bodyJson != null) 'body_json': bodyJson,
      if (statusCode != null) 'status_code': statusCode,
      if (storedAt != null) 'stored_at': storedAt,
      if (expiresAt != null) 'expires_at': expiresAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedResponsesCompanion copyWith({
    Value<String>? cacheKey,
    Value<String>? accountKey,
    Value<String>? method,
    Value<String>? path,
    Value<String>? queryJson,
    Value<String>? bodyJson,
    Value<int>? statusCode,
    Value<DateTime>? storedAt,
    Value<DateTime?>? expiresAt,
    Value<int>? rowid,
  }) {
    return CachedResponsesCompanion(
      cacheKey: cacheKey ?? this.cacheKey,
      accountKey: accountKey ?? this.accountKey,
      method: method ?? this.method,
      path: path ?? this.path,
      queryJson: queryJson ?? this.queryJson,
      bodyJson: bodyJson ?? this.bodyJson,
      statusCode: statusCode ?? this.statusCode,
      storedAt: storedAt ?? this.storedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (cacheKey.present) {
      map['cache_key'] = Variable<String>(cacheKey.value);
    }
    if (accountKey.present) {
      map['account_key'] = Variable<String>(accountKey.value);
    }
    if (method.present) {
      map['method'] = Variable<String>(method.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (queryJson.present) {
      map['query_json'] = Variable<String>(queryJson.value);
    }
    if (bodyJson.present) {
      map['body_json'] = Variable<String>(bodyJson.value);
    }
    if (statusCode.present) {
      map['status_code'] = Variable<int>(statusCode.value);
    }
    if (storedAt.present) {
      map['stored_at'] = Variable<DateTime>(storedAt.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<DateTime>(expiresAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedResponsesCompanion(')
          ..write('cacheKey: $cacheKey, ')
          ..write('accountKey: $accountKey, ')
          ..write('method: $method, ')
          ..write('path: $path, ')
          ..write('queryJson: $queryJson, ')
          ..write('bodyJson: $bodyJson, ')
          ..write('statusCode: $statusCode, ')
          ..write('storedAt: $storedAt, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncOutboxEntriesTable extends SyncOutboxEntries
    with TableInfo<$SyncOutboxEntriesTable, SyncOutboxEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncOutboxEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _accountKeyMeta = const VerificationMeta(
    'accountKey',
  );
  @override
  late final GeneratedColumn<String> accountKey = GeneratedColumn<String>(
    'account_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _operationTypeMeta = const VerificationMeta(
    'operationType',
  );
  @override
  late final GeneratedColumn<String> operationType = GeneratedColumn<String>(
    'operation_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _methodMeta = const VerificationMeta('method');
  @override
  late final GeneratedColumn<String> method = GeneratedColumn<String>(
    'method',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _queryJsonMeta = const VerificationMeta(
    'queryJson',
  );
  @override
  late final GeneratedColumn<String> queryJson = GeneratedColumn<String>(
    'query_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idempotencyKeyMeta = const VerificationMeta(
    'idempotencyKey',
  );
  @override
  late final GeneratedColumn<String> idempotencyKey = GeneratedColumn<String>(
    'idempotency_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _retryCountMeta = const VerificationMeta(
    'retryCount',
  );
  @override
  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
    'retry_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nextAttemptAtMeta = const VerificationMeta(
    'nextAttemptAt',
  );
  @override
  late final GeneratedColumn<DateTime> nextAttemptAt =
      GeneratedColumn<DateTime>(
        'next_attempt_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    accountKey,
    operationType,
    method,
    path,
    queryJson,
    payloadJson,
    idempotencyKey,
    createdAt,
    retryCount,
    status,
    lastError,
    nextAttemptAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_outbox_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncOutboxEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('account_key')) {
      context.handle(
        _accountKeyMeta,
        accountKey.isAcceptableOrUnknown(data['account_key']!, _accountKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_accountKeyMeta);
    }
    if (data.containsKey('operation_type')) {
      context.handle(
        _operationTypeMeta,
        operationType.isAcceptableOrUnknown(
          data['operation_type']!,
          _operationTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_operationTypeMeta);
    }
    if (data.containsKey('method')) {
      context.handle(
        _methodMeta,
        method.isAcceptableOrUnknown(data['method']!, _methodMeta),
      );
    } else if (isInserting) {
      context.missing(_methodMeta);
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('query_json')) {
      context.handle(
        _queryJsonMeta,
        queryJson.isAcceptableOrUnknown(data['query_json']!, _queryJsonMeta),
      );
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('idempotency_key')) {
      context.handle(
        _idempotencyKeyMeta,
        idempotencyKey.isAcceptableOrUnknown(
          data['idempotency_key']!,
          _idempotencyKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_idempotencyKeyMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('retry_count')) {
      context.handle(
        _retryCountMeta,
        retryCount.isAcceptableOrUnknown(data['retry_count']!, _retryCountMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('next_attempt_at')) {
      context.handle(
        _nextAttemptAtMeta,
        nextAttemptAt.isAcceptableOrUnknown(
          data['next_attempt_at']!,
          _nextAttemptAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncOutboxEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncOutboxEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      accountKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_key'],
      )!,
      operationType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation_type'],
      )!,
      method: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}method'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      queryJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}query_json'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      idempotencyKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}idempotency_key'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      retryCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}retry_count'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      nextAttemptAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_attempt_at'],
      ),
    );
  }

  @override
  $SyncOutboxEntriesTable createAlias(String alias) {
    return $SyncOutboxEntriesTable(attachedDatabase, alias);
  }
}

class SyncOutboxEntry extends DataClass implements Insertable<SyncOutboxEntry> {
  final int id;
  final String accountKey;
  final String operationType;
  final String method;
  final String path;
  final String queryJson;
  final String payloadJson;
  final String idempotencyKey;
  final DateTime createdAt;
  final int retryCount;
  final String status;
  final String? lastError;
  final DateTime? nextAttemptAt;
  const SyncOutboxEntry({
    required this.id,
    required this.accountKey,
    required this.operationType,
    required this.method,
    required this.path,
    required this.queryJson,
    required this.payloadJson,
    required this.idempotencyKey,
    required this.createdAt,
    required this.retryCount,
    required this.status,
    this.lastError,
    this.nextAttemptAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['account_key'] = Variable<String>(accountKey);
    map['operation_type'] = Variable<String>(operationType);
    map['method'] = Variable<String>(method);
    map['path'] = Variable<String>(path);
    map['query_json'] = Variable<String>(queryJson);
    map['payload_json'] = Variable<String>(payloadJson);
    map['idempotency_key'] = Variable<String>(idempotencyKey);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['retry_count'] = Variable<int>(retryCount);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    if (!nullToAbsent || nextAttemptAt != null) {
      map['next_attempt_at'] = Variable<DateTime>(nextAttemptAt);
    }
    return map;
  }

  SyncOutboxEntriesCompanion toCompanion(bool nullToAbsent) {
    return SyncOutboxEntriesCompanion(
      id: Value(id),
      accountKey: Value(accountKey),
      operationType: Value(operationType),
      method: Value(method),
      path: Value(path),
      queryJson: Value(queryJson),
      payloadJson: Value(payloadJson),
      idempotencyKey: Value(idempotencyKey),
      createdAt: Value(createdAt),
      retryCount: Value(retryCount),
      status: Value(status),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      nextAttemptAt: nextAttemptAt == null && nullToAbsent
          ? const Value.absent()
          : Value(nextAttemptAt),
    );
  }

  factory SyncOutboxEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncOutboxEntry(
      id: serializer.fromJson<int>(json['id']),
      accountKey: serializer.fromJson<String>(json['accountKey']),
      operationType: serializer.fromJson<String>(json['operationType']),
      method: serializer.fromJson<String>(json['method']),
      path: serializer.fromJson<String>(json['path']),
      queryJson: serializer.fromJson<String>(json['queryJson']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      idempotencyKey: serializer.fromJson<String>(json['idempotencyKey']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
      status: serializer.fromJson<String>(json['status']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      nextAttemptAt: serializer.fromJson<DateTime?>(json['nextAttemptAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'accountKey': serializer.toJson<String>(accountKey),
      'operationType': serializer.toJson<String>(operationType),
      'method': serializer.toJson<String>(method),
      'path': serializer.toJson<String>(path),
      'queryJson': serializer.toJson<String>(queryJson),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'idempotencyKey': serializer.toJson<String>(idempotencyKey),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'retryCount': serializer.toJson<int>(retryCount),
      'status': serializer.toJson<String>(status),
      'lastError': serializer.toJson<String?>(lastError),
      'nextAttemptAt': serializer.toJson<DateTime?>(nextAttemptAt),
    };
  }

  SyncOutboxEntry copyWith({
    int? id,
    String? accountKey,
    String? operationType,
    String? method,
    String? path,
    String? queryJson,
    String? payloadJson,
    String? idempotencyKey,
    DateTime? createdAt,
    int? retryCount,
    String? status,
    Value<String?> lastError = const Value.absent(),
    Value<DateTime?> nextAttemptAt = const Value.absent(),
  }) => SyncOutboxEntry(
    id: id ?? this.id,
    accountKey: accountKey ?? this.accountKey,
    operationType: operationType ?? this.operationType,
    method: method ?? this.method,
    path: path ?? this.path,
    queryJson: queryJson ?? this.queryJson,
    payloadJson: payloadJson ?? this.payloadJson,
    idempotencyKey: idempotencyKey ?? this.idempotencyKey,
    createdAt: createdAt ?? this.createdAt,
    retryCount: retryCount ?? this.retryCount,
    status: status ?? this.status,
    lastError: lastError.present ? lastError.value : this.lastError,
    nextAttemptAt: nextAttemptAt.present
        ? nextAttemptAt.value
        : this.nextAttemptAt,
  );
  SyncOutboxEntry copyWithCompanion(SyncOutboxEntriesCompanion data) {
    return SyncOutboxEntry(
      id: data.id.present ? data.id.value : this.id,
      accountKey: data.accountKey.present
          ? data.accountKey.value
          : this.accountKey,
      operationType: data.operationType.present
          ? data.operationType.value
          : this.operationType,
      method: data.method.present ? data.method.value : this.method,
      path: data.path.present ? data.path.value : this.path,
      queryJson: data.queryJson.present ? data.queryJson.value : this.queryJson,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      idempotencyKey: data.idempotencyKey.present
          ? data.idempotencyKey.value
          : this.idempotencyKey,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      retryCount: data.retryCount.present
          ? data.retryCount.value
          : this.retryCount,
      status: data.status.present ? data.status.value : this.status,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      nextAttemptAt: data.nextAttemptAt.present
          ? data.nextAttemptAt.value
          : this.nextAttemptAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncOutboxEntry(')
          ..write('id: $id, ')
          ..write('accountKey: $accountKey, ')
          ..write('operationType: $operationType, ')
          ..write('method: $method, ')
          ..write('path: $path, ')
          ..write('queryJson: $queryJson, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('idempotencyKey: $idempotencyKey, ')
          ..write('createdAt: $createdAt, ')
          ..write('retryCount: $retryCount, ')
          ..write('status: $status, ')
          ..write('lastError: $lastError, ')
          ..write('nextAttemptAt: $nextAttemptAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    accountKey,
    operationType,
    method,
    path,
    queryJson,
    payloadJson,
    idempotencyKey,
    createdAt,
    retryCount,
    status,
    lastError,
    nextAttemptAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncOutboxEntry &&
          other.id == this.id &&
          other.accountKey == this.accountKey &&
          other.operationType == this.operationType &&
          other.method == this.method &&
          other.path == this.path &&
          other.queryJson == this.queryJson &&
          other.payloadJson == this.payloadJson &&
          other.idempotencyKey == this.idempotencyKey &&
          other.createdAt == this.createdAt &&
          other.retryCount == this.retryCount &&
          other.status == this.status &&
          other.lastError == this.lastError &&
          other.nextAttemptAt == this.nextAttemptAt);
}

class SyncOutboxEntriesCompanion extends UpdateCompanion<SyncOutboxEntry> {
  final Value<int> id;
  final Value<String> accountKey;
  final Value<String> operationType;
  final Value<String> method;
  final Value<String> path;
  final Value<String> queryJson;
  final Value<String> payloadJson;
  final Value<String> idempotencyKey;
  final Value<DateTime> createdAt;
  final Value<int> retryCount;
  final Value<String> status;
  final Value<String?> lastError;
  final Value<DateTime?> nextAttemptAt;
  const SyncOutboxEntriesCompanion({
    this.id = const Value.absent(),
    this.accountKey = const Value.absent(),
    this.operationType = const Value.absent(),
    this.method = const Value.absent(),
    this.path = const Value.absent(),
    this.queryJson = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.idempotencyKey = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.status = const Value.absent(),
    this.lastError = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
  });
  SyncOutboxEntriesCompanion.insert({
    this.id = const Value.absent(),
    required String accountKey,
    required String operationType,
    required String method,
    required String path,
    this.queryJson = const Value.absent(),
    required String payloadJson,
    required String idempotencyKey,
    required DateTime createdAt,
    this.retryCount = const Value.absent(),
    this.status = const Value.absent(),
    this.lastError = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
  }) : accountKey = Value(accountKey),
       operationType = Value(operationType),
       method = Value(method),
       path = Value(path),
       payloadJson = Value(payloadJson),
       idempotencyKey = Value(idempotencyKey),
       createdAt = Value(createdAt);
  static Insertable<SyncOutboxEntry> custom({
    Expression<int>? id,
    Expression<String>? accountKey,
    Expression<String>? operationType,
    Expression<String>? method,
    Expression<String>? path,
    Expression<String>? queryJson,
    Expression<String>? payloadJson,
    Expression<String>? idempotencyKey,
    Expression<DateTime>? createdAt,
    Expression<int>? retryCount,
    Expression<String>? status,
    Expression<String>? lastError,
    Expression<DateTime>? nextAttemptAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (accountKey != null) 'account_key': accountKey,
      if (operationType != null) 'operation_type': operationType,
      if (method != null) 'method': method,
      if (path != null) 'path': path,
      if (queryJson != null) 'query_json': queryJson,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
      if (createdAt != null) 'created_at': createdAt,
      if (retryCount != null) 'retry_count': retryCount,
      if (status != null) 'status': status,
      if (lastError != null) 'last_error': lastError,
      if (nextAttemptAt != null) 'next_attempt_at': nextAttemptAt,
    });
  }

  SyncOutboxEntriesCompanion copyWith({
    Value<int>? id,
    Value<String>? accountKey,
    Value<String>? operationType,
    Value<String>? method,
    Value<String>? path,
    Value<String>? queryJson,
    Value<String>? payloadJson,
    Value<String>? idempotencyKey,
    Value<DateTime>? createdAt,
    Value<int>? retryCount,
    Value<String>? status,
    Value<String?>? lastError,
    Value<DateTime?>? nextAttemptAt,
  }) {
    return SyncOutboxEntriesCompanion(
      id: id ?? this.id,
      accountKey: accountKey ?? this.accountKey,
      operationType: operationType ?? this.operationType,
      method: method ?? this.method,
      path: path ?? this.path,
      queryJson: queryJson ?? this.queryJson,
      payloadJson: payloadJson ?? this.payloadJson,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      createdAt: createdAt ?? this.createdAt,
      retryCount: retryCount ?? this.retryCount,
      status: status ?? this.status,
      lastError: lastError ?? this.lastError,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (accountKey.present) {
      map['account_key'] = Variable<String>(accountKey.value);
    }
    if (operationType.present) {
      map['operation_type'] = Variable<String>(operationType.value);
    }
    if (method.present) {
      map['method'] = Variable<String>(method.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (queryJson.present) {
      map['query_json'] = Variable<String>(queryJson.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (idempotencyKey.present) {
      map['idempotency_key'] = Variable<String>(idempotencyKey.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (nextAttemptAt.present) {
      map['next_attempt_at'] = Variable<DateTime>(nextAttemptAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncOutboxEntriesCompanion(')
          ..write('id: $id, ')
          ..write('accountKey: $accountKey, ')
          ..write('operationType: $operationType, ')
          ..write('method: $method, ')
          ..write('path: $path, ')
          ..write('queryJson: $queryJson, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('idempotencyKey: $idempotencyKey, ')
          ..write('createdAt: $createdAt, ')
          ..write('retryCount: $retryCount, ')
          ..write('status: $status, ')
          ..write('lastError: $lastError, ')
          ..write('nextAttemptAt: $nextAttemptAt')
          ..write(')'))
        .toString();
  }
}

class $SyncStatesTable extends SyncStates
    with TableInfo<$SyncStatesTable, SyncState> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncStatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _accountKeyMeta = const VerificationMeta(
    'accountKey',
  );
  @override
  late final GeneratedColumn<String> accountKey = GeneratedColumn<String>(
    'account_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('idle'),
  );
  static const VerificationMeta _lastAttemptAtMeta = const VerificationMeta(
    'lastAttemptAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastAttemptAt =
      GeneratedColumn<DateTime>(
        'last_attempt_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _lastSyncedAtMeta = const VerificationMeta(
    'lastSyncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSyncedAt = GeneratedColumn<DateTime>(
    'last_synced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    accountKey,
    status,
    lastAttemptAt,
    lastSyncedAt,
    lastError,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_states';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncState> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('account_key')) {
      context.handle(
        _accountKeyMeta,
        accountKey.isAcceptableOrUnknown(data['account_key']!, _accountKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_accountKeyMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('last_attempt_at')) {
      context.handle(
        _lastAttemptAtMeta,
        lastAttemptAt.isAcceptableOrUnknown(
          data['last_attempt_at']!,
          _lastAttemptAtMeta,
        ),
      );
    }
    if (data.containsKey('last_synced_at')) {
      context.handle(
        _lastSyncedAtMeta,
        lastSyncedAt.isAcceptableOrUnknown(
          data['last_synced_at']!,
          _lastSyncedAtMeta,
        ),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {accountKey};
  @override
  SyncState map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncState(
      accountKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_key'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      lastAttemptAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_attempt_at'],
      ),
      lastSyncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_synced_at'],
      ),
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
    );
  }

  @override
  $SyncStatesTable createAlias(String alias) {
    return $SyncStatesTable(attachedDatabase, alias);
  }
}

class SyncState extends DataClass implements Insertable<SyncState> {
  final String accountKey;
  final String status;
  final DateTime? lastAttemptAt;
  final DateTime? lastSyncedAt;
  final String? lastError;
  const SyncState({
    required this.accountKey,
    required this.status,
    this.lastAttemptAt,
    this.lastSyncedAt,
    this.lastError,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['account_key'] = Variable<String>(accountKey);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || lastAttemptAt != null) {
      map['last_attempt_at'] = Variable<DateTime>(lastAttemptAt);
    }
    if (!nullToAbsent || lastSyncedAt != null) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt);
    }
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    return map;
  }

  SyncStatesCompanion toCompanion(bool nullToAbsent) {
    return SyncStatesCompanion(
      accountKey: Value(accountKey),
      status: Value(status),
      lastAttemptAt: lastAttemptAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastAttemptAt),
      lastSyncedAt: lastSyncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncedAt),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
    );
  }

  factory SyncState.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncState(
      accountKey: serializer.fromJson<String>(json['accountKey']),
      status: serializer.fromJson<String>(json['status']),
      lastAttemptAt: serializer.fromJson<DateTime?>(json['lastAttemptAt']),
      lastSyncedAt: serializer.fromJson<DateTime?>(json['lastSyncedAt']),
      lastError: serializer.fromJson<String?>(json['lastError']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'accountKey': serializer.toJson<String>(accountKey),
      'status': serializer.toJson<String>(status),
      'lastAttemptAt': serializer.toJson<DateTime?>(lastAttemptAt),
      'lastSyncedAt': serializer.toJson<DateTime?>(lastSyncedAt),
      'lastError': serializer.toJson<String?>(lastError),
    };
  }

  SyncState copyWith({
    String? accountKey,
    String? status,
    Value<DateTime?> lastAttemptAt = const Value.absent(),
    Value<DateTime?> lastSyncedAt = const Value.absent(),
    Value<String?> lastError = const Value.absent(),
  }) => SyncState(
    accountKey: accountKey ?? this.accountKey,
    status: status ?? this.status,
    lastAttemptAt: lastAttemptAt.present
        ? lastAttemptAt.value
        : this.lastAttemptAt,
    lastSyncedAt: lastSyncedAt.present ? lastSyncedAt.value : this.lastSyncedAt,
    lastError: lastError.present ? lastError.value : this.lastError,
  );
  SyncState copyWithCompanion(SyncStatesCompanion data) {
    return SyncState(
      accountKey: data.accountKey.present
          ? data.accountKey.value
          : this.accountKey,
      status: data.status.present ? data.status.value : this.status,
      lastAttemptAt: data.lastAttemptAt.present
          ? data.lastAttemptAt.value
          : this.lastAttemptAt,
      lastSyncedAt: data.lastSyncedAt.present
          ? data.lastSyncedAt.value
          : this.lastSyncedAt,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncState(')
          ..write('accountKey: $accountKey, ')
          ..write('status: $status, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(accountKey, status, lastAttemptAt, lastSyncedAt, lastError);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncState &&
          other.accountKey == this.accountKey &&
          other.status == this.status &&
          other.lastAttemptAt == this.lastAttemptAt &&
          other.lastSyncedAt == this.lastSyncedAt &&
          other.lastError == this.lastError);
}

class SyncStatesCompanion extends UpdateCompanion<SyncState> {
  final Value<String> accountKey;
  final Value<String> status;
  final Value<DateTime?> lastAttemptAt;
  final Value<DateTime?> lastSyncedAt;
  final Value<String?> lastError;
  final Value<int> rowid;
  const SyncStatesCompanion({
    this.accountKey = const Value.absent(),
    this.status = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncStatesCompanion.insert({
    required String accountKey,
    this.status = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : accountKey = Value(accountKey);
  static Insertable<SyncState> custom({
    Expression<String>? accountKey,
    Expression<String>? status,
    Expression<DateTime>? lastAttemptAt,
    Expression<DateTime>? lastSyncedAt,
    Expression<String>? lastError,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (accountKey != null) 'account_key': accountKey,
      if (status != null) 'status': status,
      if (lastAttemptAt != null) 'last_attempt_at': lastAttemptAt,
      if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
      if (lastError != null) 'last_error': lastError,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncStatesCompanion copyWith({
    Value<String>? accountKey,
    Value<String>? status,
    Value<DateTime?>? lastAttemptAt,
    Value<DateTime?>? lastSyncedAt,
    Value<String?>? lastError,
    Value<int>? rowid,
  }) {
    return SyncStatesCompanion(
      accountKey: accountKey ?? this.accountKey,
      status: status ?? this.status,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      lastError: lastError ?? this.lastError,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (accountKey.present) {
      map['account_key'] = Variable<String>(accountKey.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (lastAttemptAt.present) {
      map['last_attempt_at'] = Variable<DateTime>(lastAttemptAt.value);
    }
    if (lastSyncedAt.present) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncStatesCompanion(')
          ..write('accountKey: $accountKey, ')
          ..write('status: $status, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('lastError: $lastError, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncReferencesTable extends SyncReferences
    with TableInfo<$SyncReferencesTable, SyncReference> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncReferencesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _placeholderMeta = const VerificationMeta(
    'placeholder',
  );
  @override
  late final GeneratedColumn<String> placeholder = GeneratedColumn<String>(
    'placeholder',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accountKeyMeta = const VerificationMeta(
    'accountKey',
  );
  @override
  late final GeneratedColumn<String> accountKey = GeneratedColumn<String>(
    'account_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _referenceTypeMeta = const VerificationMeta(
    'referenceType',
  );
  @override
  late final GeneratedColumn<String> referenceType = GeneratedColumn<String>(
    'reference_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _remoteIdMeta = const VerificationMeta(
    'remoteId',
  );
  @override
  late final GeneratedColumn<String> remoteId = GeneratedColumn<String>(
    'remote_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    placeholder,
    accountKey,
    referenceType,
    remoteId,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_references';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncReference> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('placeholder')) {
      context.handle(
        _placeholderMeta,
        placeholder.isAcceptableOrUnknown(
          data['placeholder']!,
          _placeholderMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_placeholderMeta);
    }
    if (data.containsKey('account_key')) {
      context.handle(
        _accountKeyMeta,
        accountKey.isAcceptableOrUnknown(data['account_key']!, _accountKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_accountKeyMeta);
    }
    if (data.containsKey('reference_type')) {
      context.handle(
        _referenceTypeMeta,
        referenceType.isAcceptableOrUnknown(
          data['reference_type']!,
          _referenceTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_referenceTypeMeta);
    }
    if (data.containsKey('remote_id')) {
      context.handle(
        _remoteIdMeta,
        remoteId.isAcceptableOrUnknown(data['remote_id']!, _remoteIdMeta),
      );
    } else if (isInserting) {
      context.missing(_remoteIdMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {accountKey, placeholder};
  @override
  SyncReference map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncReference(
      placeholder: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}placeholder'],
      )!,
      accountKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_key'],
      )!,
      referenceType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reference_type'],
      )!,
      remoteId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $SyncReferencesTable createAlias(String alias) {
    return $SyncReferencesTable(attachedDatabase, alias);
  }
}

class SyncReference extends DataClass implements Insertable<SyncReference> {
  final String placeholder;
  final String accountKey;
  final String referenceType;
  final String remoteId;
  final DateTime createdAt;
  const SyncReference({
    required this.placeholder,
    required this.accountKey,
    required this.referenceType,
    required this.remoteId,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['placeholder'] = Variable<String>(placeholder);
    map['account_key'] = Variable<String>(accountKey);
    map['reference_type'] = Variable<String>(referenceType);
    map['remote_id'] = Variable<String>(remoteId);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  SyncReferencesCompanion toCompanion(bool nullToAbsent) {
    return SyncReferencesCompanion(
      placeholder: Value(placeholder),
      accountKey: Value(accountKey),
      referenceType: Value(referenceType),
      remoteId: Value(remoteId),
      createdAt: Value(createdAt),
    );
  }

  factory SyncReference.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncReference(
      placeholder: serializer.fromJson<String>(json['placeholder']),
      accountKey: serializer.fromJson<String>(json['accountKey']),
      referenceType: serializer.fromJson<String>(json['referenceType']),
      remoteId: serializer.fromJson<String>(json['remoteId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'placeholder': serializer.toJson<String>(placeholder),
      'accountKey': serializer.toJson<String>(accountKey),
      'referenceType': serializer.toJson<String>(referenceType),
      'remoteId': serializer.toJson<String>(remoteId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  SyncReference copyWith({
    String? placeholder,
    String? accountKey,
    String? referenceType,
    String? remoteId,
    DateTime? createdAt,
  }) => SyncReference(
    placeholder: placeholder ?? this.placeholder,
    accountKey: accountKey ?? this.accountKey,
    referenceType: referenceType ?? this.referenceType,
    remoteId: remoteId ?? this.remoteId,
    createdAt: createdAt ?? this.createdAt,
  );
  SyncReference copyWithCompanion(SyncReferencesCompanion data) {
    return SyncReference(
      placeholder: data.placeholder.present
          ? data.placeholder.value
          : this.placeholder,
      accountKey: data.accountKey.present
          ? data.accountKey.value
          : this.accountKey,
      referenceType: data.referenceType.present
          ? data.referenceType.value
          : this.referenceType,
      remoteId: data.remoteId.present ? data.remoteId.value : this.remoteId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncReference(')
          ..write('placeholder: $placeholder, ')
          ..write('accountKey: $accountKey, ')
          ..write('referenceType: $referenceType, ')
          ..write('remoteId: $remoteId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(placeholder, accountKey, referenceType, remoteId, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncReference &&
          other.placeholder == this.placeholder &&
          other.accountKey == this.accountKey &&
          other.referenceType == this.referenceType &&
          other.remoteId == this.remoteId &&
          other.createdAt == this.createdAt);
}

class SyncReferencesCompanion extends UpdateCompanion<SyncReference> {
  final Value<String> placeholder;
  final Value<String> accountKey;
  final Value<String> referenceType;
  final Value<String> remoteId;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const SyncReferencesCompanion({
    this.placeholder = const Value.absent(),
    this.accountKey = const Value.absent(),
    this.referenceType = const Value.absent(),
    this.remoteId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncReferencesCompanion.insert({
    required String placeholder,
    required String accountKey,
    required String referenceType,
    required String remoteId,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : placeholder = Value(placeholder),
       accountKey = Value(accountKey),
       referenceType = Value(referenceType),
       remoteId = Value(remoteId),
       createdAt = Value(createdAt);
  static Insertable<SyncReference> custom({
    Expression<String>? placeholder,
    Expression<String>? accountKey,
    Expression<String>? referenceType,
    Expression<String>? remoteId,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (placeholder != null) 'placeholder': placeholder,
      if (accountKey != null) 'account_key': accountKey,
      if (referenceType != null) 'reference_type': referenceType,
      if (remoteId != null) 'remote_id': remoteId,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncReferencesCompanion copyWith({
    Value<String>? placeholder,
    Value<String>? accountKey,
    Value<String>? referenceType,
    Value<String>? remoteId,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return SyncReferencesCompanion(
      placeholder: placeholder ?? this.placeholder,
      accountKey: accountKey ?? this.accountKey,
      referenceType: referenceType ?? this.referenceType,
      remoteId: remoteId ?? this.remoteId,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (placeholder.present) {
      map['placeholder'] = Variable<String>(placeholder.value);
    }
    if (accountKey.present) {
      map['account_key'] = Variable<String>(accountKey.value);
    }
    if (referenceType.present) {
      map['reference_type'] = Variable<String>(referenceType.value);
    }
    if (remoteId.present) {
      map['remote_id'] = Variable<String>(remoteId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncReferencesCompanion(')
          ..write('placeholder: $placeholder, ')
          ..write('accountKey: $accountKey, ')
          ..write('referenceType: $referenceType, ')
          ..write('remoteId: $remoteId, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalFileUploadsTable extends LocalFileUploads
    with TableInfo<$LocalFileUploadsTable, LocalFileUpload> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalFileUploadsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _localIdMeta = const VerificationMeta(
    'localId',
  );
  @override
  late final GeneratedColumn<String> localId = GeneratedColumn<String>(
    'local_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accountKeyMeta = const VerificationMeta(
    'accountKey',
  );
  @override
  late final GeneratedColumn<String> accountKey = GeneratedColumn<String>(
    'account_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _methodMeta = const VerificationMeta('method');
  @override
  late final GeneratedColumn<String> method = GeneratedColumn<String>(
    'method',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('POST'),
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fieldsJsonMeta = const VerificationMeta(
    'fieldsJson',
  );
  @override
  late final GeneratedColumn<String> fieldsJson = GeneratedColumn<String>(
    'fields_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _fieldNameMeta = const VerificationMeta(
    'fieldName',
  );
  @override
  late final GeneratedColumn<String> fieldName = GeneratedColumn<String>(
    'field_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fileNameMeta = const VerificationMeta(
    'fileName',
  );
  @override
  late final GeneratedColumn<String> fileName = GeneratedColumn<String>(
    'file_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mimeTypeMeta = const VerificationMeta(
    'mimeType',
  );
  @override
  late final GeneratedColumn<String> mimeType = GeneratedColumn<String>(
    'mime_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _filePathMeta = const VerificationMeta(
    'filePath',
  );
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
    'file_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fileBytesMeta = const VerificationMeta(
    'fileBytes',
  );
  @override
  late final GeneratedColumn<Uint8List> fileBytes = GeneratedColumn<Uint8List>(
    'file_bytes',
    aliasedName,
    true,
    type: DriftSqlType.blob,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _placeholderMeta = const VerificationMeta(
    'placeholder',
  );
  @override
  late final GeneratedColumn<String> placeholder = GeneratedColumn<String>(
    'placeholder',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idempotencyKeyMeta = const VerificationMeta(
    'idempotencyKey',
  );
  @override
  late final GeneratedColumn<String> idempotencyKey = GeneratedColumn<String>(
    'idempotency_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _retryCountMeta = const VerificationMeta(
    'retryCount',
  );
  @override
  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
    'retry_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nextAttemptAtMeta = const VerificationMeta(
    'nextAttemptAt',
  );
  @override
  late final GeneratedColumn<DateTime> nextAttemptAt =
      GeneratedColumn<DateTime>(
        'next_attempt_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _remoteUrlMeta = const VerificationMeta(
    'remoteUrl',
  );
  @override
  late final GeneratedColumn<String> remoteUrl = GeneratedColumn<String>(
    'remote_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    localId,
    accountKey,
    method,
    path,
    fieldsJson,
    fieldName,
    fileName,
    mimeType,
    filePath,
    fileBytes,
    placeholder,
    idempotencyKey,
    createdAt,
    retryCount,
    status,
    lastError,
    nextAttemptAt,
    remoteUrl,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_file_uploads';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalFileUpload> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('local_id')) {
      context.handle(
        _localIdMeta,
        localId.isAcceptableOrUnknown(data['local_id']!, _localIdMeta),
      );
    } else if (isInserting) {
      context.missing(_localIdMeta);
    }
    if (data.containsKey('account_key')) {
      context.handle(
        _accountKeyMeta,
        accountKey.isAcceptableOrUnknown(data['account_key']!, _accountKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_accountKeyMeta);
    }
    if (data.containsKey('method')) {
      context.handle(
        _methodMeta,
        method.isAcceptableOrUnknown(data['method']!, _methodMeta),
      );
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('fields_json')) {
      context.handle(
        _fieldsJsonMeta,
        fieldsJson.isAcceptableOrUnknown(data['fields_json']!, _fieldsJsonMeta),
      );
    }
    if (data.containsKey('field_name')) {
      context.handle(
        _fieldNameMeta,
        fieldName.isAcceptableOrUnknown(data['field_name']!, _fieldNameMeta),
      );
    } else if (isInserting) {
      context.missing(_fieldNameMeta);
    }
    if (data.containsKey('file_name')) {
      context.handle(
        _fileNameMeta,
        fileName.isAcceptableOrUnknown(data['file_name']!, _fileNameMeta),
      );
    } else if (isInserting) {
      context.missing(_fileNameMeta);
    }
    if (data.containsKey('mime_type')) {
      context.handle(
        _mimeTypeMeta,
        mimeType.isAcceptableOrUnknown(data['mime_type']!, _mimeTypeMeta),
      );
    }
    if (data.containsKey('file_path')) {
      context.handle(
        _filePathMeta,
        filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta),
      );
    }
    if (data.containsKey('file_bytes')) {
      context.handle(
        _fileBytesMeta,
        fileBytes.isAcceptableOrUnknown(data['file_bytes']!, _fileBytesMeta),
      );
    }
    if (data.containsKey('placeholder')) {
      context.handle(
        _placeholderMeta,
        placeholder.isAcceptableOrUnknown(
          data['placeholder']!,
          _placeholderMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_placeholderMeta);
    }
    if (data.containsKey('idempotency_key')) {
      context.handle(
        _idempotencyKeyMeta,
        idempotencyKey.isAcceptableOrUnknown(
          data['idempotency_key']!,
          _idempotencyKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_idempotencyKeyMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('retry_count')) {
      context.handle(
        _retryCountMeta,
        retryCount.isAcceptableOrUnknown(data['retry_count']!, _retryCountMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('next_attempt_at')) {
      context.handle(
        _nextAttemptAtMeta,
        nextAttemptAt.isAcceptableOrUnknown(
          data['next_attempt_at']!,
          _nextAttemptAtMeta,
        ),
      );
    }
    if (data.containsKey('remote_url')) {
      context.handle(
        _remoteUrlMeta,
        remoteUrl.isAcceptableOrUnknown(data['remote_url']!, _remoteUrlMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {localId, accountKey};
  @override
  LocalFileUpload map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalFileUpload(
      localId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_id'],
      )!,
      accountKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_key'],
      )!,
      method: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}method'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      fieldsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fields_json'],
      )!,
      fieldName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}field_name'],
      )!,
      fileName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_name'],
      )!,
      mimeType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mime_type'],
      ),
      filePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_path'],
      ),
      fileBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}file_bytes'],
      ),
      placeholder: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}placeholder'],
      )!,
      idempotencyKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}idempotency_key'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      retryCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}retry_count'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      nextAttemptAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_attempt_at'],
      ),
      remoteUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_url'],
      ),
    );
  }

  @override
  $LocalFileUploadsTable createAlias(String alias) {
    return $LocalFileUploadsTable(attachedDatabase, alias);
  }
}

class LocalFileUpload extends DataClass implements Insertable<LocalFileUpload> {
  final String localId;
  final String accountKey;
  final String method;
  final String path;
  final String fieldsJson;
  final String fieldName;
  final String fileName;
  final String? mimeType;
  final String? filePath;
  final Uint8List? fileBytes;
  final String placeholder;
  final String idempotencyKey;
  final DateTime createdAt;
  final int retryCount;
  final String status;
  final String? lastError;
  final DateTime? nextAttemptAt;
  final String? remoteUrl;
  const LocalFileUpload({
    required this.localId,
    required this.accountKey,
    required this.method,
    required this.path,
    required this.fieldsJson,
    required this.fieldName,
    required this.fileName,
    this.mimeType,
    this.filePath,
    this.fileBytes,
    required this.placeholder,
    required this.idempotencyKey,
    required this.createdAt,
    required this.retryCount,
    required this.status,
    this.lastError,
    this.nextAttemptAt,
    this.remoteUrl,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['local_id'] = Variable<String>(localId);
    map['account_key'] = Variable<String>(accountKey);
    map['method'] = Variable<String>(method);
    map['path'] = Variable<String>(path);
    map['fields_json'] = Variable<String>(fieldsJson);
    map['field_name'] = Variable<String>(fieldName);
    map['file_name'] = Variable<String>(fileName);
    if (!nullToAbsent || mimeType != null) {
      map['mime_type'] = Variable<String>(mimeType);
    }
    if (!nullToAbsent || filePath != null) {
      map['file_path'] = Variable<String>(filePath);
    }
    if (!nullToAbsent || fileBytes != null) {
      map['file_bytes'] = Variable<Uint8List>(fileBytes);
    }
    map['placeholder'] = Variable<String>(placeholder);
    map['idempotency_key'] = Variable<String>(idempotencyKey);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['retry_count'] = Variable<int>(retryCount);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    if (!nullToAbsent || nextAttemptAt != null) {
      map['next_attempt_at'] = Variable<DateTime>(nextAttemptAt);
    }
    if (!nullToAbsent || remoteUrl != null) {
      map['remote_url'] = Variable<String>(remoteUrl);
    }
    return map;
  }

  LocalFileUploadsCompanion toCompanion(bool nullToAbsent) {
    return LocalFileUploadsCompanion(
      localId: Value(localId),
      accountKey: Value(accountKey),
      method: Value(method),
      path: Value(path),
      fieldsJson: Value(fieldsJson),
      fieldName: Value(fieldName),
      fileName: Value(fileName),
      mimeType: mimeType == null && nullToAbsent
          ? const Value.absent()
          : Value(mimeType),
      filePath: filePath == null && nullToAbsent
          ? const Value.absent()
          : Value(filePath),
      fileBytes: fileBytes == null && nullToAbsent
          ? const Value.absent()
          : Value(fileBytes),
      placeholder: Value(placeholder),
      idempotencyKey: Value(idempotencyKey),
      createdAt: Value(createdAt),
      retryCount: Value(retryCount),
      status: Value(status),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      nextAttemptAt: nextAttemptAt == null && nullToAbsent
          ? const Value.absent()
          : Value(nextAttemptAt),
      remoteUrl: remoteUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteUrl),
    );
  }

  factory LocalFileUpload.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalFileUpload(
      localId: serializer.fromJson<String>(json['localId']),
      accountKey: serializer.fromJson<String>(json['accountKey']),
      method: serializer.fromJson<String>(json['method']),
      path: serializer.fromJson<String>(json['path']),
      fieldsJson: serializer.fromJson<String>(json['fieldsJson']),
      fieldName: serializer.fromJson<String>(json['fieldName']),
      fileName: serializer.fromJson<String>(json['fileName']),
      mimeType: serializer.fromJson<String?>(json['mimeType']),
      filePath: serializer.fromJson<String?>(json['filePath']),
      fileBytes: serializer.fromJson<Uint8List?>(json['fileBytes']),
      placeholder: serializer.fromJson<String>(json['placeholder']),
      idempotencyKey: serializer.fromJson<String>(json['idempotencyKey']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
      status: serializer.fromJson<String>(json['status']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      nextAttemptAt: serializer.fromJson<DateTime?>(json['nextAttemptAt']),
      remoteUrl: serializer.fromJson<String?>(json['remoteUrl']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'localId': serializer.toJson<String>(localId),
      'accountKey': serializer.toJson<String>(accountKey),
      'method': serializer.toJson<String>(method),
      'path': serializer.toJson<String>(path),
      'fieldsJson': serializer.toJson<String>(fieldsJson),
      'fieldName': serializer.toJson<String>(fieldName),
      'fileName': serializer.toJson<String>(fileName),
      'mimeType': serializer.toJson<String?>(mimeType),
      'filePath': serializer.toJson<String?>(filePath),
      'fileBytes': serializer.toJson<Uint8List?>(fileBytes),
      'placeholder': serializer.toJson<String>(placeholder),
      'idempotencyKey': serializer.toJson<String>(idempotencyKey),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'retryCount': serializer.toJson<int>(retryCount),
      'status': serializer.toJson<String>(status),
      'lastError': serializer.toJson<String?>(lastError),
      'nextAttemptAt': serializer.toJson<DateTime?>(nextAttemptAt),
      'remoteUrl': serializer.toJson<String?>(remoteUrl),
    };
  }

  LocalFileUpload copyWith({
    String? localId,
    String? accountKey,
    String? method,
    String? path,
    String? fieldsJson,
    String? fieldName,
    String? fileName,
    Value<String?> mimeType = const Value.absent(),
    Value<String?> filePath = const Value.absent(),
    Value<Uint8List?> fileBytes = const Value.absent(),
    String? placeholder,
    String? idempotencyKey,
    DateTime? createdAt,
    int? retryCount,
    String? status,
    Value<String?> lastError = const Value.absent(),
    Value<DateTime?> nextAttemptAt = const Value.absent(),
    Value<String?> remoteUrl = const Value.absent(),
  }) => LocalFileUpload(
    localId: localId ?? this.localId,
    accountKey: accountKey ?? this.accountKey,
    method: method ?? this.method,
    path: path ?? this.path,
    fieldsJson: fieldsJson ?? this.fieldsJson,
    fieldName: fieldName ?? this.fieldName,
    fileName: fileName ?? this.fileName,
    mimeType: mimeType.present ? mimeType.value : this.mimeType,
    filePath: filePath.present ? filePath.value : this.filePath,
    fileBytes: fileBytes.present ? fileBytes.value : this.fileBytes,
    placeholder: placeholder ?? this.placeholder,
    idempotencyKey: idempotencyKey ?? this.idempotencyKey,
    createdAt: createdAt ?? this.createdAt,
    retryCount: retryCount ?? this.retryCount,
    status: status ?? this.status,
    lastError: lastError.present ? lastError.value : this.lastError,
    nextAttemptAt: nextAttemptAt.present
        ? nextAttemptAt.value
        : this.nextAttemptAt,
    remoteUrl: remoteUrl.present ? remoteUrl.value : this.remoteUrl,
  );
  LocalFileUpload copyWithCompanion(LocalFileUploadsCompanion data) {
    return LocalFileUpload(
      localId: data.localId.present ? data.localId.value : this.localId,
      accountKey: data.accountKey.present
          ? data.accountKey.value
          : this.accountKey,
      method: data.method.present ? data.method.value : this.method,
      path: data.path.present ? data.path.value : this.path,
      fieldsJson: data.fieldsJson.present
          ? data.fieldsJson.value
          : this.fieldsJson,
      fieldName: data.fieldName.present ? data.fieldName.value : this.fieldName,
      fileName: data.fileName.present ? data.fileName.value : this.fileName,
      mimeType: data.mimeType.present ? data.mimeType.value : this.mimeType,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      fileBytes: data.fileBytes.present ? data.fileBytes.value : this.fileBytes,
      placeholder: data.placeholder.present
          ? data.placeholder.value
          : this.placeholder,
      idempotencyKey: data.idempotencyKey.present
          ? data.idempotencyKey.value
          : this.idempotencyKey,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      retryCount: data.retryCount.present
          ? data.retryCount.value
          : this.retryCount,
      status: data.status.present ? data.status.value : this.status,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      nextAttemptAt: data.nextAttemptAt.present
          ? data.nextAttemptAt.value
          : this.nextAttemptAt,
      remoteUrl: data.remoteUrl.present ? data.remoteUrl.value : this.remoteUrl,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalFileUpload(')
          ..write('localId: $localId, ')
          ..write('accountKey: $accountKey, ')
          ..write('method: $method, ')
          ..write('path: $path, ')
          ..write('fieldsJson: $fieldsJson, ')
          ..write('fieldName: $fieldName, ')
          ..write('fileName: $fileName, ')
          ..write('mimeType: $mimeType, ')
          ..write('filePath: $filePath, ')
          ..write('fileBytes: $fileBytes, ')
          ..write('placeholder: $placeholder, ')
          ..write('idempotencyKey: $idempotencyKey, ')
          ..write('createdAt: $createdAt, ')
          ..write('retryCount: $retryCount, ')
          ..write('status: $status, ')
          ..write('lastError: $lastError, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('remoteUrl: $remoteUrl')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    localId,
    accountKey,
    method,
    path,
    fieldsJson,
    fieldName,
    fileName,
    mimeType,
    filePath,
    $driftBlobEquality.hash(fileBytes),
    placeholder,
    idempotencyKey,
    createdAt,
    retryCount,
    status,
    lastError,
    nextAttemptAt,
    remoteUrl,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalFileUpload &&
          other.localId == this.localId &&
          other.accountKey == this.accountKey &&
          other.method == this.method &&
          other.path == this.path &&
          other.fieldsJson == this.fieldsJson &&
          other.fieldName == this.fieldName &&
          other.fileName == this.fileName &&
          other.mimeType == this.mimeType &&
          other.filePath == this.filePath &&
          $driftBlobEquality.equals(other.fileBytes, this.fileBytes) &&
          other.placeholder == this.placeholder &&
          other.idempotencyKey == this.idempotencyKey &&
          other.createdAt == this.createdAt &&
          other.retryCount == this.retryCount &&
          other.status == this.status &&
          other.lastError == this.lastError &&
          other.nextAttemptAt == this.nextAttemptAt &&
          other.remoteUrl == this.remoteUrl);
}

class LocalFileUploadsCompanion extends UpdateCompanion<LocalFileUpload> {
  final Value<String> localId;
  final Value<String> accountKey;
  final Value<String> method;
  final Value<String> path;
  final Value<String> fieldsJson;
  final Value<String> fieldName;
  final Value<String> fileName;
  final Value<String?> mimeType;
  final Value<String?> filePath;
  final Value<Uint8List?> fileBytes;
  final Value<String> placeholder;
  final Value<String> idempotencyKey;
  final Value<DateTime> createdAt;
  final Value<int> retryCount;
  final Value<String> status;
  final Value<String?> lastError;
  final Value<DateTime?> nextAttemptAt;
  final Value<String?> remoteUrl;
  final Value<int> rowid;
  const LocalFileUploadsCompanion({
    this.localId = const Value.absent(),
    this.accountKey = const Value.absent(),
    this.method = const Value.absent(),
    this.path = const Value.absent(),
    this.fieldsJson = const Value.absent(),
    this.fieldName = const Value.absent(),
    this.fileName = const Value.absent(),
    this.mimeType = const Value.absent(),
    this.filePath = const Value.absent(),
    this.fileBytes = const Value.absent(),
    this.placeholder = const Value.absent(),
    this.idempotencyKey = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.status = const Value.absent(),
    this.lastError = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
    this.remoteUrl = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalFileUploadsCompanion.insert({
    required String localId,
    required String accountKey,
    this.method = const Value.absent(),
    required String path,
    this.fieldsJson = const Value.absent(),
    required String fieldName,
    required String fileName,
    this.mimeType = const Value.absent(),
    this.filePath = const Value.absent(),
    this.fileBytes = const Value.absent(),
    required String placeholder,
    required String idempotencyKey,
    required DateTime createdAt,
    this.retryCount = const Value.absent(),
    this.status = const Value.absent(),
    this.lastError = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
    this.remoteUrl = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : localId = Value(localId),
       accountKey = Value(accountKey),
       path = Value(path),
       fieldName = Value(fieldName),
       fileName = Value(fileName),
       placeholder = Value(placeholder),
       idempotencyKey = Value(idempotencyKey),
       createdAt = Value(createdAt);
  static Insertable<LocalFileUpload> custom({
    Expression<String>? localId,
    Expression<String>? accountKey,
    Expression<String>? method,
    Expression<String>? path,
    Expression<String>? fieldsJson,
    Expression<String>? fieldName,
    Expression<String>? fileName,
    Expression<String>? mimeType,
    Expression<String>? filePath,
    Expression<Uint8List>? fileBytes,
    Expression<String>? placeholder,
    Expression<String>? idempotencyKey,
    Expression<DateTime>? createdAt,
    Expression<int>? retryCount,
    Expression<String>? status,
    Expression<String>? lastError,
    Expression<DateTime>? nextAttemptAt,
    Expression<String>? remoteUrl,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (localId != null) 'local_id': localId,
      if (accountKey != null) 'account_key': accountKey,
      if (method != null) 'method': method,
      if (path != null) 'path': path,
      if (fieldsJson != null) 'fields_json': fieldsJson,
      if (fieldName != null) 'field_name': fieldName,
      if (fileName != null) 'file_name': fileName,
      if (mimeType != null) 'mime_type': mimeType,
      if (filePath != null) 'file_path': filePath,
      if (fileBytes != null) 'file_bytes': fileBytes,
      if (placeholder != null) 'placeholder': placeholder,
      if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
      if (createdAt != null) 'created_at': createdAt,
      if (retryCount != null) 'retry_count': retryCount,
      if (status != null) 'status': status,
      if (lastError != null) 'last_error': lastError,
      if (nextAttemptAt != null) 'next_attempt_at': nextAttemptAt,
      if (remoteUrl != null) 'remote_url': remoteUrl,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalFileUploadsCompanion copyWith({
    Value<String>? localId,
    Value<String>? accountKey,
    Value<String>? method,
    Value<String>? path,
    Value<String>? fieldsJson,
    Value<String>? fieldName,
    Value<String>? fileName,
    Value<String?>? mimeType,
    Value<String?>? filePath,
    Value<Uint8List?>? fileBytes,
    Value<String>? placeholder,
    Value<String>? idempotencyKey,
    Value<DateTime>? createdAt,
    Value<int>? retryCount,
    Value<String>? status,
    Value<String?>? lastError,
    Value<DateTime?>? nextAttemptAt,
    Value<String?>? remoteUrl,
    Value<int>? rowid,
  }) {
    return LocalFileUploadsCompanion(
      localId: localId ?? this.localId,
      accountKey: accountKey ?? this.accountKey,
      method: method ?? this.method,
      path: path ?? this.path,
      fieldsJson: fieldsJson ?? this.fieldsJson,
      fieldName: fieldName ?? this.fieldName,
      fileName: fileName ?? this.fileName,
      mimeType: mimeType ?? this.mimeType,
      filePath: filePath ?? this.filePath,
      fileBytes: fileBytes ?? this.fileBytes,
      placeholder: placeholder ?? this.placeholder,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      createdAt: createdAt ?? this.createdAt,
      retryCount: retryCount ?? this.retryCount,
      status: status ?? this.status,
      lastError: lastError ?? this.lastError,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
      remoteUrl: remoteUrl ?? this.remoteUrl,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (localId.present) {
      map['local_id'] = Variable<String>(localId.value);
    }
    if (accountKey.present) {
      map['account_key'] = Variable<String>(accountKey.value);
    }
    if (method.present) {
      map['method'] = Variable<String>(method.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (fieldsJson.present) {
      map['fields_json'] = Variable<String>(fieldsJson.value);
    }
    if (fieldName.present) {
      map['field_name'] = Variable<String>(fieldName.value);
    }
    if (fileName.present) {
      map['file_name'] = Variable<String>(fileName.value);
    }
    if (mimeType.present) {
      map['mime_type'] = Variable<String>(mimeType.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (fileBytes.present) {
      map['file_bytes'] = Variable<Uint8List>(fileBytes.value);
    }
    if (placeholder.present) {
      map['placeholder'] = Variable<String>(placeholder.value);
    }
    if (idempotencyKey.present) {
      map['idempotency_key'] = Variable<String>(idempotencyKey.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (nextAttemptAt.present) {
      map['next_attempt_at'] = Variable<DateTime>(nextAttemptAt.value);
    }
    if (remoteUrl.present) {
      map['remote_url'] = Variable<String>(remoteUrl.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalFileUploadsCompanion(')
          ..write('localId: $localId, ')
          ..write('accountKey: $accountKey, ')
          ..write('method: $method, ')
          ..write('path: $path, ')
          ..write('fieldsJson: $fieldsJson, ')
          ..write('fieldName: $fieldName, ')
          ..write('fileName: $fileName, ')
          ..write('mimeType: $mimeType, ')
          ..write('filePath: $filePath, ')
          ..write('fileBytes: $fileBytes, ')
          ..write('placeholder: $placeholder, ')
          ..write('idempotencyKey: $idempotencyKey, ')
          ..write('createdAt: $createdAt, ')
          ..write('retryCount: $retryCount, ')
          ..write('status: $status, ')
          ..write('lastError: $lastError, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('remoteUrl: $remoteUrl, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalAttendanceRecordsTable extends LocalAttendanceRecords
    with TableInfo<$LocalAttendanceRecordsTable, LocalAttendanceRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalAttendanceRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _localIdMeta = const VerificationMeta(
    'localId',
  );
  @override
  late final GeneratedColumn<String> localId = GeneratedColumn<String>(
    'local_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accountKeyMeta = const VerificationMeta(
    'accountKey',
  );
  @override
  late final GeneratedColumn<String> accountKey = GeneratedColumn<String>(
    'account_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
    'server_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _schoolIdMeta = const VerificationMeta(
    'schoolId',
  );
  @override
  late final GeneratedColumn<String> schoolId = GeneratedColumn<String>(
    'school_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _studentIdMeta = const VerificationMeta(
    'studentId',
  );
  @override
  late final GeneratedColumn<String> studentId = GeneratedColumn<String>(
    'student_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _studentNameMeta = const VerificationMeta(
    'studentName',
  );
  @override
  late final GeneratedColumn<String> studentName = GeneratedColumn<String>(
    'student_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _classNameMeta = const VerificationMeta(
    'className',
  );
  @override
  late final GeneratedColumn<String> className = GeneratedColumn<String>(
    'class_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _sectionMeta = const VerificationMeta(
    'section',
  );
  @override
  late final GeneratedColumn<String> section = GeneratedColumn<String>(
    'section',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _attendanceStatusMeta = const VerificationMeta(
    'attendanceStatus',
  );
  @override
  late final GeneratedColumn<String> attendanceStatus = GeneratedColumn<String>(
    'attendance_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _remarksMeta = const VerificationMeta(
    'remarks',
  );
  @override
  late final GeneratedColumn<String> remarks = GeneratedColumn<String>(
    'remarks',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _markedByMeta = const VerificationMeta(
    'markedBy',
  );
  @override
  late final GeneratedColumn<String> markedBy = GeneratedColumn<String>(
    'marked_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _markedAtMeta = const VerificationMeta(
    'markedAt',
  );
  @override
  late final GeneratedColumn<DateTime> markedAt = GeneratedColumn<DateTime>(
    'marked_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _localUpdatedAtMeta = const VerificationMeta(
    'localUpdatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> localUpdatedAt =
      GeneratedColumn<DateTime>(
        'local_updated_at',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('synced'),
  );
  static const VerificationMeta _serverVersionMeta = const VerificationMeta(
    'serverVersion',
  );
  @override
  late final GeneratedColumn<int> serverVersion = GeneratedColumn<int>(
    'server_version',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rawJsonMeta = const VerificationMeta(
    'rawJson',
  );
  @override
  late final GeneratedColumn<String> rawJson = GeneratedColumn<String>(
    'raw_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    localId,
    accountKey,
    serverId,
    schoolId,
    studentId,
    studentName,
    className,
    section,
    date,
    attendanceStatus,
    remarks,
    markedBy,
    markedAt,
    updatedAt,
    localUpdatedAt,
    syncStatus,
    serverVersion,
    rawJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_attendance_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalAttendanceRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('local_id')) {
      context.handle(
        _localIdMeta,
        localId.isAcceptableOrUnknown(data['local_id']!, _localIdMeta),
      );
    } else if (isInserting) {
      context.missing(_localIdMeta);
    }
    if (data.containsKey('account_key')) {
      context.handle(
        _accountKeyMeta,
        accountKey.isAcceptableOrUnknown(data['account_key']!, _accountKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_accountKeyMeta);
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    }
    if (data.containsKey('school_id')) {
      context.handle(
        _schoolIdMeta,
        schoolId.isAcceptableOrUnknown(data['school_id']!, _schoolIdMeta),
      );
    }
    if (data.containsKey('student_id')) {
      context.handle(
        _studentIdMeta,
        studentId.isAcceptableOrUnknown(data['student_id']!, _studentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_studentIdMeta);
    }
    if (data.containsKey('student_name')) {
      context.handle(
        _studentNameMeta,
        studentName.isAcceptableOrUnknown(
          data['student_name']!,
          _studentNameMeta,
        ),
      );
    }
    if (data.containsKey('class_name')) {
      context.handle(
        _classNameMeta,
        className.isAcceptableOrUnknown(data['class_name']!, _classNameMeta),
      );
    }
    if (data.containsKey('section')) {
      context.handle(
        _sectionMeta,
        section.isAcceptableOrUnknown(data['section']!, _sectionMeta),
      );
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('attendance_status')) {
      context.handle(
        _attendanceStatusMeta,
        attendanceStatus.isAcceptableOrUnknown(
          data['attendance_status']!,
          _attendanceStatusMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_attendanceStatusMeta);
    }
    if (data.containsKey('remarks')) {
      context.handle(
        _remarksMeta,
        remarks.isAcceptableOrUnknown(data['remarks']!, _remarksMeta),
      );
    }
    if (data.containsKey('marked_by')) {
      context.handle(
        _markedByMeta,
        markedBy.isAcceptableOrUnknown(data['marked_by']!, _markedByMeta),
      );
    }
    if (data.containsKey('marked_at')) {
      context.handle(
        _markedAtMeta,
        markedAt.isAcceptableOrUnknown(data['marked_at']!, _markedAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('local_updated_at')) {
      context.handle(
        _localUpdatedAtMeta,
        localUpdatedAt.isAcceptableOrUnknown(
          data['local_updated_at']!,
          _localUpdatedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_localUpdatedAtMeta);
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    if (data.containsKey('server_version')) {
      context.handle(
        _serverVersionMeta,
        serverVersion.isAcceptableOrUnknown(
          data['server_version']!,
          _serverVersionMeta,
        ),
      );
    }
    if (data.containsKey('raw_json')) {
      context.handle(
        _rawJsonMeta,
        rawJson.isAcceptableOrUnknown(data['raw_json']!, _rawJsonMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {accountKey, localId};
  @override
  LocalAttendanceRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalAttendanceRecord(
      localId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_id'],
      )!,
      accountKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_key'],
      )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      ),
      schoolId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}school_id'],
      ),
      studentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}student_id'],
      )!,
      studentName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}student_name'],
      )!,
      className: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}class_name'],
      )!,
      section: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}section'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date'],
      )!,
      attendanceStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}attendance_status'],
      )!,
      remarks: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remarks'],
      )!,
      markedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}marked_by'],
      ),
      markedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}marked_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      ),
      localUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}local_updated_at'],
      )!,
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_status'],
      )!,
      serverVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_version'],
      ),
      rawJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}raw_json'],
      )!,
    );
  }

  @override
  $LocalAttendanceRecordsTable createAlias(String alias) {
    return $LocalAttendanceRecordsTable(attachedDatabase, alias);
  }
}

class LocalAttendanceRecord extends DataClass
    implements Insertable<LocalAttendanceRecord> {
  final String localId;
  final String accountKey;
  final String? serverId;
  final String? schoolId;
  final String studentId;
  final String studentName;
  final String className;
  final String section;
  final String date;
  final String attendanceStatus;
  final String remarks;
  final String? markedBy;
  final DateTime? markedAt;
  final DateTime? updatedAt;
  final DateTime localUpdatedAt;
  final String syncStatus;
  final int? serverVersion;
  final String rawJson;
  const LocalAttendanceRecord({
    required this.localId,
    required this.accountKey,
    this.serverId,
    this.schoolId,
    required this.studentId,
    required this.studentName,
    required this.className,
    required this.section,
    required this.date,
    required this.attendanceStatus,
    required this.remarks,
    this.markedBy,
    this.markedAt,
    this.updatedAt,
    required this.localUpdatedAt,
    required this.syncStatus,
    this.serverVersion,
    required this.rawJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['local_id'] = Variable<String>(localId);
    map['account_key'] = Variable<String>(accountKey);
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<String>(serverId);
    }
    if (!nullToAbsent || schoolId != null) {
      map['school_id'] = Variable<String>(schoolId);
    }
    map['student_id'] = Variable<String>(studentId);
    map['student_name'] = Variable<String>(studentName);
    map['class_name'] = Variable<String>(className);
    map['section'] = Variable<String>(section);
    map['date'] = Variable<String>(date);
    map['attendance_status'] = Variable<String>(attendanceStatus);
    map['remarks'] = Variable<String>(remarks);
    if (!nullToAbsent || markedBy != null) {
      map['marked_by'] = Variable<String>(markedBy);
    }
    if (!nullToAbsent || markedAt != null) {
      map['marked_at'] = Variable<DateTime>(markedAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    map['local_updated_at'] = Variable<DateTime>(localUpdatedAt);
    map['sync_status'] = Variable<String>(syncStatus);
    if (!nullToAbsent || serverVersion != null) {
      map['server_version'] = Variable<int>(serverVersion);
    }
    map['raw_json'] = Variable<String>(rawJson);
    return map;
  }

  LocalAttendanceRecordsCompanion toCompanion(bool nullToAbsent) {
    return LocalAttendanceRecordsCompanion(
      localId: Value(localId),
      accountKey: Value(accountKey),
      serverId: serverId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverId),
      schoolId: schoolId == null && nullToAbsent
          ? const Value.absent()
          : Value(schoolId),
      studentId: Value(studentId),
      studentName: Value(studentName),
      className: Value(className),
      section: Value(section),
      date: Value(date),
      attendanceStatus: Value(attendanceStatus),
      remarks: Value(remarks),
      markedBy: markedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(markedBy),
      markedAt: markedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(markedAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      localUpdatedAt: Value(localUpdatedAt),
      syncStatus: Value(syncStatus),
      serverVersion: serverVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(serverVersion),
      rawJson: Value(rawJson),
    );
  }

  factory LocalAttendanceRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalAttendanceRecord(
      localId: serializer.fromJson<String>(json['localId']),
      accountKey: serializer.fromJson<String>(json['accountKey']),
      serverId: serializer.fromJson<String?>(json['serverId']),
      schoolId: serializer.fromJson<String?>(json['schoolId']),
      studentId: serializer.fromJson<String>(json['studentId']),
      studentName: serializer.fromJson<String>(json['studentName']),
      className: serializer.fromJson<String>(json['className']),
      section: serializer.fromJson<String>(json['section']),
      date: serializer.fromJson<String>(json['date']),
      attendanceStatus: serializer.fromJson<String>(json['attendanceStatus']),
      remarks: serializer.fromJson<String>(json['remarks']),
      markedBy: serializer.fromJson<String?>(json['markedBy']),
      markedAt: serializer.fromJson<DateTime?>(json['markedAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
      localUpdatedAt: serializer.fromJson<DateTime>(json['localUpdatedAt']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
      serverVersion: serializer.fromJson<int?>(json['serverVersion']),
      rawJson: serializer.fromJson<String>(json['rawJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'localId': serializer.toJson<String>(localId),
      'accountKey': serializer.toJson<String>(accountKey),
      'serverId': serializer.toJson<String?>(serverId),
      'schoolId': serializer.toJson<String?>(schoolId),
      'studentId': serializer.toJson<String>(studentId),
      'studentName': serializer.toJson<String>(studentName),
      'className': serializer.toJson<String>(className),
      'section': serializer.toJson<String>(section),
      'date': serializer.toJson<String>(date),
      'attendanceStatus': serializer.toJson<String>(attendanceStatus),
      'remarks': serializer.toJson<String>(remarks),
      'markedBy': serializer.toJson<String?>(markedBy),
      'markedAt': serializer.toJson<DateTime?>(markedAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
      'localUpdatedAt': serializer.toJson<DateTime>(localUpdatedAt),
      'syncStatus': serializer.toJson<String>(syncStatus),
      'serverVersion': serializer.toJson<int?>(serverVersion),
      'rawJson': serializer.toJson<String>(rawJson),
    };
  }

  LocalAttendanceRecord copyWith({
    String? localId,
    String? accountKey,
    Value<String?> serverId = const Value.absent(),
    Value<String?> schoolId = const Value.absent(),
    String? studentId,
    String? studentName,
    String? className,
    String? section,
    String? date,
    String? attendanceStatus,
    String? remarks,
    Value<String?> markedBy = const Value.absent(),
    Value<DateTime?> markedAt = const Value.absent(),
    Value<DateTime?> updatedAt = const Value.absent(),
    DateTime? localUpdatedAt,
    String? syncStatus,
    Value<int?> serverVersion = const Value.absent(),
    String? rawJson,
  }) => LocalAttendanceRecord(
    localId: localId ?? this.localId,
    accountKey: accountKey ?? this.accountKey,
    serverId: serverId.present ? serverId.value : this.serverId,
    schoolId: schoolId.present ? schoolId.value : this.schoolId,
    studentId: studentId ?? this.studentId,
    studentName: studentName ?? this.studentName,
    className: className ?? this.className,
    section: section ?? this.section,
    date: date ?? this.date,
    attendanceStatus: attendanceStatus ?? this.attendanceStatus,
    remarks: remarks ?? this.remarks,
    markedBy: markedBy.present ? markedBy.value : this.markedBy,
    markedAt: markedAt.present ? markedAt.value : this.markedAt,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    localUpdatedAt: localUpdatedAt ?? this.localUpdatedAt,
    syncStatus: syncStatus ?? this.syncStatus,
    serverVersion: serverVersion.present
        ? serverVersion.value
        : this.serverVersion,
    rawJson: rawJson ?? this.rawJson,
  );
  LocalAttendanceRecord copyWithCompanion(
    LocalAttendanceRecordsCompanion data,
  ) {
    return LocalAttendanceRecord(
      localId: data.localId.present ? data.localId.value : this.localId,
      accountKey: data.accountKey.present
          ? data.accountKey.value
          : this.accountKey,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      schoolId: data.schoolId.present ? data.schoolId.value : this.schoolId,
      studentId: data.studentId.present ? data.studentId.value : this.studentId,
      studentName: data.studentName.present
          ? data.studentName.value
          : this.studentName,
      className: data.className.present ? data.className.value : this.className,
      section: data.section.present ? data.section.value : this.section,
      date: data.date.present ? data.date.value : this.date,
      attendanceStatus: data.attendanceStatus.present
          ? data.attendanceStatus.value
          : this.attendanceStatus,
      remarks: data.remarks.present ? data.remarks.value : this.remarks,
      markedBy: data.markedBy.present ? data.markedBy.value : this.markedBy,
      markedAt: data.markedAt.present ? data.markedAt.value : this.markedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      localUpdatedAt: data.localUpdatedAt.present
          ? data.localUpdatedAt.value
          : this.localUpdatedAt,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      serverVersion: data.serverVersion.present
          ? data.serverVersion.value
          : this.serverVersion,
      rawJson: data.rawJson.present ? data.rawJson.value : this.rawJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalAttendanceRecord(')
          ..write('localId: $localId, ')
          ..write('accountKey: $accountKey, ')
          ..write('serverId: $serverId, ')
          ..write('schoolId: $schoolId, ')
          ..write('studentId: $studentId, ')
          ..write('studentName: $studentName, ')
          ..write('className: $className, ')
          ..write('section: $section, ')
          ..write('date: $date, ')
          ..write('attendanceStatus: $attendanceStatus, ')
          ..write('remarks: $remarks, ')
          ..write('markedBy: $markedBy, ')
          ..write('markedAt: $markedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('localUpdatedAt: $localUpdatedAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('serverVersion: $serverVersion, ')
          ..write('rawJson: $rawJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    localId,
    accountKey,
    serverId,
    schoolId,
    studentId,
    studentName,
    className,
    section,
    date,
    attendanceStatus,
    remarks,
    markedBy,
    markedAt,
    updatedAt,
    localUpdatedAt,
    syncStatus,
    serverVersion,
    rawJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalAttendanceRecord &&
          other.localId == this.localId &&
          other.accountKey == this.accountKey &&
          other.serverId == this.serverId &&
          other.schoolId == this.schoolId &&
          other.studentId == this.studentId &&
          other.studentName == this.studentName &&
          other.className == this.className &&
          other.section == this.section &&
          other.date == this.date &&
          other.attendanceStatus == this.attendanceStatus &&
          other.remarks == this.remarks &&
          other.markedBy == this.markedBy &&
          other.markedAt == this.markedAt &&
          other.updatedAt == this.updatedAt &&
          other.localUpdatedAt == this.localUpdatedAt &&
          other.syncStatus == this.syncStatus &&
          other.serverVersion == this.serverVersion &&
          other.rawJson == this.rawJson);
}

class LocalAttendanceRecordsCompanion
    extends UpdateCompanion<LocalAttendanceRecord> {
  final Value<String> localId;
  final Value<String> accountKey;
  final Value<String?> serverId;
  final Value<String?> schoolId;
  final Value<String> studentId;
  final Value<String> studentName;
  final Value<String> className;
  final Value<String> section;
  final Value<String> date;
  final Value<String> attendanceStatus;
  final Value<String> remarks;
  final Value<String?> markedBy;
  final Value<DateTime?> markedAt;
  final Value<DateTime?> updatedAt;
  final Value<DateTime> localUpdatedAt;
  final Value<String> syncStatus;
  final Value<int?> serverVersion;
  final Value<String> rawJson;
  final Value<int> rowid;
  const LocalAttendanceRecordsCompanion({
    this.localId = const Value.absent(),
    this.accountKey = const Value.absent(),
    this.serverId = const Value.absent(),
    this.schoolId = const Value.absent(),
    this.studentId = const Value.absent(),
    this.studentName = const Value.absent(),
    this.className = const Value.absent(),
    this.section = const Value.absent(),
    this.date = const Value.absent(),
    this.attendanceStatus = const Value.absent(),
    this.remarks = const Value.absent(),
    this.markedBy = const Value.absent(),
    this.markedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.localUpdatedAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.serverVersion = const Value.absent(),
    this.rawJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalAttendanceRecordsCompanion.insert({
    required String localId,
    required String accountKey,
    this.serverId = const Value.absent(),
    this.schoolId = const Value.absent(),
    required String studentId,
    this.studentName = const Value.absent(),
    this.className = const Value.absent(),
    this.section = const Value.absent(),
    required String date,
    required String attendanceStatus,
    this.remarks = const Value.absent(),
    this.markedBy = const Value.absent(),
    this.markedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    required DateTime localUpdatedAt,
    this.syncStatus = const Value.absent(),
    this.serverVersion = const Value.absent(),
    this.rawJson = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : localId = Value(localId),
       accountKey = Value(accountKey),
       studentId = Value(studentId),
       date = Value(date),
       attendanceStatus = Value(attendanceStatus),
       localUpdatedAt = Value(localUpdatedAt);
  static Insertable<LocalAttendanceRecord> custom({
    Expression<String>? localId,
    Expression<String>? accountKey,
    Expression<String>? serverId,
    Expression<String>? schoolId,
    Expression<String>? studentId,
    Expression<String>? studentName,
    Expression<String>? className,
    Expression<String>? section,
    Expression<String>? date,
    Expression<String>? attendanceStatus,
    Expression<String>? remarks,
    Expression<String>? markedBy,
    Expression<DateTime>? markedAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? localUpdatedAt,
    Expression<String>? syncStatus,
    Expression<int>? serverVersion,
    Expression<String>? rawJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (localId != null) 'local_id': localId,
      if (accountKey != null) 'account_key': accountKey,
      if (serverId != null) 'server_id': serverId,
      if (schoolId != null) 'school_id': schoolId,
      if (studentId != null) 'student_id': studentId,
      if (studentName != null) 'student_name': studentName,
      if (className != null) 'class_name': className,
      if (section != null) 'section': section,
      if (date != null) 'date': date,
      if (attendanceStatus != null) 'attendance_status': attendanceStatus,
      if (remarks != null) 'remarks': remarks,
      if (markedBy != null) 'marked_by': markedBy,
      if (markedAt != null) 'marked_at': markedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (localUpdatedAt != null) 'local_updated_at': localUpdatedAt,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (serverVersion != null) 'server_version': serverVersion,
      if (rawJson != null) 'raw_json': rawJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalAttendanceRecordsCompanion copyWith({
    Value<String>? localId,
    Value<String>? accountKey,
    Value<String?>? serverId,
    Value<String?>? schoolId,
    Value<String>? studentId,
    Value<String>? studentName,
    Value<String>? className,
    Value<String>? section,
    Value<String>? date,
    Value<String>? attendanceStatus,
    Value<String>? remarks,
    Value<String?>? markedBy,
    Value<DateTime?>? markedAt,
    Value<DateTime?>? updatedAt,
    Value<DateTime>? localUpdatedAt,
    Value<String>? syncStatus,
    Value<int?>? serverVersion,
    Value<String>? rawJson,
    Value<int>? rowid,
  }) {
    return LocalAttendanceRecordsCompanion(
      localId: localId ?? this.localId,
      accountKey: accountKey ?? this.accountKey,
      serverId: serverId ?? this.serverId,
      schoolId: schoolId ?? this.schoolId,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      className: className ?? this.className,
      section: section ?? this.section,
      date: date ?? this.date,
      attendanceStatus: attendanceStatus ?? this.attendanceStatus,
      remarks: remarks ?? this.remarks,
      markedBy: markedBy ?? this.markedBy,
      markedAt: markedAt ?? this.markedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      localUpdatedAt: localUpdatedAt ?? this.localUpdatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      serverVersion: serverVersion ?? this.serverVersion,
      rawJson: rawJson ?? this.rawJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (localId.present) {
      map['local_id'] = Variable<String>(localId.value);
    }
    if (accountKey.present) {
      map['account_key'] = Variable<String>(accountKey.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (schoolId.present) {
      map['school_id'] = Variable<String>(schoolId.value);
    }
    if (studentId.present) {
      map['student_id'] = Variable<String>(studentId.value);
    }
    if (studentName.present) {
      map['student_name'] = Variable<String>(studentName.value);
    }
    if (className.present) {
      map['class_name'] = Variable<String>(className.value);
    }
    if (section.present) {
      map['section'] = Variable<String>(section.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (attendanceStatus.present) {
      map['attendance_status'] = Variable<String>(attendanceStatus.value);
    }
    if (remarks.present) {
      map['remarks'] = Variable<String>(remarks.value);
    }
    if (markedBy.present) {
      map['marked_by'] = Variable<String>(markedBy.value);
    }
    if (markedAt.present) {
      map['marked_at'] = Variable<DateTime>(markedAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (localUpdatedAt.present) {
      map['local_updated_at'] = Variable<DateTime>(localUpdatedAt.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (serverVersion.present) {
      map['server_version'] = Variable<int>(serverVersion.value);
    }
    if (rawJson.present) {
      map['raw_json'] = Variable<String>(rawJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalAttendanceRecordsCompanion(')
          ..write('localId: $localId, ')
          ..write('accountKey: $accountKey, ')
          ..write('serverId: $serverId, ')
          ..write('schoolId: $schoolId, ')
          ..write('studentId: $studentId, ')
          ..write('studentName: $studentName, ')
          ..write('className: $className, ')
          ..write('section: $section, ')
          ..write('date: $date, ')
          ..write('attendanceStatus: $attendanceStatus, ')
          ..write('remarks: $remarks, ')
          ..write('markedBy: $markedBy, ')
          ..write('markedAt: $markedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('localUpdatedAt: $localUpdatedAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('serverVersion: $serverVersion, ')
          ..write('rawJson: $rawJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalAttendanceSessionsTable extends LocalAttendanceSessions
    with TableInfo<$LocalAttendanceSessionsTable, LocalAttendanceSession> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalAttendanceSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _localIdMeta = const VerificationMeta(
    'localId',
  );
  @override
  late final GeneratedColumn<String> localId = GeneratedColumn<String>(
    'local_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accountKeyMeta = const VerificationMeta(
    'accountKey',
  );
  @override
  late final GeneratedColumn<String> accountKey = GeneratedColumn<String>(
    'account_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
    'server_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sectionIdMeta = const VerificationMeta(
    'sectionId',
  );
  @override
  late final GeneratedColumn<String> sectionId = GeneratedColumn<String>(
    'section_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _academicYearIdMeta = const VerificationMeta(
    'academicYearId',
  );
  @override
  late final GeneratedColumn<String> academicYearId = GeneratedColumn<String>(
    'academic_year_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subjectIdMeta = const VerificationMeta(
    'subjectId',
  );
  @override
  late final GeneratedColumn<String> subjectId = GeneratedColumn<String>(
    'subject_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _staffIdMeta = const VerificationMeta(
    'staffId',
  );
  @override
  late final GeneratedColumn<String> staffId = GeneratedColumn<String>(
    'staff_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _periodNumberMeta = const VerificationMeta(
    'periodNumber',
  );
  @override
  late final GeneratedColumn<int> periodNumber = GeneratedColumn<int>(
    'period_number',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _timetableSlotIdMeta = const VerificationMeta(
    'timetableSlotId',
  );
  @override
  late final GeneratedColumn<String> timetableSlotId = GeneratedColumn<String>(
    'timetable_slot_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('draft'),
  );
  static const VerificationMeta _isFinalizedMeta = const VerificationMeta(
    'isFinalized',
  );
  @override
  late final GeneratedColumn<bool> isFinalized = GeneratedColumn<bool>(
    'is_finalized',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_finalized" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _studentAttendancesJsonMeta =
      const VerificationMeta('studentAttendancesJson');
  @override
  late final GeneratedColumn<String> studentAttendancesJson =
      GeneratedColumn<String>(
        'student_attendances_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      );
  static const VerificationMeta _localUpdatedAtMeta = const VerificationMeta(
    'localUpdatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> localUpdatedAt =
      GeneratedColumn<DateTime>(
        'local_updated_at',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    localId,
    accountKey,
    serverId,
    sectionId,
    academicYearId,
    subjectId,
    staffId,
    date,
    periodNumber,
    timetableSlotId,
    status,
    isFinalized,
    studentAttendancesJson,
    localUpdatedAt,
    syncStatus,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_attendance_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalAttendanceSession> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('local_id')) {
      context.handle(
        _localIdMeta,
        localId.isAcceptableOrUnknown(data['local_id']!, _localIdMeta),
      );
    } else if (isInserting) {
      context.missing(_localIdMeta);
    }
    if (data.containsKey('account_key')) {
      context.handle(
        _accountKeyMeta,
        accountKey.isAcceptableOrUnknown(data['account_key']!, _accountKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_accountKeyMeta);
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    }
    if (data.containsKey('section_id')) {
      context.handle(
        _sectionIdMeta,
        sectionId.isAcceptableOrUnknown(data['section_id']!, _sectionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sectionIdMeta);
    }
    if (data.containsKey('academic_year_id')) {
      context.handle(
        _academicYearIdMeta,
        academicYearId.isAcceptableOrUnknown(
          data['academic_year_id']!,
          _academicYearIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_academicYearIdMeta);
    }
    if (data.containsKey('subject_id')) {
      context.handle(
        _subjectIdMeta,
        subjectId.isAcceptableOrUnknown(data['subject_id']!, _subjectIdMeta),
      );
    }
    if (data.containsKey('staff_id')) {
      context.handle(
        _staffIdMeta,
        staffId.isAcceptableOrUnknown(data['staff_id']!, _staffIdMeta),
      );
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('period_number')) {
      context.handle(
        _periodNumberMeta,
        periodNumber.isAcceptableOrUnknown(
          data['period_number']!,
          _periodNumberMeta,
        ),
      );
    }
    if (data.containsKey('timetable_slot_id')) {
      context.handle(
        _timetableSlotIdMeta,
        timetableSlotId.isAcceptableOrUnknown(
          data['timetable_slot_id']!,
          _timetableSlotIdMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('is_finalized')) {
      context.handle(
        _isFinalizedMeta,
        isFinalized.isAcceptableOrUnknown(
          data['is_finalized']!,
          _isFinalizedMeta,
        ),
      );
    }
    if (data.containsKey('student_attendances_json')) {
      context.handle(
        _studentAttendancesJsonMeta,
        studentAttendancesJson.isAcceptableOrUnknown(
          data['student_attendances_json']!,
          _studentAttendancesJsonMeta,
        ),
      );
    }
    if (data.containsKey('local_updated_at')) {
      context.handle(
        _localUpdatedAtMeta,
        localUpdatedAt.isAcceptableOrUnknown(
          data['local_updated_at']!,
          _localUpdatedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_localUpdatedAtMeta);
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {accountKey, localId};
  @override
  LocalAttendanceSession map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalAttendanceSession(
      localId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_id'],
      )!,
      accountKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_key'],
      )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      ),
      sectionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}section_id'],
      )!,
      academicYearId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}academic_year_id'],
      )!,
      subjectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject_id'],
      )!,
      staffId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}staff_id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date'],
      )!,
      periodNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}period_number'],
      )!,
      timetableSlotId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}timetable_slot_id'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      isFinalized: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_finalized'],
      )!,
      studentAttendancesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}student_attendances_json'],
      )!,
      localUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}local_updated_at'],
      )!,
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_status'],
      )!,
    );
  }

  @override
  $LocalAttendanceSessionsTable createAlias(String alias) {
    return $LocalAttendanceSessionsTable(attachedDatabase, alias);
  }
}

class LocalAttendanceSession extends DataClass
    implements Insertable<LocalAttendanceSession> {
  final String localId;
  final String accountKey;
  final String? serverId;
  final String sectionId;
  final String academicYearId;
  final String subjectId;
  final String staffId;
  final String date;
  final int periodNumber;
  final String timetableSlotId;
  final String status;
  final bool isFinalized;
  final String studentAttendancesJson;
  final DateTime localUpdatedAt;
  final String syncStatus;
  const LocalAttendanceSession({
    required this.localId,
    required this.accountKey,
    this.serverId,
    required this.sectionId,
    required this.academicYearId,
    required this.subjectId,
    required this.staffId,
    required this.date,
    required this.periodNumber,
    required this.timetableSlotId,
    required this.status,
    required this.isFinalized,
    required this.studentAttendancesJson,
    required this.localUpdatedAt,
    required this.syncStatus,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['local_id'] = Variable<String>(localId);
    map['account_key'] = Variable<String>(accountKey);
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<String>(serverId);
    }
    map['section_id'] = Variable<String>(sectionId);
    map['academic_year_id'] = Variable<String>(academicYearId);
    map['subject_id'] = Variable<String>(subjectId);
    map['staff_id'] = Variable<String>(staffId);
    map['date'] = Variable<String>(date);
    map['period_number'] = Variable<int>(periodNumber);
    map['timetable_slot_id'] = Variable<String>(timetableSlotId);
    map['status'] = Variable<String>(status);
    map['is_finalized'] = Variable<bool>(isFinalized);
    map['student_attendances_json'] = Variable<String>(studentAttendancesJson);
    map['local_updated_at'] = Variable<DateTime>(localUpdatedAt);
    map['sync_status'] = Variable<String>(syncStatus);
    return map;
  }

  LocalAttendanceSessionsCompanion toCompanion(bool nullToAbsent) {
    return LocalAttendanceSessionsCompanion(
      localId: Value(localId),
      accountKey: Value(accountKey),
      serverId: serverId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverId),
      sectionId: Value(sectionId),
      academicYearId: Value(academicYearId),
      subjectId: Value(subjectId),
      staffId: Value(staffId),
      date: Value(date),
      periodNumber: Value(periodNumber),
      timetableSlotId: Value(timetableSlotId),
      status: Value(status),
      isFinalized: Value(isFinalized),
      studentAttendancesJson: Value(studentAttendancesJson),
      localUpdatedAt: Value(localUpdatedAt),
      syncStatus: Value(syncStatus),
    );
  }

  factory LocalAttendanceSession.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalAttendanceSession(
      localId: serializer.fromJson<String>(json['localId']),
      accountKey: serializer.fromJson<String>(json['accountKey']),
      serverId: serializer.fromJson<String?>(json['serverId']),
      sectionId: serializer.fromJson<String>(json['sectionId']),
      academicYearId: serializer.fromJson<String>(json['academicYearId']),
      subjectId: serializer.fromJson<String>(json['subjectId']),
      staffId: serializer.fromJson<String>(json['staffId']),
      date: serializer.fromJson<String>(json['date']),
      periodNumber: serializer.fromJson<int>(json['periodNumber']),
      timetableSlotId: serializer.fromJson<String>(json['timetableSlotId']),
      status: serializer.fromJson<String>(json['status']),
      isFinalized: serializer.fromJson<bool>(json['isFinalized']),
      studentAttendancesJson: serializer.fromJson<String>(
        json['studentAttendancesJson'],
      ),
      localUpdatedAt: serializer.fromJson<DateTime>(json['localUpdatedAt']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'localId': serializer.toJson<String>(localId),
      'accountKey': serializer.toJson<String>(accountKey),
      'serverId': serializer.toJson<String?>(serverId),
      'sectionId': serializer.toJson<String>(sectionId),
      'academicYearId': serializer.toJson<String>(academicYearId),
      'subjectId': serializer.toJson<String>(subjectId),
      'staffId': serializer.toJson<String>(staffId),
      'date': serializer.toJson<String>(date),
      'periodNumber': serializer.toJson<int>(periodNumber),
      'timetableSlotId': serializer.toJson<String>(timetableSlotId),
      'status': serializer.toJson<String>(status),
      'isFinalized': serializer.toJson<bool>(isFinalized),
      'studentAttendancesJson': serializer.toJson<String>(
        studentAttendancesJson,
      ),
      'localUpdatedAt': serializer.toJson<DateTime>(localUpdatedAt),
      'syncStatus': serializer.toJson<String>(syncStatus),
    };
  }

  LocalAttendanceSession copyWith({
    String? localId,
    String? accountKey,
    Value<String?> serverId = const Value.absent(),
    String? sectionId,
    String? academicYearId,
    String? subjectId,
    String? staffId,
    String? date,
    int? periodNumber,
    String? timetableSlotId,
    String? status,
    bool? isFinalized,
    String? studentAttendancesJson,
    DateTime? localUpdatedAt,
    String? syncStatus,
  }) => LocalAttendanceSession(
    localId: localId ?? this.localId,
    accountKey: accountKey ?? this.accountKey,
    serverId: serverId.present ? serverId.value : this.serverId,
    sectionId: sectionId ?? this.sectionId,
    academicYearId: academicYearId ?? this.academicYearId,
    subjectId: subjectId ?? this.subjectId,
    staffId: staffId ?? this.staffId,
    date: date ?? this.date,
    periodNumber: periodNumber ?? this.periodNumber,
    timetableSlotId: timetableSlotId ?? this.timetableSlotId,
    status: status ?? this.status,
    isFinalized: isFinalized ?? this.isFinalized,
    studentAttendancesJson:
        studentAttendancesJson ?? this.studentAttendancesJson,
    localUpdatedAt: localUpdatedAt ?? this.localUpdatedAt,
    syncStatus: syncStatus ?? this.syncStatus,
  );
  LocalAttendanceSession copyWithCompanion(
    LocalAttendanceSessionsCompanion data,
  ) {
    return LocalAttendanceSession(
      localId: data.localId.present ? data.localId.value : this.localId,
      accountKey: data.accountKey.present
          ? data.accountKey.value
          : this.accountKey,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      sectionId: data.sectionId.present ? data.sectionId.value : this.sectionId,
      academicYearId: data.academicYearId.present
          ? data.academicYearId.value
          : this.academicYearId,
      subjectId: data.subjectId.present ? data.subjectId.value : this.subjectId,
      staffId: data.staffId.present ? data.staffId.value : this.staffId,
      date: data.date.present ? data.date.value : this.date,
      periodNumber: data.periodNumber.present
          ? data.periodNumber.value
          : this.periodNumber,
      timetableSlotId: data.timetableSlotId.present
          ? data.timetableSlotId.value
          : this.timetableSlotId,
      status: data.status.present ? data.status.value : this.status,
      isFinalized: data.isFinalized.present
          ? data.isFinalized.value
          : this.isFinalized,
      studentAttendancesJson: data.studentAttendancesJson.present
          ? data.studentAttendancesJson.value
          : this.studentAttendancesJson,
      localUpdatedAt: data.localUpdatedAt.present
          ? data.localUpdatedAt.value
          : this.localUpdatedAt,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalAttendanceSession(')
          ..write('localId: $localId, ')
          ..write('accountKey: $accountKey, ')
          ..write('serverId: $serverId, ')
          ..write('sectionId: $sectionId, ')
          ..write('academicYearId: $academicYearId, ')
          ..write('subjectId: $subjectId, ')
          ..write('staffId: $staffId, ')
          ..write('date: $date, ')
          ..write('periodNumber: $periodNumber, ')
          ..write('timetableSlotId: $timetableSlotId, ')
          ..write('status: $status, ')
          ..write('isFinalized: $isFinalized, ')
          ..write('studentAttendancesJson: $studentAttendancesJson, ')
          ..write('localUpdatedAt: $localUpdatedAt, ')
          ..write('syncStatus: $syncStatus')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    localId,
    accountKey,
    serverId,
    sectionId,
    academicYearId,
    subjectId,
    staffId,
    date,
    periodNumber,
    timetableSlotId,
    status,
    isFinalized,
    studentAttendancesJson,
    localUpdatedAt,
    syncStatus,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalAttendanceSession &&
          other.localId == this.localId &&
          other.accountKey == this.accountKey &&
          other.serverId == this.serverId &&
          other.sectionId == this.sectionId &&
          other.academicYearId == this.academicYearId &&
          other.subjectId == this.subjectId &&
          other.staffId == this.staffId &&
          other.date == this.date &&
          other.periodNumber == this.periodNumber &&
          other.timetableSlotId == this.timetableSlotId &&
          other.status == this.status &&
          other.isFinalized == this.isFinalized &&
          other.studentAttendancesJson == this.studentAttendancesJson &&
          other.localUpdatedAt == this.localUpdatedAt &&
          other.syncStatus == this.syncStatus);
}

class LocalAttendanceSessionsCompanion
    extends UpdateCompanion<LocalAttendanceSession> {
  final Value<String> localId;
  final Value<String> accountKey;
  final Value<String?> serverId;
  final Value<String> sectionId;
  final Value<String> academicYearId;
  final Value<String> subjectId;
  final Value<String> staffId;
  final Value<String> date;
  final Value<int> periodNumber;
  final Value<String> timetableSlotId;
  final Value<String> status;
  final Value<bool> isFinalized;
  final Value<String> studentAttendancesJson;
  final Value<DateTime> localUpdatedAt;
  final Value<String> syncStatus;
  final Value<int> rowid;
  const LocalAttendanceSessionsCompanion({
    this.localId = const Value.absent(),
    this.accountKey = const Value.absent(),
    this.serverId = const Value.absent(),
    this.sectionId = const Value.absent(),
    this.academicYearId = const Value.absent(),
    this.subjectId = const Value.absent(),
    this.staffId = const Value.absent(),
    this.date = const Value.absent(),
    this.periodNumber = const Value.absent(),
    this.timetableSlotId = const Value.absent(),
    this.status = const Value.absent(),
    this.isFinalized = const Value.absent(),
    this.studentAttendancesJson = const Value.absent(),
    this.localUpdatedAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalAttendanceSessionsCompanion.insert({
    required String localId,
    required String accountKey,
    this.serverId = const Value.absent(),
    required String sectionId,
    required String academicYearId,
    this.subjectId = const Value.absent(),
    this.staffId = const Value.absent(),
    required String date,
    this.periodNumber = const Value.absent(),
    this.timetableSlotId = const Value.absent(),
    this.status = const Value.absent(),
    this.isFinalized = const Value.absent(),
    this.studentAttendancesJson = const Value.absent(),
    required DateTime localUpdatedAt,
    this.syncStatus = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : localId = Value(localId),
       accountKey = Value(accountKey),
       sectionId = Value(sectionId),
       academicYearId = Value(academicYearId),
       date = Value(date),
       localUpdatedAt = Value(localUpdatedAt);
  static Insertable<LocalAttendanceSession> custom({
    Expression<String>? localId,
    Expression<String>? accountKey,
    Expression<String>? serverId,
    Expression<String>? sectionId,
    Expression<String>? academicYearId,
    Expression<String>? subjectId,
    Expression<String>? staffId,
    Expression<String>? date,
    Expression<int>? periodNumber,
    Expression<String>? timetableSlotId,
    Expression<String>? status,
    Expression<bool>? isFinalized,
    Expression<String>? studentAttendancesJson,
    Expression<DateTime>? localUpdatedAt,
    Expression<String>? syncStatus,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (localId != null) 'local_id': localId,
      if (accountKey != null) 'account_key': accountKey,
      if (serverId != null) 'server_id': serverId,
      if (sectionId != null) 'section_id': sectionId,
      if (academicYearId != null) 'academic_year_id': academicYearId,
      if (subjectId != null) 'subject_id': subjectId,
      if (staffId != null) 'staff_id': staffId,
      if (date != null) 'date': date,
      if (periodNumber != null) 'period_number': periodNumber,
      if (timetableSlotId != null) 'timetable_slot_id': timetableSlotId,
      if (status != null) 'status': status,
      if (isFinalized != null) 'is_finalized': isFinalized,
      if (studentAttendancesJson != null)
        'student_attendances_json': studentAttendancesJson,
      if (localUpdatedAt != null) 'local_updated_at': localUpdatedAt,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalAttendanceSessionsCompanion copyWith({
    Value<String>? localId,
    Value<String>? accountKey,
    Value<String?>? serverId,
    Value<String>? sectionId,
    Value<String>? academicYearId,
    Value<String>? subjectId,
    Value<String>? staffId,
    Value<String>? date,
    Value<int>? periodNumber,
    Value<String>? timetableSlotId,
    Value<String>? status,
    Value<bool>? isFinalized,
    Value<String>? studentAttendancesJson,
    Value<DateTime>? localUpdatedAt,
    Value<String>? syncStatus,
    Value<int>? rowid,
  }) {
    return LocalAttendanceSessionsCompanion(
      localId: localId ?? this.localId,
      accountKey: accountKey ?? this.accountKey,
      serverId: serverId ?? this.serverId,
      sectionId: sectionId ?? this.sectionId,
      academicYearId: academicYearId ?? this.academicYearId,
      subjectId: subjectId ?? this.subjectId,
      staffId: staffId ?? this.staffId,
      date: date ?? this.date,
      periodNumber: periodNumber ?? this.periodNumber,
      timetableSlotId: timetableSlotId ?? this.timetableSlotId,
      status: status ?? this.status,
      isFinalized: isFinalized ?? this.isFinalized,
      studentAttendancesJson:
          studentAttendancesJson ?? this.studentAttendancesJson,
      localUpdatedAt: localUpdatedAt ?? this.localUpdatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (localId.present) {
      map['local_id'] = Variable<String>(localId.value);
    }
    if (accountKey.present) {
      map['account_key'] = Variable<String>(accountKey.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (sectionId.present) {
      map['section_id'] = Variable<String>(sectionId.value);
    }
    if (academicYearId.present) {
      map['academic_year_id'] = Variable<String>(academicYearId.value);
    }
    if (subjectId.present) {
      map['subject_id'] = Variable<String>(subjectId.value);
    }
    if (staffId.present) {
      map['staff_id'] = Variable<String>(staffId.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (periodNumber.present) {
      map['period_number'] = Variable<int>(periodNumber.value);
    }
    if (timetableSlotId.present) {
      map['timetable_slot_id'] = Variable<String>(timetableSlotId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (isFinalized.present) {
      map['is_finalized'] = Variable<bool>(isFinalized.value);
    }
    if (studentAttendancesJson.present) {
      map['student_attendances_json'] = Variable<String>(
        studentAttendancesJson.value,
      );
    }
    if (localUpdatedAt.present) {
      map['local_updated_at'] = Variable<DateTime>(localUpdatedAt.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalAttendanceSessionsCompanion(')
          ..write('localId: $localId, ')
          ..write('accountKey: $accountKey, ')
          ..write('serverId: $serverId, ')
          ..write('sectionId: $sectionId, ')
          ..write('academicYearId: $academicYearId, ')
          ..write('subjectId: $subjectId, ')
          ..write('staffId: $staffId, ')
          ..write('date: $date, ')
          ..write('periodNumber: $periodNumber, ')
          ..write('timetableSlotId: $timetableSlotId, ')
          ..write('status: $status, ')
          ..write('isFinalized: $isFinalized, ')
          ..write('studentAttendancesJson: $studentAttendancesJson, ')
          ..write('localUpdatedAt: $localUpdatedAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalStudentsTable extends LocalStudents
    with TableInfo<$LocalStudentsTable, LocalStudent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalStudentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
    'server_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accountKeyMeta = const VerificationMeta(
    'accountKey',
  );
  @override
  late final GeneratedColumn<String> accountKey = GeneratedColumn<String>(
    'account_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _schoolIdMeta = const VerificationMeta(
    'schoolId',
  );
  @override
  late final GeneratedColumn<String> schoolId = GeneratedColumn<String>(
    'school_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fullNameMeta = const VerificationMeta(
    'fullName',
  );
  @override
  late final GeneratedColumn<String> fullName = GeneratedColumn<String>(
    'full_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sectionIdMeta = const VerificationMeta(
    'sectionId',
  );
  @override
  late final GeneratedColumn<String> sectionId = GeneratedColumn<String>(
    'section_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _classNameMeta = const VerificationMeta(
    'className',
  );
  @override
  late final GeneratedColumn<String> className = GeneratedColumn<String>(
    'class_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _sectionNameMeta = const VerificationMeta(
    'sectionName',
  );
  @override
  late final GeneratedColumn<String> sectionName = GeneratedColumn<String>(
    'section_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('active'),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _localUpdatedAtMeta = const VerificationMeta(
    'localUpdatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> localUpdatedAt =
      GeneratedColumn<DateTime>(
        'local_updated_at',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _serverVersionMeta = const VerificationMeta(
    'serverVersion',
  );
  @override
  late final GeneratedColumn<int> serverVersion = GeneratedColumn<int>(
    'server_version',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rawJsonMeta = const VerificationMeta(
    'rawJson',
  );
  @override
  late final GeneratedColumn<String> rawJson = GeneratedColumn<String>(
    'raw_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    serverId,
    accountKey,
    schoolId,
    fullName,
    sectionId,
    className,
    sectionName,
    status,
    updatedAt,
    localUpdatedAt,
    serverVersion,
    rawJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_students';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalStudent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    } else if (isInserting) {
      context.missing(_serverIdMeta);
    }
    if (data.containsKey('account_key')) {
      context.handle(
        _accountKeyMeta,
        accountKey.isAcceptableOrUnknown(data['account_key']!, _accountKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_accountKeyMeta);
    }
    if (data.containsKey('school_id')) {
      context.handle(
        _schoolIdMeta,
        schoolId.isAcceptableOrUnknown(data['school_id']!, _schoolIdMeta),
      );
    }
    if (data.containsKey('full_name')) {
      context.handle(
        _fullNameMeta,
        fullName.isAcceptableOrUnknown(data['full_name']!, _fullNameMeta),
      );
    } else if (isInserting) {
      context.missing(_fullNameMeta);
    }
    if (data.containsKey('section_id')) {
      context.handle(
        _sectionIdMeta,
        sectionId.isAcceptableOrUnknown(data['section_id']!, _sectionIdMeta),
      );
    }
    if (data.containsKey('class_name')) {
      context.handle(
        _classNameMeta,
        className.isAcceptableOrUnknown(data['class_name']!, _classNameMeta),
      );
    }
    if (data.containsKey('section_name')) {
      context.handle(
        _sectionNameMeta,
        sectionName.isAcceptableOrUnknown(
          data['section_name']!,
          _sectionNameMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('local_updated_at')) {
      context.handle(
        _localUpdatedAtMeta,
        localUpdatedAt.isAcceptableOrUnknown(
          data['local_updated_at']!,
          _localUpdatedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_localUpdatedAtMeta);
    }
    if (data.containsKey('server_version')) {
      context.handle(
        _serverVersionMeta,
        serverVersion.isAcceptableOrUnknown(
          data['server_version']!,
          _serverVersionMeta,
        ),
      );
    }
    if (data.containsKey('raw_json')) {
      context.handle(
        _rawJsonMeta,
        rawJson.isAcceptableOrUnknown(data['raw_json']!, _rawJsonMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {accountKey, serverId};
  @override
  LocalStudent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalStudent(
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      )!,
      accountKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_key'],
      )!,
      schoolId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}school_id'],
      ),
      fullName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}full_name'],
      )!,
      sectionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}section_id'],
      ),
      className: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}class_name'],
      )!,
      sectionName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}section_name'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      ),
      localUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}local_updated_at'],
      )!,
      serverVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_version'],
      ),
      rawJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}raw_json'],
      )!,
    );
  }

  @override
  $LocalStudentsTable createAlias(String alias) {
    return $LocalStudentsTable(attachedDatabase, alias);
  }
}

class LocalStudent extends DataClass implements Insertable<LocalStudent> {
  final String serverId;
  final String accountKey;
  final String? schoolId;
  final String fullName;
  final String? sectionId;
  final String className;
  final String sectionName;
  final String status;
  final DateTime? updatedAt;
  final DateTime localUpdatedAt;
  final int? serverVersion;
  final String rawJson;
  const LocalStudent({
    required this.serverId,
    required this.accountKey,
    this.schoolId,
    required this.fullName,
    this.sectionId,
    required this.className,
    required this.sectionName,
    required this.status,
    this.updatedAt,
    required this.localUpdatedAt,
    this.serverVersion,
    required this.rawJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['server_id'] = Variable<String>(serverId);
    map['account_key'] = Variable<String>(accountKey);
    if (!nullToAbsent || schoolId != null) {
      map['school_id'] = Variable<String>(schoolId);
    }
    map['full_name'] = Variable<String>(fullName);
    if (!nullToAbsent || sectionId != null) {
      map['section_id'] = Variable<String>(sectionId);
    }
    map['class_name'] = Variable<String>(className);
    map['section_name'] = Variable<String>(sectionName);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    map['local_updated_at'] = Variable<DateTime>(localUpdatedAt);
    if (!nullToAbsent || serverVersion != null) {
      map['server_version'] = Variable<int>(serverVersion);
    }
    map['raw_json'] = Variable<String>(rawJson);
    return map;
  }

  LocalStudentsCompanion toCompanion(bool nullToAbsent) {
    return LocalStudentsCompanion(
      serverId: Value(serverId),
      accountKey: Value(accountKey),
      schoolId: schoolId == null && nullToAbsent
          ? const Value.absent()
          : Value(schoolId),
      fullName: Value(fullName),
      sectionId: sectionId == null && nullToAbsent
          ? const Value.absent()
          : Value(sectionId),
      className: Value(className),
      sectionName: Value(sectionName),
      status: Value(status),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      localUpdatedAt: Value(localUpdatedAt),
      serverVersion: serverVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(serverVersion),
      rawJson: Value(rawJson),
    );
  }

  factory LocalStudent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalStudent(
      serverId: serializer.fromJson<String>(json['serverId']),
      accountKey: serializer.fromJson<String>(json['accountKey']),
      schoolId: serializer.fromJson<String?>(json['schoolId']),
      fullName: serializer.fromJson<String>(json['fullName']),
      sectionId: serializer.fromJson<String?>(json['sectionId']),
      className: serializer.fromJson<String>(json['className']),
      sectionName: serializer.fromJson<String>(json['sectionName']),
      status: serializer.fromJson<String>(json['status']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
      localUpdatedAt: serializer.fromJson<DateTime>(json['localUpdatedAt']),
      serverVersion: serializer.fromJson<int?>(json['serverVersion']),
      rawJson: serializer.fromJson<String>(json['rawJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'serverId': serializer.toJson<String>(serverId),
      'accountKey': serializer.toJson<String>(accountKey),
      'schoolId': serializer.toJson<String?>(schoolId),
      'fullName': serializer.toJson<String>(fullName),
      'sectionId': serializer.toJson<String?>(sectionId),
      'className': serializer.toJson<String>(className),
      'sectionName': serializer.toJson<String>(sectionName),
      'status': serializer.toJson<String>(status),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
      'localUpdatedAt': serializer.toJson<DateTime>(localUpdatedAt),
      'serverVersion': serializer.toJson<int?>(serverVersion),
      'rawJson': serializer.toJson<String>(rawJson),
    };
  }

  LocalStudent copyWith({
    String? serverId,
    String? accountKey,
    Value<String?> schoolId = const Value.absent(),
    String? fullName,
    Value<String?> sectionId = const Value.absent(),
    String? className,
    String? sectionName,
    String? status,
    Value<DateTime?> updatedAt = const Value.absent(),
    DateTime? localUpdatedAt,
    Value<int?> serverVersion = const Value.absent(),
    String? rawJson,
  }) => LocalStudent(
    serverId: serverId ?? this.serverId,
    accountKey: accountKey ?? this.accountKey,
    schoolId: schoolId.present ? schoolId.value : this.schoolId,
    fullName: fullName ?? this.fullName,
    sectionId: sectionId.present ? sectionId.value : this.sectionId,
    className: className ?? this.className,
    sectionName: sectionName ?? this.sectionName,
    status: status ?? this.status,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    localUpdatedAt: localUpdatedAt ?? this.localUpdatedAt,
    serverVersion: serverVersion.present
        ? serverVersion.value
        : this.serverVersion,
    rawJson: rawJson ?? this.rawJson,
  );
  LocalStudent copyWithCompanion(LocalStudentsCompanion data) {
    return LocalStudent(
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      accountKey: data.accountKey.present
          ? data.accountKey.value
          : this.accountKey,
      schoolId: data.schoolId.present ? data.schoolId.value : this.schoolId,
      fullName: data.fullName.present ? data.fullName.value : this.fullName,
      sectionId: data.sectionId.present ? data.sectionId.value : this.sectionId,
      className: data.className.present ? data.className.value : this.className,
      sectionName: data.sectionName.present
          ? data.sectionName.value
          : this.sectionName,
      status: data.status.present ? data.status.value : this.status,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      localUpdatedAt: data.localUpdatedAt.present
          ? data.localUpdatedAt.value
          : this.localUpdatedAt,
      serverVersion: data.serverVersion.present
          ? data.serverVersion.value
          : this.serverVersion,
      rawJson: data.rawJson.present ? data.rawJson.value : this.rawJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalStudent(')
          ..write('serverId: $serverId, ')
          ..write('accountKey: $accountKey, ')
          ..write('schoolId: $schoolId, ')
          ..write('fullName: $fullName, ')
          ..write('sectionId: $sectionId, ')
          ..write('className: $className, ')
          ..write('sectionName: $sectionName, ')
          ..write('status: $status, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('localUpdatedAt: $localUpdatedAt, ')
          ..write('serverVersion: $serverVersion, ')
          ..write('rawJson: $rawJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    serverId,
    accountKey,
    schoolId,
    fullName,
    sectionId,
    className,
    sectionName,
    status,
    updatedAt,
    localUpdatedAt,
    serverVersion,
    rawJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalStudent &&
          other.serverId == this.serverId &&
          other.accountKey == this.accountKey &&
          other.schoolId == this.schoolId &&
          other.fullName == this.fullName &&
          other.sectionId == this.sectionId &&
          other.className == this.className &&
          other.sectionName == this.sectionName &&
          other.status == this.status &&
          other.updatedAt == this.updatedAt &&
          other.localUpdatedAt == this.localUpdatedAt &&
          other.serverVersion == this.serverVersion &&
          other.rawJson == this.rawJson);
}

class LocalStudentsCompanion extends UpdateCompanion<LocalStudent> {
  final Value<String> serverId;
  final Value<String> accountKey;
  final Value<String?> schoolId;
  final Value<String> fullName;
  final Value<String?> sectionId;
  final Value<String> className;
  final Value<String> sectionName;
  final Value<String> status;
  final Value<DateTime?> updatedAt;
  final Value<DateTime> localUpdatedAt;
  final Value<int?> serverVersion;
  final Value<String> rawJson;
  final Value<int> rowid;
  const LocalStudentsCompanion({
    this.serverId = const Value.absent(),
    this.accountKey = const Value.absent(),
    this.schoolId = const Value.absent(),
    this.fullName = const Value.absent(),
    this.sectionId = const Value.absent(),
    this.className = const Value.absent(),
    this.sectionName = const Value.absent(),
    this.status = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.localUpdatedAt = const Value.absent(),
    this.serverVersion = const Value.absent(),
    this.rawJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalStudentsCompanion.insert({
    required String serverId,
    required String accountKey,
    this.schoolId = const Value.absent(),
    required String fullName,
    this.sectionId = const Value.absent(),
    this.className = const Value.absent(),
    this.sectionName = const Value.absent(),
    this.status = const Value.absent(),
    this.updatedAt = const Value.absent(),
    required DateTime localUpdatedAt,
    this.serverVersion = const Value.absent(),
    this.rawJson = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : serverId = Value(serverId),
       accountKey = Value(accountKey),
       fullName = Value(fullName),
       localUpdatedAt = Value(localUpdatedAt);
  static Insertable<LocalStudent> custom({
    Expression<String>? serverId,
    Expression<String>? accountKey,
    Expression<String>? schoolId,
    Expression<String>? fullName,
    Expression<String>? sectionId,
    Expression<String>? className,
    Expression<String>? sectionName,
    Expression<String>? status,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? localUpdatedAt,
    Expression<int>? serverVersion,
    Expression<String>? rawJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (serverId != null) 'server_id': serverId,
      if (accountKey != null) 'account_key': accountKey,
      if (schoolId != null) 'school_id': schoolId,
      if (fullName != null) 'full_name': fullName,
      if (sectionId != null) 'section_id': sectionId,
      if (className != null) 'class_name': className,
      if (sectionName != null) 'section_name': sectionName,
      if (status != null) 'status': status,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (localUpdatedAt != null) 'local_updated_at': localUpdatedAt,
      if (serverVersion != null) 'server_version': serverVersion,
      if (rawJson != null) 'raw_json': rawJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalStudentsCompanion copyWith({
    Value<String>? serverId,
    Value<String>? accountKey,
    Value<String?>? schoolId,
    Value<String>? fullName,
    Value<String?>? sectionId,
    Value<String>? className,
    Value<String>? sectionName,
    Value<String>? status,
    Value<DateTime?>? updatedAt,
    Value<DateTime>? localUpdatedAt,
    Value<int?>? serverVersion,
    Value<String>? rawJson,
    Value<int>? rowid,
  }) {
    return LocalStudentsCompanion(
      serverId: serverId ?? this.serverId,
      accountKey: accountKey ?? this.accountKey,
      schoolId: schoolId ?? this.schoolId,
      fullName: fullName ?? this.fullName,
      sectionId: sectionId ?? this.sectionId,
      className: className ?? this.className,
      sectionName: sectionName ?? this.sectionName,
      status: status ?? this.status,
      updatedAt: updatedAt ?? this.updatedAt,
      localUpdatedAt: localUpdatedAt ?? this.localUpdatedAt,
      serverVersion: serverVersion ?? this.serverVersion,
      rawJson: rawJson ?? this.rawJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (accountKey.present) {
      map['account_key'] = Variable<String>(accountKey.value);
    }
    if (schoolId.present) {
      map['school_id'] = Variable<String>(schoolId.value);
    }
    if (fullName.present) {
      map['full_name'] = Variable<String>(fullName.value);
    }
    if (sectionId.present) {
      map['section_id'] = Variable<String>(sectionId.value);
    }
    if (className.present) {
      map['class_name'] = Variable<String>(className.value);
    }
    if (sectionName.present) {
      map['section_name'] = Variable<String>(sectionName.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (localUpdatedAt.present) {
      map['local_updated_at'] = Variable<DateTime>(localUpdatedAt.value);
    }
    if (serverVersion.present) {
      map['server_version'] = Variable<int>(serverVersion.value);
    }
    if (rawJson.present) {
      map['raw_json'] = Variable<String>(rawJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalStudentsCompanion(')
          ..write('serverId: $serverId, ')
          ..write('accountKey: $accountKey, ')
          ..write('schoolId: $schoolId, ')
          ..write('fullName: $fullName, ')
          ..write('sectionId: $sectionId, ')
          ..write('className: $className, ')
          ..write('sectionName: $sectionName, ')
          ..write('status: $status, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('localUpdatedAt: $localUpdatedAt, ')
          ..write('serverVersion: $serverVersion, ')
          ..write('rawJson: $rawJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalHomeworkDraftsTable extends LocalHomeworkDrafts
    with TableInfo<$LocalHomeworkDraftsTable, LocalHomeworkDraft> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalHomeworkDraftsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _localIdMeta = const VerificationMeta(
    'localId',
  );
  @override
  late final GeneratedColumn<String> localId = GeneratedColumn<String>(
    'local_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accountKeyMeta = const VerificationMeta(
    'accountKey',
  );
  @override
  late final GeneratedColumn<String> accountKey = GeneratedColumn<String>(
    'account_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
    'server_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subjectMeta = const VerificationMeta(
    'subject',
  );
  @override
  late final GeneratedColumn<String> subject = GeneratedColumn<String>(
    'subject',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _classNameMeta = const VerificationMeta(
    'className',
  );
  @override
  late final GeneratedColumn<String> className = GeneratedColumn<String>(
    'class_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _sectionIdMeta = const VerificationMeta(
    'sectionId',
  );
  @override
  late final GeneratedColumn<String> sectionId = GeneratedColumn<String>(
    'section_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _teacherIdMeta = const VerificationMeta(
    'teacherId',
  );
  @override
  late final GeneratedColumn<String> teacherId = GeneratedColumn<String>(
    'teacher_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _dueDateMeta = const VerificationMeta(
    'dueDate',
  );
  @override
  late final GeneratedColumn<String> dueDate = GeneratedColumn<String>(
    'due_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _studentIdMeta = const VerificationMeta(
    'studentId',
  );
  @override
  late final GeneratedColumn<String> studentId = GeneratedColumn<String>(
    'student_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _attachmentUrlMeta = const VerificationMeta(
    'attachmentUrl',
  );
  @override
  late final GeneratedColumn<String> attachmentUrl = GeneratedColumn<String>(
    'attachment_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('draft'),
  );
  static const VerificationMeta _localUpdatedAtMeta = const VerificationMeta(
    'localUpdatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> localUpdatedAt =
      GeneratedColumn<DateTime>(
        'local_updated_at',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _rawJsonMeta = const VerificationMeta(
    'rawJson',
  );
  @override
  late final GeneratedColumn<String> rawJson = GeneratedColumn<String>(
    'raw_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    localId,
    accountKey,
    serverId,
    title,
    subject,
    className,
    sectionId,
    teacherId,
    description,
    dueDate,
    studentId,
    attachmentUrl,
    status,
    localUpdatedAt,
    syncStatus,
    rawJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_homework_drafts';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalHomeworkDraft> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('local_id')) {
      context.handle(
        _localIdMeta,
        localId.isAcceptableOrUnknown(data['local_id']!, _localIdMeta),
      );
    } else if (isInserting) {
      context.missing(_localIdMeta);
    }
    if (data.containsKey('account_key')) {
      context.handle(
        _accountKeyMeta,
        accountKey.isAcceptableOrUnknown(data['account_key']!, _accountKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_accountKeyMeta);
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('subject')) {
      context.handle(
        _subjectMeta,
        subject.isAcceptableOrUnknown(data['subject']!, _subjectMeta),
      );
    }
    if (data.containsKey('class_name')) {
      context.handle(
        _classNameMeta,
        className.isAcceptableOrUnknown(data['class_name']!, _classNameMeta),
      );
    }
    if (data.containsKey('section_id')) {
      context.handle(
        _sectionIdMeta,
        sectionId.isAcceptableOrUnknown(data['section_id']!, _sectionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sectionIdMeta);
    }
    if (data.containsKey('teacher_id')) {
      context.handle(
        _teacherIdMeta,
        teacherId.isAcceptableOrUnknown(data['teacher_id']!, _teacherIdMeta),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('due_date')) {
      context.handle(
        _dueDateMeta,
        dueDate.isAcceptableOrUnknown(data['due_date']!, _dueDateMeta),
      );
    }
    if (data.containsKey('student_id')) {
      context.handle(
        _studentIdMeta,
        studentId.isAcceptableOrUnknown(data['student_id']!, _studentIdMeta),
      );
    }
    if (data.containsKey('attachment_url')) {
      context.handle(
        _attachmentUrlMeta,
        attachmentUrl.isAcceptableOrUnknown(
          data['attachment_url']!,
          _attachmentUrlMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('local_updated_at')) {
      context.handle(
        _localUpdatedAtMeta,
        localUpdatedAt.isAcceptableOrUnknown(
          data['local_updated_at']!,
          _localUpdatedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_localUpdatedAtMeta);
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    if (data.containsKey('raw_json')) {
      context.handle(
        _rawJsonMeta,
        rawJson.isAcceptableOrUnknown(data['raw_json']!, _rawJsonMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {accountKey, localId};
  @override
  LocalHomeworkDraft map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalHomeworkDraft(
      localId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_id'],
      )!,
      accountKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_key'],
      )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      subject: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject'],
      )!,
      className: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}class_name'],
      )!,
      sectionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}section_id'],
      )!,
      teacherId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}teacher_id'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      dueDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}due_date'],
      )!,
      studentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}student_id'],
      )!,
      attachmentUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}attachment_url'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      localUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}local_updated_at'],
      )!,
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_status'],
      )!,
      rawJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}raw_json'],
      )!,
    );
  }

  @override
  $LocalHomeworkDraftsTable createAlias(String alias) {
    return $LocalHomeworkDraftsTable(attachedDatabase, alias);
  }
}

class LocalHomeworkDraft extends DataClass
    implements Insertable<LocalHomeworkDraft> {
  final String localId;
  final String accountKey;
  final String? serverId;
  final String title;
  final String subject;
  final String className;
  final String sectionId;
  final String teacherId;
  final String description;
  final String dueDate;
  final String studentId;
  final String attachmentUrl;
  final String status;
  final DateTime localUpdatedAt;
  final String syncStatus;
  final String rawJson;
  const LocalHomeworkDraft({
    required this.localId,
    required this.accountKey,
    this.serverId,
    required this.title,
    required this.subject,
    required this.className,
    required this.sectionId,
    required this.teacherId,
    required this.description,
    required this.dueDate,
    required this.studentId,
    required this.attachmentUrl,
    required this.status,
    required this.localUpdatedAt,
    required this.syncStatus,
    required this.rawJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['local_id'] = Variable<String>(localId);
    map['account_key'] = Variable<String>(accountKey);
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<String>(serverId);
    }
    map['title'] = Variable<String>(title);
    map['subject'] = Variable<String>(subject);
    map['class_name'] = Variable<String>(className);
    map['section_id'] = Variable<String>(sectionId);
    map['teacher_id'] = Variable<String>(teacherId);
    map['description'] = Variable<String>(description);
    map['due_date'] = Variable<String>(dueDate);
    map['student_id'] = Variable<String>(studentId);
    map['attachment_url'] = Variable<String>(attachmentUrl);
    map['status'] = Variable<String>(status);
    map['local_updated_at'] = Variable<DateTime>(localUpdatedAt);
    map['sync_status'] = Variable<String>(syncStatus);
    map['raw_json'] = Variable<String>(rawJson);
    return map;
  }

  LocalHomeworkDraftsCompanion toCompanion(bool nullToAbsent) {
    return LocalHomeworkDraftsCompanion(
      localId: Value(localId),
      accountKey: Value(accountKey),
      serverId: serverId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverId),
      title: Value(title),
      subject: Value(subject),
      className: Value(className),
      sectionId: Value(sectionId),
      teacherId: Value(teacherId),
      description: Value(description),
      dueDate: Value(dueDate),
      studentId: Value(studentId),
      attachmentUrl: Value(attachmentUrl),
      status: Value(status),
      localUpdatedAt: Value(localUpdatedAt),
      syncStatus: Value(syncStatus),
      rawJson: Value(rawJson),
    );
  }

  factory LocalHomeworkDraft.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalHomeworkDraft(
      localId: serializer.fromJson<String>(json['localId']),
      accountKey: serializer.fromJson<String>(json['accountKey']),
      serverId: serializer.fromJson<String?>(json['serverId']),
      title: serializer.fromJson<String>(json['title']),
      subject: serializer.fromJson<String>(json['subject']),
      className: serializer.fromJson<String>(json['className']),
      sectionId: serializer.fromJson<String>(json['sectionId']),
      teacherId: serializer.fromJson<String>(json['teacherId']),
      description: serializer.fromJson<String>(json['description']),
      dueDate: serializer.fromJson<String>(json['dueDate']),
      studentId: serializer.fromJson<String>(json['studentId']),
      attachmentUrl: serializer.fromJson<String>(json['attachmentUrl']),
      status: serializer.fromJson<String>(json['status']),
      localUpdatedAt: serializer.fromJson<DateTime>(json['localUpdatedAt']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
      rawJson: serializer.fromJson<String>(json['rawJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'localId': serializer.toJson<String>(localId),
      'accountKey': serializer.toJson<String>(accountKey),
      'serverId': serializer.toJson<String?>(serverId),
      'title': serializer.toJson<String>(title),
      'subject': serializer.toJson<String>(subject),
      'className': serializer.toJson<String>(className),
      'sectionId': serializer.toJson<String>(sectionId),
      'teacherId': serializer.toJson<String>(teacherId),
      'description': serializer.toJson<String>(description),
      'dueDate': serializer.toJson<String>(dueDate),
      'studentId': serializer.toJson<String>(studentId),
      'attachmentUrl': serializer.toJson<String>(attachmentUrl),
      'status': serializer.toJson<String>(status),
      'localUpdatedAt': serializer.toJson<DateTime>(localUpdatedAt),
      'syncStatus': serializer.toJson<String>(syncStatus),
      'rawJson': serializer.toJson<String>(rawJson),
    };
  }

  LocalHomeworkDraft copyWith({
    String? localId,
    String? accountKey,
    Value<String?> serverId = const Value.absent(),
    String? title,
    String? subject,
    String? className,
    String? sectionId,
    String? teacherId,
    String? description,
    String? dueDate,
    String? studentId,
    String? attachmentUrl,
    String? status,
    DateTime? localUpdatedAt,
    String? syncStatus,
    String? rawJson,
  }) => LocalHomeworkDraft(
    localId: localId ?? this.localId,
    accountKey: accountKey ?? this.accountKey,
    serverId: serverId.present ? serverId.value : this.serverId,
    title: title ?? this.title,
    subject: subject ?? this.subject,
    className: className ?? this.className,
    sectionId: sectionId ?? this.sectionId,
    teacherId: teacherId ?? this.teacherId,
    description: description ?? this.description,
    dueDate: dueDate ?? this.dueDate,
    studentId: studentId ?? this.studentId,
    attachmentUrl: attachmentUrl ?? this.attachmentUrl,
    status: status ?? this.status,
    localUpdatedAt: localUpdatedAt ?? this.localUpdatedAt,
    syncStatus: syncStatus ?? this.syncStatus,
    rawJson: rawJson ?? this.rawJson,
  );
  LocalHomeworkDraft copyWithCompanion(LocalHomeworkDraftsCompanion data) {
    return LocalHomeworkDraft(
      localId: data.localId.present ? data.localId.value : this.localId,
      accountKey: data.accountKey.present
          ? data.accountKey.value
          : this.accountKey,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      title: data.title.present ? data.title.value : this.title,
      subject: data.subject.present ? data.subject.value : this.subject,
      className: data.className.present ? data.className.value : this.className,
      sectionId: data.sectionId.present ? data.sectionId.value : this.sectionId,
      teacherId: data.teacherId.present ? data.teacherId.value : this.teacherId,
      description: data.description.present
          ? data.description.value
          : this.description,
      dueDate: data.dueDate.present ? data.dueDate.value : this.dueDate,
      studentId: data.studentId.present ? data.studentId.value : this.studentId,
      attachmentUrl: data.attachmentUrl.present
          ? data.attachmentUrl.value
          : this.attachmentUrl,
      status: data.status.present ? data.status.value : this.status,
      localUpdatedAt: data.localUpdatedAt.present
          ? data.localUpdatedAt.value
          : this.localUpdatedAt,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      rawJson: data.rawJson.present ? data.rawJson.value : this.rawJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalHomeworkDraft(')
          ..write('localId: $localId, ')
          ..write('accountKey: $accountKey, ')
          ..write('serverId: $serverId, ')
          ..write('title: $title, ')
          ..write('subject: $subject, ')
          ..write('className: $className, ')
          ..write('sectionId: $sectionId, ')
          ..write('teacherId: $teacherId, ')
          ..write('description: $description, ')
          ..write('dueDate: $dueDate, ')
          ..write('studentId: $studentId, ')
          ..write('attachmentUrl: $attachmentUrl, ')
          ..write('status: $status, ')
          ..write('localUpdatedAt: $localUpdatedAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('rawJson: $rawJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    localId,
    accountKey,
    serverId,
    title,
    subject,
    className,
    sectionId,
    teacherId,
    description,
    dueDate,
    studentId,
    attachmentUrl,
    status,
    localUpdatedAt,
    syncStatus,
    rawJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalHomeworkDraft &&
          other.localId == this.localId &&
          other.accountKey == this.accountKey &&
          other.serverId == this.serverId &&
          other.title == this.title &&
          other.subject == this.subject &&
          other.className == this.className &&
          other.sectionId == this.sectionId &&
          other.teacherId == this.teacherId &&
          other.description == this.description &&
          other.dueDate == this.dueDate &&
          other.studentId == this.studentId &&
          other.attachmentUrl == this.attachmentUrl &&
          other.status == this.status &&
          other.localUpdatedAt == this.localUpdatedAt &&
          other.syncStatus == this.syncStatus &&
          other.rawJson == this.rawJson);
}

class LocalHomeworkDraftsCompanion extends UpdateCompanion<LocalHomeworkDraft> {
  final Value<String> localId;
  final Value<String> accountKey;
  final Value<String?> serverId;
  final Value<String> title;
  final Value<String> subject;
  final Value<String> className;
  final Value<String> sectionId;
  final Value<String> teacherId;
  final Value<String> description;
  final Value<String> dueDate;
  final Value<String> studentId;
  final Value<String> attachmentUrl;
  final Value<String> status;
  final Value<DateTime> localUpdatedAt;
  final Value<String> syncStatus;
  final Value<String> rawJson;
  final Value<int> rowid;
  const LocalHomeworkDraftsCompanion({
    this.localId = const Value.absent(),
    this.accountKey = const Value.absent(),
    this.serverId = const Value.absent(),
    this.title = const Value.absent(),
    this.subject = const Value.absent(),
    this.className = const Value.absent(),
    this.sectionId = const Value.absent(),
    this.teacherId = const Value.absent(),
    this.description = const Value.absent(),
    this.dueDate = const Value.absent(),
    this.studentId = const Value.absent(),
    this.attachmentUrl = const Value.absent(),
    this.status = const Value.absent(),
    this.localUpdatedAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.rawJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalHomeworkDraftsCompanion.insert({
    required String localId,
    required String accountKey,
    this.serverId = const Value.absent(),
    required String title,
    this.subject = const Value.absent(),
    this.className = const Value.absent(),
    required String sectionId,
    this.teacherId = const Value.absent(),
    this.description = const Value.absent(),
    this.dueDate = const Value.absent(),
    this.studentId = const Value.absent(),
    this.attachmentUrl = const Value.absent(),
    this.status = const Value.absent(),
    required DateTime localUpdatedAt,
    this.syncStatus = const Value.absent(),
    this.rawJson = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : localId = Value(localId),
       accountKey = Value(accountKey),
       title = Value(title),
       sectionId = Value(sectionId),
       localUpdatedAt = Value(localUpdatedAt);
  static Insertable<LocalHomeworkDraft> custom({
    Expression<String>? localId,
    Expression<String>? accountKey,
    Expression<String>? serverId,
    Expression<String>? title,
    Expression<String>? subject,
    Expression<String>? className,
    Expression<String>? sectionId,
    Expression<String>? teacherId,
    Expression<String>? description,
    Expression<String>? dueDate,
    Expression<String>? studentId,
    Expression<String>? attachmentUrl,
    Expression<String>? status,
    Expression<DateTime>? localUpdatedAt,
    Expression<String>? syncStatus,
    Expression<String>? rawJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (localId != null) 'local_id': localId,
      if (accountKey != null) 'account_key': accountKey,
      if (serverId != null) 'server_id': serverId,
      if (title != null) 'title': title,
      if (subject != null) 'subject': subject,
      if (className != null) 'class_name': className,
      if (sectionId != null) 'section_id': sectionId,
      if (teacherId != null) 'teacher_id': teacherId,
      if (description != null) 'description': description,
      if (dueDate != null) 'due_date': dueDate,
      if (studentId != null) 'student_id': studentId,
      if (attachmentUrl != null) 'attachment_url': attachmentUrl,
      if (status != null) 'status': status,
      if (localUpdatedAt != null) 'local_updated_at': localUpdatedAt,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (rawJson != null) 'raw_json': rawJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalHomeworkDraftsCompanion copyWith({
    Value<String>? localId,
    Value<String>? accountKey,
    Value<String?>? serverId,
    Value<String>? title,
    Value<String>? subject,
    Value<String>? className,
    Value<String>? sectionId,
    Value<String>? teacherId,
    Value<String>? description,
    Value<String>? dueDate,
    Value<String>? studentId,
    Value<String>? attachmentUrl,
    Value<String>? status,
    Value<DateTime>? localUpdatedAt,
    Value<String>? syncStatus,
    Value<String>? rawJson,
    Value<int>? rowid,
  }) {
    return LocalHomeworkDraftsCompanion(
      localId: localId ?? this.localId,
      accountKey: accountKey ?? this.accountKey,
      serverId: serverId ?? this.serverId,
      title: title ?? this.title,
      subject: subject ?? this.subject,
      className: className ?? this.className,
      sectionId: sectionId ?? this.sectionId,
      teacherId: teacherId ?? this.teacherId,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      studentId: studentId ?? this.studentId,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      status: status ?? this.status,
      localUpdatedAt: localUpdatedAt ?? this.localUpdatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      rawJson: rawJson ?? this.rawJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (localId.present) {
      map['local_id'] = Variable<String>(localId.value);
    }
    if (accountKey.present) {
      map['account_key'] = Variable<String>(accountKey.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (subject.present) {
      map['subject'] = Variable<String>(subject.value);
    }
    if (className.present) {
      map['class_name'] = Variable<String>(className.value);
    }
    if (sectionId.present) {
      map['section_id'] = Variable<String>(sectionId.value);
    }
    if (teacherId.present) {
      map['teacher_id'] = Variable<String>(teacherId.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (dueDate.present) {
      map['due_date'] = Variable<String>(dueDate.value);
    }
    if (studentId.present) {
      map['student_id'] = Variable<String>(studentId.value);
    }
    if (attachmentUrl.present) {
      map['attachment_url'] = Variable<String>(attachmentUrl.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (localUpdatedAt.present) {
      map['local_updated_at'] = Variable<DateTime>(localUpdatedAt.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (rawJson.present) {
      map['raw_json'] = Variable<String>(rawJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalHomeworkDraftsCompanion(')
          ..write('localId: $localId, ')
          ..write('accountKey: $accountKey, ')
          ..write('serverId: $serverId, ')
          ..write('title: $title, ')
          ..write('subject: $subject, ')
          ..write('className: $className, ')
          ..write('sectionId: $sectionId, ')
          ..write('teacherId: $teacherId, ')
          ..write('description: $description, ')
          ..write('dueDate: $dueDate, ')
          ..write('studentId: $studentId, ')
          ..write('attachmentUrl: $attachmentUrl, ')
          ..write('status: $status, ')
          ..write('localUpdatedAt: $localUpdatedAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('rawJson: $rawJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$OfflineDatabase extends GeneratedDatabase {
  _$OfflineDatabase(QueryExecutor e) : super(e);
  $OfflineDatabaseManager get managers => $OfflineDatabaseManager(this);
  late final $CachedResponsesTable cachedResponses = $CachedResponsesTable(
    this,
  );
  late final $SyncOutboxEntriesTable syncOutboxEntries =
      $SyncOutboxEntriesTable(this);
  late final $SyncStatesTable syncStates = $SyncStatesTable(this);
  late final $SyncReferencesTable syncReferences = $SyncReferencesTable(this);
  late final $LocalFileUploadsTable localFileUploads = $LocalFileUploadsTable(
    this,
  );
  late final $LocalAttendanceRecordsTable localAttendanceRecords =
      $LocalAttendanceRecordsTable(this);
  late final $LocalAttendanceSessionsTable localAttendanceSessions =
      $LocalAttendanceSessionsTable(this);
  late final $LocalStudentsTable localStudents = $LocalStudentsTable(this);
  late final $LocalHomeworkDraftsTable localHomeworkDrafts =
      $LocalHomeworkDraftsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    cachedResponses,
    syncOutboxEntries,
    syncStates,
    syncReferences,
    localFileUploads,
    localAttendanceRecords,
    localAttendanceSessions,
    localStudents,
    localHomeworkDrafts,
  ];
}

typedef $$CachedResponsesTableCreateCompanionBuilder =
    CachedResponsesCompanion Function({
      required String cacheKey,
      required String accountKey,
      Value<String> method,
      required String path,
      Value<String> queryJson,
      required String bodyJson,
      Value<int> statusCode,
      required DateTime storedAt,
      Value<DateTime?> expiresAt,
      Value<int> rowid,
    });
typedef $$CachedResponsesTableUpdateCompanionBuilder =
    CachedResponsesCompanion Function({
      Value<String> cacheKey,
      Value<String> accountKey,
      Value<String> method,
      Value<String> path,
      Value<String> queryJson,
      Value<String> bodyJson,
      Value<int> statusCode,
      Value<DateTime> storedAt,
      Value<DateTime?> expiresAt,
      Value<int> rowid,
    });

class $$CachedResponsesTableFilterComposer
    extends Composer<_$OfflineDatabase, $CachedResponsesTable> {
  $$CachedResponsesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get cacheKey => $composableBuilder(
    column: $table.cacheKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accountKey => $composableBuilder(
    column: $table.accountKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get method => $composableBuilder(
    column: $table.method,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get queryJson => $composableBuilder(
    column: $table.queryJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bodyJson => $composableBuilder(
    column: $table.bodyJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get statusCode => $composableBuilder(
    column: $table.statusCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get storedAt => $composableBuilder(
    column: $table.storedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedResponsesTableOrderingComposer
    extends Composer<_$OfflineDatabase, $CachedResponsesTable> {
  $$CachedResponsesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get cacheKey => $composableBuilder(
    column: $table.cacheKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accountKey => $composableBuilder(
    column: $table.accountKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get method => $composableBuilder(
    column: $table.method,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get queryJson => $composableBuilder(
    column: $table.queryJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bodyJson => $composableBuilder(
    column: $table.bodyJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get statusCode => $composableBuilder(
    column: $table.statusCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get storedAt => $composableBuilder(
    column: $table.storedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedResponsesTableAnnotationComposer
    extends Composer<_$OfflineDatabase, $CachedResponsesTable> {
  $$CachedResponsesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get cacheKey =>
      $composableBuilder(column: $table.cacheKey, builder: (column) => column);

  GeneratedColumn<String> get accountKey => $composableBuilder(
    column: $table.accountKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get method =>
      $composableBuilder(column: $table.method, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<String> get queryJson =>
      $composableBuilder(column: $table.queryJson, builder: (column) => column);

  GeneratedColumn<String> get bodyJson =>
      $composableBuilder(column: $table.bodyJson, builder: (column) => column);

  GeneratedColumn<int> get statusCode => $composableBuilder(
    column: $table.statusCode,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get storedAt =>
      $composableBuilder(column: $table.storedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);
}

class $$CachedResponsesTableTableManager
    extends
        RootTableManager<
          _$OfflineDatabase,
          $CachedResponsesTable,
          CachedResponse,
          $$CachedResponsesTableFilterComposer,
          $$CachedResponsesTableOrderingComposer,
          $$CachedResponsesTableAnnotationComposer,
          $$CachedResponsesTableCreateCompanionBuilder,
          $$CachedResponsesTableUpdateCompanionBuilder,
          (
            CachedResponse,
            BaseReferences<
              _$OfflineDatabase,
              $CachedResponsesTable,
              CachedResponse
            >,
          ),
          CachedResponse,
          PrefetchHooks Function()
        > {
  $$CachedResponsesTableTableManager(
    _$OfflineDatabase db,
    $CachedResponsesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedResponsesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedResponsesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedResponsesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> cacheKey = const Value.absent(),
                Value<String> accountKey = const Value.absent(),
                Value<String> method = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<String> queryJson = const Value.absent(),
                Value<String> bodyJson = const Value.absent(),
                Value<int> statusCode = const Value.absent(),
                Value<DateTime> storedAt = const Value.absent(),
                Value<DateTime?> expiresAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedResponsesCompanion(
                cacheKey: cacheKey,
                accountKey: accountKey,
                method: method,
                path: path,
                queryJson: queryJson,
                bodyJson: bodyJson,
                statusCode: statusCode,
                storedAt: storedAt,
                expiresAt: expiresAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String cacheKey,
                required String accountKey,
                Value<String> method = const Value.absent(),
                required String path,
                Value<String> queryJson = const Value.absent(),
                required String bodyJson,
                Value<int> statusCode = const Value.absent(),
                required DateTime storedAt,
                Value<DateTime?> expiresAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedResponsesCompanion.insert(
                cacheKey: cacheKey,
                accountKey: accountKey,
                method: method,
                path: path,
                queryJson: queryJson,
                bodyJson: bodyJson,
                statusCode: statusCode,
                storedAt: storedAt,
                expiresAt: expiresAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedResponsesTableProcessedTableManager =
    ProcessedTableManager<
      _$OfflineDatabase,
      $CachedResponsesTable,
      CachedResponse,
      $$CachedResponsesTableFilterComposer,
      $$CachedResponsesTableOrderingComposer,
      $$CachedResponsesTableAnnotationComposer,
      $$CachedResponsesTableCreateCompanionBuilder,
      $$CachedResponsesTableUpdateCompanionBuilder,
      (
        CachedResponse,
        BaseReferences<
          _$OfflineDatabase,
          $CachedResponsesTable,
          CachedResponse
        >,
      ),
      CachedResponse,
      PrefetchHooks Function()
    >;
typedef $$SyncOutboxEntriesTableCreateCompanionBuilder =
    SyncOutboxEntriesCompanion Function({
      Value<int> id,
      required String accountKey,
      required String operationType,
      required String method,
      required String path,
      Value<String> queryJson,
      required String payloadJson,
      required String idempotencyKey,
      required DateTime createdAt,
      Value<int> retryCount,
      Value<String> status,
      Value<String?> lastError,
      Value<DateTime?> nextAttemptAt,
    });
typedef $$SyncOutboxEntriesTableUpdateCompanionBuilder =
    SyncOutboxEntriesCompanion Function({
      Value<int> id,
      Value<String> accountKey,
      Value<String> operationType,
      Value<String> method,
      Value<String> path,
      Value<String> queryJson,
      Value<String> payloadJson,
      Value<String> idempotencyKey,
      Value<DateTime> createdAt,
      Value<int> retryCount,
      Value<String> status,
      Value<String?> lastError,
      Value<DateTime?> nextAttemptAt,
    });

class $$SyncOutboxEntriesTableFilterComposer
    extends Composer<_$OfflineDatabase, $SyncOutboxEntriesTable> {
  $$SyncOutboxEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accountKey => $composableBuilder(
    column: $table.accountKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operationType => $composableBuilder(
    column: $table.operationType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get method => $composableBuilder(
    column: $table.method,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get queryJson => $composableBuilder(
    column: $table.queryJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncOutboxEntriesTableOrderingComposer
    extends Composer<_$OfflineDatabase, $SyncOutboxEntriesTable> {
  $$SyncOutboxEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accountKey => $composableBuilder(
    column: $table.accountKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operationType => $composableBuilder(
    column: $table.operationType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get method => $composableBuilder(
    column: $table.method,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get queryJson => $composableBuilder(
    column: $table.queryJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncOutboxEntriesTableAnnotationComposer
    extends Composer<_$OfflineDatabase, $SyncOutboxEntriesTable> {
  $$SyncOutboxEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get accountKey => $composableBuilder(
    column: $table.accountKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get operationType => $composableBuilder(
    column: $table.operationType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get method =>
      $composableBuilder(column: $table.method, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<String> get queryJson =>
      $composableBuilder(column: $table.queryJson, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => column,
  );
}

class $$SyncOutboxEntriesTableTableManager
    extends
        RootTableManager<
          _$OfflineDatabase,
          $SyncOutboxEntriesTable,
          SyncOutboxEntry,
          $$SyncOutboxEntriesTableFilterComposer,
          $$SyncOutboxEntriesTableOrderingComposer,
          $$SyncOutboxEntriesTableAnnotationComposer,
          $$SyncOutboxEntriesTableCreateCompanionBuilder,
          $$SyncOutboxEntriesTableUpdateCompanionBuilder,
          (
            SyncOutboxEntry,
            BaseReferences<
              _$OfflineDatabase,
              $SyncOutboxEntriesTable,
              SyncOutboxEntry
            >,
          ),
          SyncOutboxEntry,
          PrefetchHooks Function()
        > {
  $$SyncOutboxEntriesTableTableManager(
    _$OfflineDatabase db,
    $SyncOutboxEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncOutboxEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncOutboxEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncOutboxEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> accountKey = const Value.absent(),
                Value<String> operationType = const Value.absent(),
                Value<String> method = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<String> queryJson = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<String> idempotencyKey = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<DateTime?> nextAttemptAt = const Value.absent(),
              }) => SyncOutboxEntriesCompanion(
                id: id,
                accountKey: accountKey,
                operationType: operationType,
                method: method,
                path: path,
                queryJson: queryJson,
                payloadJson: payloadJson,
                idempotencyKey: idempotencyKey,
                createdAt: createdAt,
                retryCount: retryCount,
                status: status,
                lastError: lastError,
                nextAttemptAt: nextAttemptAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String accountKey,
                required String operationType,
                required String method,
                required String path,
                Value<String> queryJson = const Value.absent(),
                required String payloadJson,
                required String idempotencyKey,
                required DateTime createdAt,
                Value<int> retryCount = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<DateTime?> nextAttemptAt = const Value.absent(),
              }) => SyncOutboxEntriesCompanion.insert(
                id: id,
                accountKey: accountKey,
                operationType: operationType,
                method: method,
                path: path,
                queryJson: queryJson,
                payloadJson: payloadJson,
                idempotencyKey: idempotencyKey,
                createdAt: createdAt,
                retryCount: retryCount,
                status: status,
                lastError: lastError,
                nextAttemptAt: nextAttemptAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncOutboxEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$OfflineDatabase,
      $SyncOutboxEntriesTable,
      SyncOutboxEntry,
      $$SyncOutboxEntriesTableFilterComposer,
      $$SyncOutboxEntriesTableOrderingComposer,
      $$SyncOutboxEntriesTableAnnotationComposer,
      $$SyncOutboxEntriesTableCreateCompanionBuilder,
      $$SyncOutboxEntriesTableUpdateCompanionBuilder,
      (
        SyncOutboxEntry,
        BaseReferences<
          _$OfflineDatabase,
          $SyncOutboxEntriesTable,
          SyncOutboxEntry
        >,
      ),
      SyncOutboxEntry,
      PrefetchHooks Function()
    >;
typedef $$SyncStatesTableCreateCompanionBuilder =
    SyncStatesCompanion Function({
      required String accountKey,
      Value<String> status,
      Value<DateTime?> lastAttemptAt,
      Value<DateTime?> lastSyncedAt,
      Value<String?> lastError,
      Value<int> rowid,
    });
typedef $$SyncStatesTableUpdateCompanionBuilder =
    SyncStatesCompanion Function({
      Value<String> accountKey,
      Value<String> status,
      Value<DateTime?> lastAttemptAt,
      Value<DateTime?> lastSyncedAt,
      Value<String?> lastError,
      Value<int> rowid,
    });

class $$SyncStatesTableFilterComposer
    extends Composer<_$OfflineDatabase, $SyncStatesTable> {
  $$SyncStatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get accountKey => $composableBuilder(
    column: $table.accountKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncStatesTableOrderingComposer
    extends Composer<_$OfflineDatabase, $SyncStatesTable> {
  $$SyncStatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get accountKey => $composableBuilder(
    column: $table.accountKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncStatesTableAnnotationComposer
    extends Composer<_$OfflineDatabase, $SyncStatesTable> {
  $$SyncStatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get accountKey => $composableBuilder(
    column: $table.accountKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);
}

class $$SyncStatesTableTableManager
    extends
        RootTableManager<
          _$OfflineDatabase,
          $SyncStatesTable,
          SyncState,
          $$SyncStatesTableFilterComposer,
          $$SyncStatesTableOrderingComposer,
          $$SyncStatesTableAnnotationComposer,
          $$SyncStatesTableCreateCompanionBuilder,
          $$SyncStatesTableUpdateCompanionBuilder,
          (
            SyncState,
            BaseReferences<_$OfflineDatabase, $SyncStatesTable, SyncState>,
          ),
          SyncState,
          PrefetchHooks Function()
        > {
  $$SyncStatesTableTableManager(_$OfflineDatabase db, $SyncStatesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncStatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncStatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncStatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> accountKey = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime?> lastAttemptAt = const Value.absent(),
                Value<DateTime?> lastSyncedAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncStatesCompanion(
                accountKey: accountKey,
                status: status,
                lastAttemptAt: lastAttemptAt,
                lastSyncedAt: lastSyncedAt,
                lastError: lastError,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String accountKey,
                Value<String> status = const Value.absent(),
                Value<DateTime?> lastAttemptAt = const Value.absent(),
                Value<DateTime?> lastSyncedAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncStatesCompanion.insert(
                accountKey: accountKey,
                status: status,
                lastAttemptAt: lastAttemptAt,
                lastSyncedAt: lastSyncedAt,
                lastError: lastError,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncStatesTableProcessedTableManager =
    ProcessedTableManager<
      _$OfflineDatabase,
      $SyncStatesTable,
      SyncState,
      $$SyncStatesTableFilterComposer,
      $$SyncStatesTableOrderingComposer,
      $$SyncStatesTableAnnotationComposer,
      $$SyncStatesTableCreateCompanionBuilder,
      $$SyncStatesTableUpdateCompanionBuilder,
      (
        SyncState,
        BaseReferences<_$OfflineDatabase, $SyncStatesTable, SyncState>,
      ),
      SyncState,
      PrefetchHooks Function()
    >;
typedef $$SyncReferencesTableCreateCompanionBuilder =
    SyncReferencesCompanion Function({
      required String placeholder,
      required String accountKey,
      required String referenceType,
      required String remoteId,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$SyncReferencesTableUpdateCompanionBuilder =
    SyncReferencesCompanion Function({
      Value<String> placeholder,
      Value<String> accountKey,
      Value<String> referenceType,
      Value<String> remoteId,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$SyncReferencesTableFilterComposer
    extends Composer<_$OfflineDatabase, $SyncReferencesTable> {
  $$SyncReferencesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get placeholder => $composableBuilder(
    column: $table.placeholder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accountKey => $composableBuilder(
    column: $table.accountKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get referenceType => $composableBuilder(
    column: $table.referenceType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remoteId => $composableBuilder(
    column: $table.remoteId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncReferencesTableOrderingComposer
    extends Composer<_$OfflineDatabase, $SyncReferencesTable> {
  $$SyncReferencesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get placeholder => $composableBuilder(
    column: $table.placeholder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accountKey => $composableBuilder(
    column: $table.accountKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get referenceType => $composableBuilder(
    column: $table.referenceType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteId => $composableBuilder(
    column: $table.remoteId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncReferencesTableAnnotationComposer
    extends Composer<_$OfflineDatabase, $SyncReferencesTable> {
  $$SyncReferencesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get placeholder => $composableBuilder(
    column: $table.placeholder,
    builder: (column) => column,
  );

  GeneratedColumn<String> get accountKey => $composableBuilder(
    column: $table.accountKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get referenceType => $composableBuilder(
    column: $table.referenceType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get remoteId =>
      $composableBuilder(column: $table.remoteId, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$SyncReferencesTableTableManager
    extends
        RootTableManager<
          _$OfflineDatabase,
          $SyncReferencesTable,
          SyncReference,
          $$SyncReferencesTableFilterComposer,
          $$SyncReferencesTableOrderingComposer,
          $$SyncReferencesTableAnnotationComposer,
          $$SyncReferencesTableCreateCompanionBuilder,
          $$SyncReferencesTableUpdateCompanionBuilder,
          (
            SyncReference,
            BaseReferences<
              _$OfflineDatabase,
              $SyncReferencesTable,
              SyncReference
            >,
          ),
          SyncReference,
          PrefetchHooks Function()
        > {
  $$SyncReferencesTableTableManager(
    _$OfflineDatabase db,
    $SyncReferencesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncReferencesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncReferencesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncReferencesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> placeholder = const Value.absent(),
                Value<String> accountKey = const Value.absent(),
                Value<String> referenceType = const Value.absent(),
                Value<String> remoteId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncReferencesCompanion(
                placeholder: placeholder,
                accountKey: accountKey,
                referenceType: referenceType,
                remoteId: remoteId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String placeholder,
                required String accountKey,
                required String referenceType,
                required String remoteId,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => SyncReferencesCompanion.insert(
                placeholder: placeholder,
                accountKey: accountKey,
                referenceType: referenceType,
                remoteId: remoteId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncReferencesTableProcessedTableManager =
    ProcessedTableManager<
      _$OfflineDatabase,
      $SyncReferencesTable,
      SyncReference,
      $$SyncReferencesTableFilterComposer,
      $$SyncReferencesTableOrderingComposer,
      $$SyncReferencesTableAnnotationComposer,
      $$SyncReferencesTableCreateCompanionBuilder,
      $$SyncReferencesTableUpdateCompanionBuilder,
      (
        SyncReference,
        BaseReferences<_$OfflineDatabase, $SyncReferencesTable, SyncReference>,
      ),
      SyncReference,
      PrefetchHooks Function()
    >;
typedef $$LocalFileUploadsTableCreateCompanionBuilder =
    LocalFileUploadsCompanion Function({
      required String localId,
      required String accountKey,
      Value<String> method,
      required String path,
      Value<String> fieldsJson,
      required String fieldName,
      required String fileName,
      Value<String?> mimeType,
      Value<String?> filePath,
      Value<Uint8List?> fileBytes,
      required String placeholder,
      required String idempotencyKey,
      required DateTime createdAt,
      Value<int> retryCount,
      Value<String> status,
      Value<String?> lastError,
      Value<DateTime?> nextAttemptAt,
      Value<String?> remoteUrl,
      Value<int> rowid,
    });
typedef $$LocalFileUploadsTableUpdateCompanionBuilder =
    LocalFileUploadsCompanion Function({
      Value<String> localId,
      Value<String> accountKey,
      Value<String> method,
      Value<String> path,
      Value<String> fieldsJson,
      Value<String> fieldName,
      Value<String> fileName,
      Value<String?> mimeType,
      Value<String?> filePath,
      Value<Uint8List?> fileBytes,
      Value<String> placeholder,
      Value<String> idempotencyKey,
      Value<DateTime> createdAt,
      Value<int> retryCount,
      Value<String> status,
      Value<String?> lastError,
      Value<DateTime?> nextAttemptAt,
      Value<String?> remoteUrl,
      Value<int> rowid,
    });

class $$LocalFileUploadsTableFilterComposer
    extends Composer<_$OfflineDatabase, $LocalFileUploadsTable> {
  $$LocalFileUploadsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get localId => $composableBuilder(
    column: $table.localId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accountKey => $composableBuilder(
    column: $table.accountKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get method => $composableBuilder(
    column: $table.method,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fieldsJson => $composableBuilder(
    column: $table.fieldsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fieldName => $composableBuilder(
    column: $table.fieldName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get fileBytes => $composableBuilder(
    column: $table.fileBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get placeholder => $composableBuilder(
    column: $table.placeholder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remoteUrl => $composableBuilder(
    column: $table.remoteUrl,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalFileUploadsTableOrderingComposer
    extends Composer<_$OfflineDatabase, $LocalFileUploadsTable> {
  $$LocalFileUploadsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get localId => $composableBuilder(
    column: $table.localId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accountKey => $composableBuilder(
    column: $table.accountKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get method => $composableBuilder(
    column: $table.method,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fieldsJson => $composableBuilder(
    column: $table.fieldsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fieldName => $composableBuilder(
    column: $table.fieldName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get fileBytes => $composableBuilder(
    column: $table.fileBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get placeholder => $composableBuilder(
    column: $table.placeholder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteUrl => $composableBuilder(
    column: $table.remoteUrl,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalFileUploadsTableAnnotationComposer
    extends Composer<_$OfflineDatabase, $LocalFileUploadsTable> {
  $$LocalFileUploadsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get localId =>
      $composableBuilder(column: $table.localId, builder: (column) => column);

  GeneratedColumn<String> get accountKey => $composableBuilder(
    column: $table.accountKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get method =>
      $composableBuilder(column: $table.method, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<String> get fieldsJson => $composableBuilder(
    column: $table.fieldsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fieldName =>
      $composableBuilder(column: $table.fieldName, builder: (column) => column);

  GeneratedColumn<String> get fileName =>
      $composableBuilder(column: $table.fileName, builder: (column) => column);

  GeneratedColumn<String> get mimeType =>
      $composableBuilder(column: $table.mimeType, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<Uint8List> get fileBytes =>
      $composableBuilder(column: $table.fileBytes, builder: (column) => column);

  GeneratedColumn<String> get placeholder => $composableBuilder(
    column: $table.placeholder,
    builder: (column) => column,
  );

  GeneratedColumn<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get remoteUrl =>
      $composableBuilder(column: $table.remoteUrl, builder: (column) => column);
}

class $$LocalFileUploadsTableTableManager
    extends
        RootTableManager<
          _$OfflineDatabase,
          $LocalFileUploadsTable,
          LocalFileUpload,
          $$LocalFileUploadsTableFilterComposer,
          $$LocalFileUploadsTableOrderingComposer,
          $$LocalFileUploadsTableAnnotationComposer,
          $$LocalFileUploadsTableCreateCompanionBuilder,
          $$LocalFileUploadsTableUpdateCompanionBuilder,
          (
            LocalFileUpload,
            BaseReferences<
              _$OfflineDatabase,
              $LocalFileUploadsTable,
              LocalFileUpload
            >,
          ),
          LocalFileUpload,
          PrefetchHooks Function()
        > {
  $$LocalFileUploadsTableTableManager(
    _$OfflineDatabase db,
    $LocalFileUploadsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalFileUploadsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalFileUploadsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalFileUploadsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> localId = const Value.absent(),
                Value<String> accountKey = const Value.absent(),
                Value<String> method = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<String> fieldsJson = const Value.absent(),
                Value<String> fieldName = const Value.absent(),
                Value<String> fileName = const Value.absent(),
                Value<String?> mimeType = const Value.absent(),
                Value<String?> filePath = const Value.absent(),
                Value<Uint8List?> fileBytes = const Value.absent(),
                Value<String> placeholder = const Value.absent(),
                Value<String> idempotencyKey = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<DateTime?> nextAttemptAt = const Value.absent(),
                Value<String?> remoteUrl = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalFileUploadsCompanion(
                localId: localId,
                accountKey: accountKey,
                method: method,
                path: path,
                fieldsJson: fieldsJson,
                fieldName: fieldName,
                fileName: fileName,
                mimeType: mimeType,
                filePath: filePath,
                fileBytes: fileBytes,
                placeholder: placeholder,
                idempotencyKey: idempotencyKey,
                createdAt: createdAt,
                retryCount: retryCount,
                status: status,
                lastError: lastError,
                nextAttemptAt: nextAttemptAt,
                remoteUrl: remoteUrl,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String localId,
                required String accountKey,
                Value<String> method = const Value.absent(),
                required String path,
                Value<String> fieldsJson = const Value.absent(),
                required String fieldName,
                required String fileName,
                Value<String?> mimeType = const Value.absent(),
                Value<String?> filePath = const Value.absent(),
                Value<Uint8List?> fileBytes = const Value.absent(),
                required String placeholder,
                required String idempotencyKey,
                required DateTime createdAt,
                Value<int> retryCount = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<DateTime?> nextAttemptAt = const Value.absent(),
                Value<String?> remoteUrl = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalFileUploadsCompanion.insert(
                localId: localId,
                accountKey: accountKey,
                method: method,
                path: path,
                fieldsJson: fieldsJson,
                fieldName: fieldName,
                fileName: fileName,
                mimeType: mimeType,
                filePath: filePath,
                fileBytes: fileBytes,
                placeholder: placeholder,
                idempotencyKey: idempotencyKey,
                createdAt: createdAt,
                retryCount: retryCount,
                status: status,
                lastError: lastError,
                nextAttemptAt: nextAttemptAt,
                remoteUrl: remoteUrl,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalFileUploadsTableProcessedTableManager =
    ProcessedTableManager<
      _$OfflineDatabase,
      $LocalFileUploadsTable,
      LocalFileUpload,
      $$LocalFileUploadsTableFilterComposer,
      $$LocalFileUploadsTableOrderingComposer,
      $$LocalFileUploadsTableAnnotationComposer,
      $$LocalFileUploadsTableCreateCompanionBuilder,
      $$LocalFileUploadsTableUpdateCompanionBuilder,
      (
        LocalFileUpload,
        BaseReferences<
          _$OfflineDatabase,
          $LocalFileUploadsTable,
          LocalFileUpload
        >,
      ),
      LocalFileUpload,
      PrefetchHooks Function()
    >;
typedef $$LocalAttendanceRecordsTableCreateCompanionBuilder =
    LocalAttendanceRecordsCompanion Function({
      required String localId,
      required String accountKey,
      Value<String?> serverId,
      Value<String?> schoolId,
      required String studentId,
      Value<String> studentName,
      Value<String> className,
      Value<String> section,
      required String date,
      required String attendanceStatus,
      Value<String> remarks,
      Value<String?> markedBy,
      Value<DateTime?> markedAt,
      Value<DateTime?> updatedAt,
      required DateTime localUpdatedAt,
      Value<String> syncStatus,
      Value<int?> serverVersion,
      Value<String> rawJson,
      Value<int> rowid,
    });
typedef $$LocalAttendanceRecordsTableUpdateCompanionBuilder =
    LocalAttendanceRecordsCompanion Function({
      Value<String> localId,
      Value<String> accountKey,
      Value<String?> serverId,
      Value<String?> schoolId,
      Value<String> studentId,
      Value<String> studentName,
      Value<String> className,
      Value<String> section,
      Value<String> date,
      Value<String> attendanceStatus,
      Value<String> remarks,
      Value<String?> markedBy,
      Value<DateTime?> markedAt,
      Value<DateTime?> updatedAt,
      Value<DateTime> localUpdatedAt,
      Value<String> syncStatus,
      Value<int?> serverVersion,
      Value<String> rawJson,
      Value<int> rowid,
    });

class $$LocalAttendanceRecordsTableFilterComposer
    extends Composer<_$OfflineDatabase, $LocalAttendanceRecordsTable> {
  $$LocalAttendanceRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get localId => $composableBuilder(
    column: $table.localId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accountKey => $composableBuilder(
    column: $table.accountKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get schoolId => $composableBuilder(
    column: $table.schoolId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get studentId => $composableBuilder(
    column: $table.studentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get studentName => $composableBuilder(
    column: $table.studentName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get className => $composableBuilder(
    column: $table.className,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get section => $composableBuilder(
    column: $table.section,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get attendanceStatus => $composableBuilder(
    column: $table.attendanceStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remarks => $composableBuilder(
    column: $table.remarks,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get markedBy => $composableBuilder(
    column: $table.markedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get markedAt => $composableBuilder(
    column: $table.markedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get localUpdatedAt => $composableBuilder(
    column: $table.localUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rawJson => $composableBuilder(
    column: $table.rawJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalAttendanceRecordsTableOrderingComposer
    extends Composer<_$OfflineDatabase, $LocalAttendanceRecordsTable> {
  $$LocalAttendanceRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get localId => $composableBuilder(
    column: $table.localId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accountKey => $composableBuilder(
    column: $table.accountKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get schoolId => $composableBuilder(
    column: $table.schoolId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get studentId => $composableBuilder(
    column: $table.studentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get studentName => $composableBuilder(
    column: $table.studentName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get className => $composableBuilder(
    column: $table.className,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get section => $composableBuilder(
    column: $table.section,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get attendanceStatus => $composableBuilder(
    column: $table.attendanceStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remarks => $composableBuilder(
    column: $table.remarks,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get markedBy => $composableBuilder(
    column: $table.markedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get markedAt => $composableBuilder(
    column: $table.markedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get localUpdatedAt => $composableBuilder(
    column: $table.localUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rawJson => $composableBuilder(
    column: $table.rawJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalAttendanceRecordsTableAnnotationComposer
    extends Composer<_$OfflineDatabase, $LocalAttendanceRecordsTable> {
  $$LocalAttendanceRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get localId =>
      $composableBuilder(column: $table.localId, builder: (column) => column);

  GeneratedColumn<String> get accountKey => $composableBuilder(
    column: $table.accountKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get schoolId =>
      $composableBuilder(column: $table.schoolId, builder: (column) => column);

  GeneratedColumn<String> get studentId =>
      $composableBuilder(column: $table.studentId, builder: (column) => column);

  GeneratedColumn<String> get studentName => $composableBuilder(
    column: $table.studentName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get className =>
      $composableBuilder(column: $table.className, builder: (column) => column);

  GeneratedColumn<String> get section =>
      $composableBuilder(column: $table.section, builder: (column) => column);

  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get attendanceStatus => $composableBuilder(
    column: $table.attendanceStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get remarks =>
      $composableBuilder(column: $table.remarks, builder: (column) => column);

  GeneratedColumn<String> get markedBy =>
      $composableBuilder(column: $table.markedBy, builder: (column) => column);

  GeneratedColumn<DateTime> get markedAt =>
      $composableBuilder(column: $table.markedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get localUpdatedAt => $composableBuilder(
    column: $table.localUpdatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  GeneratedColumn<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rawJson =>
      $composableBuilder(column: $table.rawJson, builder: (column) => column);
}

class $$LocalAttendanceRecordsTableTableManager
    extends
        RootTableManager<
          _$OfflineDatabase,
          $LocalAttendanceRecordsTable,
          LocalAttendanceRecord,
          $$LocalAttendanceRecordsTableFilterComposer,
          $$LocalAttendanceRecordsTableOrderingComposer,
          $$LocalAttendanceRecordsTableAnnotationComposer,
          $$LocalAttendanceRecordsTableCreateCompanionBuilder,
          $$LocalAttendanceRecordsTableUpdateCompanionBuilder,
          (
            LocalAttendanceRecord,
            BaseReferences<
              _$OfflineDatabase,
              $LocalAttendanceRecordsTable,
              LocalAttendanceRecord
            >,
          ),
          LocalAttendanceRecord,
          PrefetchHooks Function()
        > {
  $$LocalAttendanceRecordsTableTableManager(
    _$OfflineDatabase db,
    $LocalAttendanceRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalAttendanceRecordsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$LocalAttendanceRecordsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LocalAttendanceRecordsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> localId = const Value.absent(),
                Value<String> accountKey = const Value.absent(),
                Value<String?> serverId = const Value.absent(),
                Value<String?> schoolId = const Value.absent(),
                Value<String> studentId = const Value.absent(),
                Value<String> studentName = const Value.absent(),
                Value<String> className = const Value.absent(),
                Value<String> section = const Value.absent(),
                Value<String> date = const Value.absent(),
                Value<String> attendanceStatus = const Value.absent(),
                Value<String> remarks = const Value.absent(),
                Value<String?> markedBy = const Value.absent(),
                Value<DateTime?> markedAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<DateTime> localUpdatedAt = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<int?> serverVersion = const Value.absent(),
                Value<String> rawJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalAttendanceRecordsCompanion(
                localId: localId,
                accountKey: accountKey,
                serverId: serverId,
                schoolId: schoolId,
                studentId: studentId,
                studentName: studentName,
                className: className,
                section: section,
                date: date,
                attendanceStatus: attendanceStatus,
                remarks: remarks,
                markedBy: markedBy,
                markedAt: markedAt,
                updatedAt: updatedAt,
                localUpdatedAt: localUpdatedAt,
                syncStatus: syncStatus,
                serverVersion: serverVersion,
                rawJson: rawJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String localId,
                required String accountKey,
                Value<String?> serverId = const Value.absent(),
                Value<String?> schoolId = const Value.absent(),
                required String studentId,
                Value<String> studentName = const Value.absent(),
                Value<String> className = const Value.absent(),
                Value<String> section = const Value.absent(),
                required String date,
                required String attendanceStatus,
                Value<String> remarks = const Value.absent(),
                Value<String?> markedBy = const Value.absent(),
                Value<DateTime?> markedAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                required DateTime localUpdatedAt,
                Value<String> syncStatus = const Value.absent(),
                Value<int?> serverVersion = const Value.absent(),
                Value<String> rawJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalAttendanceRecordsCompanion.insert(
                localId: localId,
                accountKey: accountKey,
                serverId: serverId,
                schoolId: schoolId,
                studentId: studentId,
                studentName: studentName,
                className: className,
                section: section,
                date: date,
                attendanceStatus: attendanceStatus,
                remarks: remarks,
                markedBy: markedBy,
                markedAt: markedAt,
                updatedAt: updatedAt,
                localUpdatedAt: localUpdatedAt,
                syncStatus: syncStatus,
                serverVersion: serverVersion,
                rawJson: rawJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalAttendanceRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$OfflineDatabase,
      $LocalAttendanceRecordsTable,
      LocalAttendanceRecord,
      $$LocalAttendanceRecordsTableFilterComposer,
      $$LocalAttendanceRecordsTableOrderingComposer,
      $$LocalAttendanceRecordsTableAnnotationComposer,
      $$LocalAttendanceRecordsTableCreateCompanionBuilder,
      $$LocalAttendanceRecordsTableUpdateCompanionBuilder,
      (
        LocalAttendanceRecord,
        BaseReferences<
          _$OfflineDatabase,
          $LocalAttendanceRecordsTable,
          LocalAttendanceRecord
        >,
      ),
      LocalAttendanceRecord,
      PrefetchHooks Function()
    >;
typedef $$LocalAttendanceSessionsTableCreateCompanionBuilder =
    LocalAttendanceSessionsCompanion Function({
      required String localId,
      required String accountKey,
      Value<String?> serverId,
      required String sectionId,
      required String academicYearId,
      Value<String> subjectId,
      Value<String> staffId,
      required String date,
      Value<int> periodNumber,
      Value<String> timetableSlotId,
      Value<String> status,
      Value<bool> isFinalized,
      Value<String> studentAttendancesJson,
      required DateTime localUpdatedAt,
      Value<String> syncStatus,
      Value<int> rowid,
    });
typedef $$LocalAttendanceSessionsTableUpdateCompanionBuilder =
    LocalAttendanceSessionsCompanion Function({
      Value<String> localId,
      Value<String> accountKey,
      Value<String?> serverId,
      Value<String> sectionId,
      Value<String> academicYearId,
      Value<String> subjectId,
      Value<String> staffId,
      Value<String> date,
      Value<int> periodNumber,
      Value<String> timetableSlotId,
      Value<String> status,
      Value<bool> isFinalized,
      Value<String> studentAttendancesJson,
      Value<DateTime> localUpdatedAt,
      Value<String> syncStatus,
      Value<int> rowid,
    });

class $$LocalAttendanceSessionsTableFilterComposer
    extends Composer<_$OfflineDatabase, $LocalAttendanceSessionsTable> {
  $$LocalAttendanceSessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get localId => $composableBuilder(
    column: $table.localId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accountKey => $composableBuilder(
    column: $table.accountKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sectionId => $composableBuilder(
    column: $table.sectionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get academicYearId => $composableBuilder(
    column: $table.academicYearId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get staffId => $composableBuilder(
    column: $table.staffId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get periodNumber => $composableBuilder(
    column: $table.periodNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get timetableSlotId => $composableBuilder(
    column: $table.timetableSlotId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isFinalized => $composableBuilder(
    column: $table.isFinalized,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get studentAttendancesJson => $composableBuilder(
    column: $table.studentAttendancesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get localUpdatedAt => $composableBuilder(
    column: $table.localUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalAttendanceSessionsTableOrderingComposer
    extends Composer<_$OfflineDatabase, $LocalAttendanceSessionsTable> {
  $$LocalAttendanceSessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get localId => $composableBuilder(
    column: $table.localId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accountKey => $composableBuilder(
    column: $table.accountKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sectionId => $composableBuilder(
    column: $table.sectionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get academicYearId => $composableBuilder(
    column: $table.academicYearId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get staffId => $composableBuilder(
    column: $table.staffId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get periodNumber => $composableBuilder(
    column: $table.periodNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get timetableSlotId => $composableBuilder(
    column: $table.timetableSlotId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isFinalized => $composableBuilder(
    column: $table.isFinalized,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get studentAttendancesJson => $composableBuilder(
    column: $table.studentAttendancesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get localUpdatedAt => $composableBuilder(
    column: $table.localUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalAttendanceSessionsTableAnnotationComposer
    extends Composer<_$OfflineDatabase, $LocalAttendanceSessionsTable> {
  $$LocalAttendanceSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get localId =>
      $composableBuilder(column: $table.localId, builder: (column) => column);

  GeneratedColumn<String> get accountKey => $composableBuilder(
    column: $table.accountKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get sectionId =>
      $composableBuilder(column: $table.sectionId, builder: (column) => column);

  GeneratedColumn<String> get academicYearId => $composableBuilder(
    column: $table.academicYearId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get subjectId =>
      $composableBuilder(column: $table.subjectId, builder: (column) => column);

  GeneratedColumn<String> get staffId =>
      $composableBuilder(column: $table.staffId, builder: (column) => column);

  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<int> get periodNumber => $composableBuilder(
    column: $table.periodNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get timetableSlotId => $composableBuilder(
    column: $table.timetableSlotId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<bool> get isFinalized => $composableBuilder(
    column: $table.isFinalized,
    builder: (column) => column,
  );

  GeneratedColumn<String> get studentAttendancesJson => $composableBuilder(
    column: $table.studentAttendancesJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get localUpdatedAt => $composableBuilder(
    column: $table.localUpdatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );
}

class $$LocalAttendanceSessionsTableTableManager
    extends
        RootTableManager<
          _$OfflineDatabase,
          $LocalAttendanceSessionsTable,
          LocalAttendanceSession,
          $$LocalAttendanceSessionsTableFilterComposer,
          $$LocalAttendanceSessionsTableOrderingComposer,
          $$LocalAttendanceSessionsTableAnnotationComposer,
          $$LocalAttendanceSessionsTableCreateCompanionBuilder,
          $$LocalAttendanceSessionsTableUpdateCompanionBuilder,
          (
            LocalAttendanceSession,
            BaseReferences<
              _$OfflineDatabase,
              $LocalAttendanceSessionsTable,
              LocalAttendanceSession
            >,
          ),
          LocalAttendanceSession,
          PrefetchHooks Function()
        > {
  $$LocalAttendanceSessionsTableTableManager(
    _$OfflineDatabase db,
    $LocalAttendanceSessionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalAttendanceSessionsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$LocalAttendanceSessionsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LocalAttendanceSessionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> localId = const Value.absent(),
                Value<String> accountKey = const Value.absent(),
                Value<String?> serverId = const Value.absent(),
                Value<String> sectionId = const Value.absent(),
                Value<String> academicYearId = const Value.absent(),
                Value<String> subjectId = const Value.absent(),
                Value<String> staffId = const Value.absent(),
                Value<String> date = const Value.absent(),
                Value<int> periodNumber = const Value.absent(),
                Value<String> timetableSlotId = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<bool> isFinalized = const Value.absent(),
                Value<String> studentAttendancesJson = const Value.absent(),
                Value<DateTime> localUpdatedAt = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalAttendanceSessionsCompanion(
                localId: localId,
                accountKey: accountKey,
                serverId: serverId,
                sectionId: sectionId,
                academicYearId: academicYearId,
                subjectId: subjectId,
                staffId: staffId,
                date: date,
                periodNumber: periodNumber,
                timetableSlotId: timetableSlotId,
                status: status,
                isFinalized: isFinalized,
                studentAttendancesJson: studentAttendancesJson,
                localUpdatedAt: localUpdatedAt,
                syncStatus: syncStatus,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String localId,
                required String accountKey,
                Value<String?> serverId = const Value.absent(),
                required String sectionId,
                required String academicYearId,
                Value<String> subjectId = const Value.absent(),
                Value<String> staffId = const Value.absent(),
                required String date,
                Value<int> periodNumber = const Value.absent(),
                Value<String> timetableSlotId = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<bool> isFinalized = const Value.absent(),
                Value<String> studentAttendancesJson = const Value.absent(),
                required DateTime localUpdatedAt,
                Value<String> syncStatus = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalAttendanceSessionsCompanion.insert(
                localId: localId,
                accountKey: accountKey,
                serverId: serverId,
                sectionId: sectionId,
                academicYearId: academicYearId,
                subjectId: subjectId,
                staffId: staffId,
                date: date,
                periodNumber: periodNumber,
                timetableSlotId: timetableSlotId,
                status: status,
                isFinalized: isFinalized,
                studentAttendancesJson: studentAttendancesJson,
                localUpdatedAt: localUpdatedAt,
                syncStatus: syncStatus,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalAttendanceSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$OfflineDatabase,
      $LocalAttendanceSessionsTable,
      LocalAttendanceSession,
      $$LocalAttendanceSessionsTableFilterComposer,
      $$LocalAttendanceSessionsTableOrderingComposer,
      $$LocalAttendanceSessionsTableAnnotationComposer,
      $$LocalAttendanceSessionsTableCreateCompanionBuilder,
      $$LocalAttendanceSessionsTableUpdateCompanionBuilder,
      (
        LocalAttendanceSession,
        BaseReferences<
          _$OfflineDatabase,
          $LocalAttendanceSessionsTable,
          LocalAttendanceSession
        >,
      ),
      LocalAttendanceSession,
      PrefetchHooks Function()
    >;
typedef $$LocalStudentsTableCreateCompanionBuilder =
    LocalStudentsCompanion Function({
      required String serverId,
      required String accountKey,
      Value<String?> schoolId,
      required String fullName,
      Value<String?> sectionId,
      Value<String> className,
      Value<String> sectionName,
      Value<String> status,
      Value<DateTime?> updatedAt,
      required DateTime localUpdatedAt,
      Value<int?> serverVersion,
      Value<String> rawJson,
      Value<int> rowid,
    });
typedef $$LocalStudentsTableUpdateCompanionBuilder =
    LocalStudentsCompanion Function({
      Value<String> serverId,
      Value<String> accountKey,
      Value<String?> schoolId,
      Value<String> fullName,
      Value<String?> sectionId,
      Value<String> className,
      Value<String> sectionName,
      Value<String> status,
      Value<DateTime?> updatedAt,
      Value<DateTime> localUpdatedAt,
      Value<int?> serverVersion,
      Value<String> rawJson,
      Value<int> rowid,
    });

class $$LocalStudentsTableFilterComposer
    extends Composer<_$OfflineDatabase, $LocalStudentsTable> {
  $$LocalStudentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accountKey => $composableBuilder(
    column: $table.accountKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get schoolId => $composableBuilder(
    column: $table.schoolId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fullName => $composableBuilder(
    column: $table.fullName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sectionId => $composableBuilder(
    column: $table.sectionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get className => $composableBuilder(
    column: $table.className,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sectionName => $composableBuilder(
    column: $table.sectionName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get localUpdatedAt => $composableBuilder(
    column: $table.localUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rawJson => $composableBuilder(
    column: $table.rawJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalStudentsTableOrderingComposer
    extends Composer<_$OfflineDatabase, $LocalStudentsTable> {
  $$LocalStudentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accountKey => $composableBuilder(
    column: $table.accountKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get schoolId => $composableBuilder(
    column: $table.schoolId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fullName => $composableBuilder(
    column: $table.fullName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sectionId => $composableBuilder(
    column: $table.sectionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get className => $composableBuilder(
    column: $table.className,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sectionName => $composableBuilder(
    column: $table.sectionName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get localUpdatedAt => $composableBuilder(
    column: $table.localUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rawJson => $composableBuilder(
    column: $table.rawJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalStudentsTableAnnotationComposer
    extends Composer<_$OfflineDatabase, $LocalStudentsTable> {
  $$LocalStudentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get accountKey => $composableBuilder(
    column: $table.accountKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get schoolId =>
      $composableBuilder(column: $table.schoolId, builder: (column) => column);

  GeneratedColumn<String> get fullName =>
      $composableBuilder(column: $table.fullName, builder: (column) => column);

  GeneratedColumn<String> get sectionId =>
      $composableBuilder(column: $table.sectionId, builder: (column) => column);

  GeneratedColumn<String> get className =>
      $composableBuilder(column: $table.className, builder: (column) => column);

  GeneratedColumn<String> get sectionName => $composableBuilder(
    column: $table.sectionName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get localUpdatedAt => $composableBuilder(
    column: $table.localUpdatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rawJson =>
      $composableBuilder(column: $table.rawJson, builder: (column) => column);
}

class $$LocalStudentsTableTableManager
    extends
        RootTableManager<
          _$OfflineDatabase,
          $LocalStudentsTable,
          LocalStudent,
          $$LocalStudentsTableFilterComposer,
          $$LocalStudentsTableOrderingComposer,
          $$LocalStudentsTableAnnotationComposer,
          $$LocalStudentsTableCreateCompanionBuilder,
          $$LocalStudentsTableUpdateCompanionBuilder,
          (
            LocalStudent,
            BaseReferences<
              _$OfflineDatabase,
              $LocalStudentsTable,
              LocalStudent
            >,
          ),
          LocalStudent,
          PrefetchHooks Function()
        > {
  $$LocalStudentsTableTableManager(
    _$OfflineDatabase db,
    $LocalStudentsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalStudentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalStudentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalStudentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> serverId = const Value.absent(),
                Value<String> accountKey = const Value.absent(),
                Value<String?> schoolId = const Value.absent(),
                Value<String> fullName = const Value.absent(),
                Value<String?> sectionId = const Value.absent(),
                Value<String> className = const Value.absent(),
                Value<String> sectionName = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<DateTime> localUpdatedAt = const Value.absent(),
                Value<int?> serverVersion = const Value.absent(),
                Value<String> rawJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalStudentsCompanion(
                serverId: serverId,
                accountKey: accountKey,
                schoolId: schoolId,
                fullName: fullName,
                sectionId: sectionId,
                className: className,
                sectionName: sectionName,
                status: status,
                updatedAt: updatedAt,
                localUpdatedAt: localUpdatedAt,
                serverVersion: serverVersion,
                rawJson: rawJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String serverId,
                required String accountKey,
                Value<String?> schoolId = const Value.absent(),
                required String fullName,
                Value<String?> sectionId = const Value.absent(),
                Value<String> className = const Value.absent(),
                Value<String> sectionName = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                required DateTime localUpdatedAt,
                Value<int?> serverVersion = const Value.absent(),
                Value<String> rawJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalStudentsCompanion.insert(
                serverId: serverId,
                accountKey: accountKey,
                schoolId: schoolId,
                fullName: fullName,
                sectionId: sectionId,
                className: className,
                sectionName: sectionName,
                status: status,
                updatedAt: updatedAt,
                localUpdatedAt: localUpdatedAt,
                serverVersion: serverVersion,
                rawJson: rawJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalStudentsTableProcessedTableManager =
    ProcessedTableManager<
      _$OfflineDatabase,
      $LocalStudentsTable,
      LocalStudent,
      $$LocalStudentsTableFilterComposer,
      $$LocalStudentsTableOrderingComposer,
      $$LocalStudentsTableAnnotationComposer,
      $$LocalStudentsTableCreateCompanionBuilder,
      $$LocalStudentsTableUpdateCompanionBuilder,
      (
        LocalStudent,
        BaseReferences<_$OfflineDatabase, $LocalStudentsTable, LocalStudent>,
      ),
      LocalStudent,
      PrefetchHooks Function()
    >;
typedef $$LocalHomeworkDraftsTableCreateCompanionBuilder =
    LocalHomeworkDraftsCompanion Function({
      required String localId,
      required String accountKey,
      Value<String?> serverId,
      required String title,
      Value<String> subject,
      Value<String> className,
      required String sectionId,
      Value<String> teacherId,
      Value<String> description,
      Value<String> dueDate,
      Value<String> studentId,
      Value<String> attachmentUrl,
      Value<String> status,
      required DateTime localUpdatedAt,
      Value<String> syncStatus,
      Value<String> rawJson,
      Value<int> rowid,
    });
typedef $$LocalHomeworkDraftsTableUpdateCompanionBuilder =
    LocalHomeworkDraftsCompanion Function({
      Value<String> localId,
      Value<String> accountKey,
      Value<String?> serverId,
      Value<String> title,
      Value<String> subject,
      Value<String> className,
      Value<String> sectionId,
      Value<String> teacherId,
      Value<String> description,
      Value<String> dueDate,
      Value<String> studentId,
      Value<String> attachmentUrl,
      Value<String> status,
      Value<DateTime> localUpdatedAt,
      Value<String> syncStatus,
      Value<String> rawJson,
      Value<int> rowid,
    });

class $$LocalHomeworkDraftsTableFilterComposer
    extends Composer<_$OfflineDatabase, $LocalHomeworkDraftsTable> {
  $$LocalHomeworkDraftsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get localId => $composableBuilder(
    column: $table.localId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accountKey => $composableBuilder(
    column: $table.accountKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subject => $composableBuilder(
    column: $table.subject,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get className => $composableBuilder(
    column: $table.className,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sectionId => $composableBuilder(
    column: $table.sectionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get teacherId => $composableBuilder(
    column: $table.teacherId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get studentId => $composableBuilder(
    column: $table.studentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get attachmentUrl => $composableBuilder(
    column: $table.attachmentUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get localUpdatedAt => $composableBuilder(
    column: $table.localUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rawJson => $composableBuilder(
    column: $table.rawJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalHomeworkDraftsTableOrderingComposer
    extends Composer<_$OfflineDatabase, $LocalHomeworkDraftsTable> {
  $$LocalHomeworkDraftsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get localId => $composableBuilder(
    column: $table.localId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accountKey => $composableBuilder(
    column: $table.accountKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subject => $composableBuilder(
    column: $table.subject,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get className => $composableBuilder(
    column: $table.className,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sectionId => $composableBuilder(
    column: $table.sectionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get teacherId => $composableBuilder(
    column: $table.teacherId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get studentId => $composableBuilder(
    column: $table.studentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get attachmentUrl => $composableBuilder(
    column: $table.attachmentUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get localUpdatedAt => $composableBuilder(
    column: $table.localUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rawJson => $composableBuilder(
    column: $table.rawJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalHomeworkDraftsTableAnnotationComposer
    extends Composer<_$OfflineDatabase, $LocalHomeworkDraftsTable> {
  $$LocalHomeworkDraftsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get localId =>
      $composableBuilder(column: $table.localId, builder: (column) => column);

  GeneratedColumn<String> get accountKey => $composableBuilder(
    column: $table.accountKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get subject =>
      $composableBuilder(column: $table.subject, builder: (column) => column);

  GeneratedColumn<String> get className =>
      $composableBuilder(column: $table.className, builder: (column) => column);

  GeneratedColumn<String> get sectionId =>
      $composableBuilder(column: $table.sectionId, builder: (column) => column);

  GeneratedColumn<String> get teacherId =>
      $composableBuilder(column: $table.teacherId, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dueDate =>
      $composableBuilder(column: $table.dueDate, builder: (column) => column);

  GeneratedColumn<String> get studentId =>
      $composableBuilder(column: $table.studentId, builder: (column) => column);

  GeneratedColumn<String> get attachmentUrl => $composableBuilder(
    column: $table.attachmentUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get localUpdatedAt => $composableBuilder(
    column: $table.localUpdatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rawJson =>
      $composableBuilder(column: $table.rawJson, builder: (column) => column);
}

class $$LocalHomeworkDraftsTableTableManager
    extends
        RootTableManager<
          _$OfflineDatabase,
          $LocalHomeworkDraftsTable,
          LocalHomeworkDraft,
          $$LocalHomeworkDraftsTableFilterComposer,
          $$LocalHomeworkDraftsTableOrderingComposer,
          $$LocalHomeworkDraftsTableAnnotationComposer,
          $$LocalHomeworkDraftsTableCreateCompanionBuilder,
          $$LocalHomeworkDraftsTableUpdateCompanionBuilder,
          (
            LocalHomeworkDraft,
            BaseReferences<
              _$OfflineDatabase,
              $LocalHomeworkDraftsTable,
              LocalHomeworkDraft
            >,
          ),
          LocalHomeworkDraft,
          PrefetchHooks Function()
        > {
  $$LocalHomeworkDraftsTableTableManager(
    _$OfflineDatabase db,
    $LocalHomeworkDraftsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalHomeworkDraftsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalHomeworkDraftsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LocalHomeworkDraftsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> localId = const Value.absent(),
                Value<String> accountKey = const Value.absent(),
                Value<String?> serverId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> subject = const Value.absent(),
                Value<String> className = const Value.absent(),
                Value<String> sectionId = const Value.absent(),
                Value<String> teacherId = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String> dueDate = const Value.absent(),
                Value<String> studentId = const Value.absent(),
                Value<String> attachmentUrl = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime> localUpdatedAt = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<String> rawJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalHomeworkDraftsCompanion(
                localId: localId,
                accountKey: accountKey,
                serverId: serverId,
                title: title,
                subject: subject,
                className: className,
                sectionId: sectionId,
                teacherId: teacherId,
                description: description,
                dueDate: dueDate,
                studentId: studentId,
                attachmentUrl: attachmentUrl,
                status: status,
                localUpdatedAt: localUpdatedAt,
                syncStatus: syncStatus,
                rawJson: rawJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String localId,
                required String accountKey,
                Value<String?> serverId = const Value.absent(),
                required String title,
                Value<String> subject = const Value.absent(),
                Value<String> className = const Value.absent(),
                required String sectionId,
                Value<String> teacherId = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String> dueDate = const Value.absent(),
                Value<String> studentId = const Value.absent(),
                Value<String> attachmentUrl = const Value.absent(),
                Value<String> status = const Value.absent(),
                required DateTime localUpdatedAt,
                Value<String> syncStatus = const Value.absent(),
                Value<String> rawJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalHomeworkDraftsCompanion.insert(
                localId: localId,
                accountKey: accountKey,
                serverId: serverId,
                title: title,
                subject: subject,
                className: className,
                sectionId: sectionId,
                teacherId: teacherId,
                description: description,
                dueDate: dueDate,
                studentId: studentId,
                attachmentUrl: attachmentUrl,
                status: status,
                localUpdatedAt: localUpdatedAt,
                syncStatus: syncStatus,
                rawJson: rawJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalHomeworkDraftsTableProcessedTableManager =
    ProcessedTableManager<
      _$OfflineDatabase,
      $LocalHomeworkDraftsTable,
      LocalHomeworkDraft,
      $$LocalHomeworkDraftsTableFilterComposer,
      $$LocalHomeworkDraftsTableOrderingComposer,
      $$LocalHomeworkDraftsTableAnnotationComposer,
      $$LocalHomeworkDraftsTableCreateCompanionBuilder,
      $$LocalHomeworkDraftsTableUpdateCompanionBuilder,
      (
        LocalHomeworkDraft,
        BaseReferences<
          _$OfflineDatabase,
          $LocalHomeworkDraftsTable,
          LocalHomeworkDraft
        >,
      ),
      LocalHomeworkDraft,
      PrefetchHooks Function()
    >;

class $OfflineDatabaseManager {
  final _$OfflineDatabase _db;
  $OfflineDatabaseManager(this._db);
  $$CachedResponsesTableTableManager get cachedResponses =>
      $$CachedResponsesTableTableManager(_db, _db.cachedResponses);
  $$SyncOutboxEntriesTableTableManager get syncOutboxEntries =>
      $$SyncOutboxEntriesTableTableManager(_db, _db.syncOutboxEntries);
  $$SyncStatesTableTableManager get syncStates =>
      $$SyncStatesTableTableManager(_db, _db.syncStates);
  $$SyncReferencesTableTableManager get syncReferences =>
      $$SyncReferencesTableTableManager(_db, _db.syncReferences);
  $$LocalFileUploadsTableTableManager get localFileUploads =>
      $$LocalFileUploadsTableTableManager(_db, _db.localFileUploads);
  $$LocalAttendanceRecordsTableTableManager get localAttendanceRecords =>
      $$LocalAttendanceRecordsTableTableManager(
        _db,
        _db.localAttendanceRecords,
      );
  $$LocalAttendanceSessionsTableTableManager get localAttendanceSessions =>
      $$LocalAttendanceSessionsTableTableManager(
        _db,
        _db.localAttendanceSessions,
      );
  $$LocalStudentsTableTableManager get localStudents =>
      $$LocalStudentsTableTableManager(_db, _db.localStudents);
  $$LocalHomeworkDraftsTableTableManager get localHomeworkDrafts =>
      $$LocalHomeworkDraftsTableTableManager(_db, _db.localHomeworkDrafts);
}
