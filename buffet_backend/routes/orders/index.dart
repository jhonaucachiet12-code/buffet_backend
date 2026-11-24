import 'dart:convert';
import 'package:dart_frog/dart_frog.dart';
import '../../lib/src/database.dart';

Future<Response> onRequest(RequestContext context) async {
  final pool = await Database.pool;

  // GET: Devuelve todos los pedidos con su cantidad de productos
  if (context.request.method == HttpMethod.get) {
    try {
      // Pedimos las columnas una por una (en vez de o.*) para que el orden
      // sea siempre el mismo, sin depender de cómo esté armada la tabla.
      // Índices: 0 id, 1 nombre, 2 curso, 3 ticket, 4 estado, 5 pago,
      // 6 total, 7 itemCount.
      final result = await pool.execute(
        'SELECT o.id, o.student_name, o.student_course, o.ticket_code, '
        'o.status, o.payment_method, o.total, '
        'COALESCE(SUM(oi.quantity), 0) AS itemCount '
        'FROM orders o LEFT JOIN order_items oi ON o.id = oi.order_id '
        'GROUP BY o.id, o.student_name, o.student_course, o.ticket_code, '
        'o.status, o.payment_method, o.total, o.created_at '
        'ORDER BY o.created_at DESC',
      );
      final orders = result.rows
          .map(
            (row) => {
              // Usamos colAt y toString() para evitar el error del tipo DECIMAL
              'id': int.parse(row.colAt(0).toString()),
              'studentName': row.colAt(1)?.toString() ?? 'Alumno',
              'course': row.colAt(2)?.toString() ?? 'Curso',
              'ticketCode': row.colAt(3)?.toString() ?? 'Ticket',
              'status': row.colAt(4)?.toString() ?? 'Pending_Payment',
              'paymentMethod': row.colAt(5)?.toString() ?? 'Cash',
              'total': double.parse(row.colAt(6).toString()),
              // Si no hay productos mandamos 0
              'itemCount': row.colAt(7) != null
                  ? double.parse(row.colAt(7).toString()).toInt()
                  : 0,
            },
          )
          .toList();
      return Response.json(body: orders);
    } catch (e) {
      // Queda registrado en los logs de Railway
      print('Error al listar pedidos: $e');
      return Response.json(
        statusCode: 500,
        body: {'error': 'No se pudieron cargar los pedidos'},
      );
    }
  }

  // POST: Crear un pedido nuevo
  if (context.request.method == HttpMethod.post) {
    int? orderId;
    try {
      final body = await context.request.json() as Map<String, dynamic>;

      final items = (body['items'] as List<dynamic>?) ?? <dynamic>[];
      if (items.isEmpty) {
        return Response.json(
          statusCode: 400,
          body: {'error': 'El pedido no tiene productos'},
        );
      }

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

      orderId = orderResult.lastInsertID.toInt();

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
    } catch (e) {
      print('Error al crear pedido: $e');
      // Si el pedido se alcanzó a crear pero falló un producto, lo borramos
      // para no dejar pedidos a medias (los items se borran en cascada).
      if (orderId != null) {
        try {
          await pool.execute(
            'DELETE FROM orders WHERE id = :id',
            {'id': orderId},
          );
        } catch (_) {}
      }
      return Response.json(
        statusCode: 500,
        body: {'error': 'No se pudo crear el pedido'},
      );
    }
  }

  // PATCH: Actualizar estado (Aceptar/Rechazar)
  if (context.request.method == HttpMethod.patch) {
    try {
      final body = await context.request.json() as Map<String, dynamic>;
      await pool.execute(
        'UPDATE orders SET status = :status WHERE id = :id',
        {'status': body['status'], 'id': body['id']},
      );
      return Response.json(body: {'success': true});
    } catch (e) {
      print('Error al actualizar pedido: $e');
      return Response.json(
        statusCode: 500,
        body: {'error': 'No se pudo actualizar el pedido'},
      );
    }
  }

  return Response(statusCode: 405);
}
