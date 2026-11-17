import 'dart:convert';
import 'package:dart_frog/dart_frog.dart';
import '../../lib/src/database.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405);
  }
  final pool = await Database.pool;
  final result = await pool.execute('SELECT * FROM products');

  final products = result.rows
      .map(
        (row) => {
          'id': int.parse(row.colAt(0)!),
          'name': row.colAt(2),
          'description': row.colAt(3),
          'price': double.parse(row.colAt(4)!),
          'isAvailable': row.colAt(5) == '1',
        },
      )
      .toList();

  return Response.json(body: products);
}
