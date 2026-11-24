import 'dart:io';
import 'package:mysql_dart/mysql_dart.dart';
import 'package:dotenv/dotenv.dart';

class Database {
  static MySQLConnectionPool? _pool;
  static final DotEnv _env = DotEnv(includePlatformEnvironment: true)..load();

  static Future<MySQLConnectionPool> get pool async {
    if (_pool != null) return _pool!;

    // 1. Creamos el contexto de seguridad y cargamos el certificado de Aiven
    final sslContext = SecurityContext(withTrustedRoots: true)
      ..setTrustedCertificates('ca.pem');

    _pool = MySQLConnectionPool(
      host: _env['DB_HOST'] ?? '',
      port: int.parse(_env['DB_PORT'] ?? '3306'),
      userName: _env['DB_USER'] ?? '',
      password: _env['DB_PASS'] ?? '',
      databaseName: _env['DB_NAME'] ?? 'defaultdb',
      maxConnections: 10,
      secure: true,
      securityContext: sslContext,
    );
    return _pool!;
  }
}
