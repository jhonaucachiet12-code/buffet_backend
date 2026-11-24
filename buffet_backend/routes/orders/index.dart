import 'dart:convert';
import 'package:dart_frog/dart_frog.dart';
import '../../lib/src/database.dart';

Future<Response> onRequest(RequestContext context) async {
  final pool = await Database.pool;

  // GET: Devuelve todos los pedidos con su cantidad de productos
  if (context.request.method == HttpMethod.get) {
    final result = await pool.execute(
      'SELECT o.*, SUM(oi.quantity) as itemCount FROM orders o LEFT JOIN order_items oi ON o.id = oi.order_id GROUP BY o.id ORDER BY o.created_at DESC',
    );
    final orders = result.rows
        .map(
          (row) => {
            // Usamos colAt y toString() para evitar el error del tipo DECIMAL
            'id': int.parse(row.colAt(0).toString()),
            'studentName': row.colAt(2)?.toString() ?? 'Alumno',
            'course': row.colAt(3)?.toString() ?? 'Curso',
            'ticketCode': row.colAt(4)?.toString() ?? 'Ticket',
            'status': row.colAt(5)?.toString() ?? 'Pendiente',
            'paymentMethod': row.colAt(6)?.toString() ?? 'Efectivo',
            'total': double.parse(row.colAt(7).toString()),
            // Si no hay productos (itemCount es null), mandamos 0
            'itemCount': row.colAt(8) != null
                ? int.parse(row.colAt(8).toString())
                : 0,
          },
        )
        .toList();
    return Response.json(body: orders);
  }

  // POST: Crear un pedido nuevo
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

  // PATCH: Actualizar estado (Aceptar/Rechazar)
  if (context.request.method == HttpMethod.patch) {
    final body = await context.request.json() as Map<String, dynamic>;
    await pool.execute(
      'UPDATE orders SET status = :status WHERE id = :id',
      {'status': body['status'], 'id': body['id']},
    );
    return Response.json(body: {'success': true});
  }

  return Response(statusCode: 405);
}
