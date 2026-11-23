import 'dart:convert';
import 'package:dart_frog/dart_frog.dart';
import '../../lib/src/database.dart';

Future<Response> onRequest(RequestContext context) async {
  final pool = await Database.pool;

  // --- GET: Obtener pedidos con sus productos ---
  if (context.request.method == HttpMethod.get) {
    // 1. Traemos todos los pedidos
    final ordersResult = await pool.execute(
      'SELECT * FROM orders ORDER BY created_at DESC',
    );

    // 2. Traemos todos los items de los pedidos
    final itemsResult = await pool.execute('''
      SELECT oi.order_id, oi.quantity, oi.price, p.name 
      FROM order_items oi 
      JOIN products p ON oi.product_id = p.id
    ''');

    // 3. Agrupamos los items por ID de pedido
    final Map<int, List<Map<String, dynamic>>> itemsByOrder = {};
    for (var row in itemsResult.rows) {
      final orderId = int.parse(row.colAt(0)!);
      itemsByOrder.putIfAbsent(orderId, () => []).add({
        'name': row.colAt(3),
        'quantity': int.parse(row.colAt(1)!),
        'price': double.parse(row.colAt(2)!),
      });
    }

    // 4. Armamos la respuesta final
    final orders = ordersResult.rows.map((row) {
      final orderId = int.parse(row.colAt(0)!);
      final items = itemsByOrder[orderId] ?? [];
      final itemCount = items.fold(
        0,
        (sum, item) => sum + (item['quantity'] as int),
      );

      return {
        'id': row.colAt(0),
        'studentName': row.colAt(2),
        'course': row.colAt(3),
        'ticketCode': row.colAt(4),
        'status': row.colAt(5),
        'paymentMethod': row.colAt(6),
        'total': double.parse(row.colAt(7)!),
        'itemCount': itemCount,
        'items': items, // <-- Ahora enviamos la lista de productos
      };
    }).toList();

    return Response.json(body: orders);
  }

  // --- POST: Crear un pedido ---
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

    final orderId = orderResult.lastInsertID.toInt();

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

  // --- PATCH: Actualizar estado ---
  if (context.request.method == HttpMethod.patch) {
    final body = await context.request.json() as Map<String, dynamic>;

    await pool.execute(
      'UPDATE orders SET status = :status WHERE id = :id',
      {
        'status': body['status'],
        'id': body['id'],
      },
    );

    return Response.json(body: {'success': true});
  }

  return Response(statusCode: 405);
}
