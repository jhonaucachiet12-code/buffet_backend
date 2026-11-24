import 'dart:convert';
import 'package:dart_frog/dart_frog.dart';
import '../../lib/src/database.dart';

Future<Response> onRequest(RequestContext context) async {
  final pool = await Database.pool;

  // GET: Devuelve todos los pedidos para el panel del vendedor
  if (context.request.method == HttpMethod.get) {
    final result = await pool.execute(
      'SELECT * FROM orders ORDER BY created_at DESC',
    );
    final orders = result.rows
        .map(
          (row) => {
            'id': int.parse(row.colAt(0).toString()),
            'studentName': row.colAt(2).toString(),
            'course': row.colAt(3).toString(),
            'ticketCode': row.colAt(4).toString(),
            'status': row.colAt(5).toString(),
            'paymentMethod': row.colAt(6).toString(),
            'total': double.parse(row.colAt(7).toString()),
          },
        )
        .toList();
    return Response.json(body: orders);
  }

  // POST: Recibe un pedido desde el carrito del alumno
  if (context.request.method == HttpMethod.post) {
    final body = await context.request.json() as Map<String, dynamic>;

    final orderResult = await pool.execute(
      'INSERT INTO orders (student_name, student_course, ticket_code, status, payment_method, total) VALUES (:name, :course, :ticket, :status, :payment, :total)',
      {
        'name': body['studentName'],
        'course': body['course'],
        'ticket': body['ticketCode'],
        'status': body['status'],
        'payment': body['paymentMethod'],
        'total': body['total'],
      },
    );

    final orderId = orderResult.lastInsertID;

    final items = body['items'] as List<dynamic>;
    for (var item in items) {
      await pool.execute(
        'INSERT INTO order_items (order_id, product_id, quantity, price) VALUES (:orderId, :productId, :quantity, :price)',
        {
          'orderId': orderId,
          'productId': item['productId'],
          'quantity': item['quantity'],
          'price': item['price'],
        },
      );
    }

    return Response.json(
      body: {'orderId': orderId, 'ticketCode': body['ticketCode']},
    );
  }

  return Response(statusCode: 405);
}
