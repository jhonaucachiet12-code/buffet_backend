import 'dart:convert';
import 'dart:io';
import 'package:mysql_dart/mysql_dart.dart';
import 'package:dotenv/dotenv.dart';

class Database {
  static MySQLConnectionPool? _pool;
  static final DotEnv _env = DotEnv(includePlatformEnvironment: true)..load();

  static SecurityContext _buildSecurityContext() {
    final context = SecurityContext(withTrustedRoots: true);
    final caFromEnv = _env['DB_CA_CERT'];

    if (caFromEnv != null && caFromEnv.isNotEmpty) {
      // Railway: el certificado viene en una variable de entorno.
      // Algunas plataformas guardan los saltos de línea como "\n" literal.
      final pem = caFromEnv.replaceAll(r'\n', '\n');
      context.setTrustedCertificatesBytes(utf8.encode(pem));
    } else {
      // Local: el certificado está en un archivo en la raíz del backend.
      context.setTrustedCertificates('ca.pem');
    }
    return context;
  }

  static Future<MySQLConnectionPool> get pool async {
    if (_pool != null) return _pool!;

    _pool = MySQLConnectionPool(
      host: _env['DB_HOST'] ?? '127.0.0.1',
      port: int.parse(_env['DB_PORT'] ?? '3306'),
      userName: _env['DB_USER'] ?? 'root',
      password: _env['DB_PASS'] ?? '',
      databaseName: _env['DB_NAME'] ?? 'defaultdb',
      maxConnections: 10,
      secure: true,
      securityContext: _buildSecurityContext(),
    );
    return _pool!;
  }
}
