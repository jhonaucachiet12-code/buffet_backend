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
            'id': int.parse(row.colAt(0).toString()),
            'categoryId': int.parse(row.colAt(1).toString()),
            'name': row.colAt(2).toString(),
            'description': row.colAt(3).toString(),
            'price': double.parse(row.colAt(4).toString()),
            'status': row.colAt(5).toString(),
            'unavailableReason': row.colAt(6)?.toString(),
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
    final reason = body['unavailableReason'] ?? 'Sin stock';

    await pool.execute(
      'UPDATE products SET price = :price, status = :status, unavailable_reason = :reason WHERE id = :id',
      {'price': price, 'status': status, 'reason': reason, 'id': id},
    );
    return Response.json(body: {'success': true});
  }

  return Response(statusCode: 405);
}
