import 'dart:io';
import 'package:mysql_client/mysql_client.dart';
import 'package:dotenv/dotenv.dart';

class Database {
  static MySQLConnectionPool? _pool;
  static final DotEnv _env = DotEnv(includePlatformEnvironment: true)..load();

  static Future<MySQLConnectionPool> get pool async {
    if (_pool != null) return _pool!;

    // Leemos el certificado SSL de Aiven
    final sslContext = SecurityContext()..setTrustedCertificates('ca.pem');

    _pool = MySQLConnectionPool(
      host: _env['DB_HOST'] ?? '',
      port: int.parse(_env['DB_PORT'] ?? '3306'),
      userName: _env['DB_USER'] ?? '',
      password: _env['DB_PASS'] ?? '',
      databaseName: _env['DB_NAME'] ?? 'defaultdb',
      maxConnections: 10,
      secure: true, // Obligatorio para Aiven
      // Algunas versiones de mysql_client piden el contexto SSL así:
      // sslContext: sslContext,
    );
    return _pool!;
  }
}
