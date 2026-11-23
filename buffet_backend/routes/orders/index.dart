import 'dart:convert';
import 'package:dart_frog/dart_frog.dart';
import '../../lib/src/database.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: 405);
  }

  final body = await context.request.json() as Map<String, dynamic>;
  final pool = await Database.pool;

  // 1. Insertar la orden principal (Quitamos 'params:')
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

  // 2. Insertar los productos de ese pedido (Quitamos 'params:')
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
