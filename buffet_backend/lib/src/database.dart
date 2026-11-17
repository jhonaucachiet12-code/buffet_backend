import 'dart:io';
import 'package:mysql_client/mysql_client.dart';
import 'package:dotenv/dotenv.dart';

class Database {
  static MySQLConnectionPool? _pool;
  static final DotEnv _env = DotEnv(includePlatformEnvironment: true)..load();

  static Future<MySQLConnectionPool> get pool async {
    if (_pool != null) return _pool!;

    _pool = MySQLConnectionPool(
      host: _env['DB_HOST'] ?? '127.0.0.1',
      port: int.parse(_env['DB_PORT'] ?? '3306'),
      userName: _env['DB_USER'] ?? 'root',
      password: _env['DB_PASS'] ?? '',
      databaseName: _env['DB_NAME'] ?? 'buffet_express',
      maxConnections: 10,
    );
    return _pool!;
  }
}
