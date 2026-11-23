import 'dart:convert';
import 'package:dart_frog/dart_frog.dart';
import '../../lib/src/database.dart';

Future<Response> onRequest(RequestContext context) async {
  final pool = await Database.pool;

  if (context.request.method == HttpMethod.get) {
    final result = await pool.execute('SELECT * FROM products');
    final products = result.rows
        .map(
          (row) => {
            'id': int.parse(row.colAt(0)!),
            'categoryId': int.parse(row.colAt(1)!),
            'name': row.colAt(2),
            'description': row.colAt(3),
            'price': double.parse(row.colAt(4)!),
            'status': row.colAt(5),
            'unavailableReason': row.colAt(6),
          },
        )
        .toList();
    return Response.json(body: products);
  }

  if (context.request.method == HttpMethod.patch) {
    final body = await context.request.json() as Map<String, dynamic>;
    final id = body['id'];
    final price = body['price'];
    final status = body['status'];

    // CORRECCIÓN: Quitamos 'params:' y pasamos el Map directamente
    await pool.execute(
      'UPDATE products SET price = :price, status = :status WHERE id = :id',
      {'price': price, 'status': status, 'id': id},
    );
    return Response.json(body: {'success': true});
  }

  return Response(statusCode: 405);
}
