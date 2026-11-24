import 'dart:convert';
import 'package:dart_frog/dart_frog.dart';
import '../../lib/src/database.dart';

// Estados válidos de un pedido (coinciden con el ENUM de la base de datos):
//  - Pending_Payment: pedido nuevo, el vendedor todavía no respondió
//  - Preparing:       el vendedor lo aceptó
//  - Rejected:        el vendedor lo rechazó
//  - Cancelled:       pedido cancelado
const _validStatuses = [
  'Pending_Payment',
  'Preparing',
  'Cancelled',
  'Rejected',
];

Future<Response> onRequest(RequestContext context) async {
  final pool = await Database.pool;

  // GET: Devuelve los pedidos (los últimos 200) con sus productos
  if (context.request.method == HttpMethod.get) {
    try {
      // Pedimos las columnas una por una (en vez de o.*) para que el orden
      // sea siempre el mismo, sin depender de cómo esté armada la tabla.
      // Índices: 0 id, 1 nombre, 2 curso, 3 ticket, 4 estado, 5 pago,
      // 6 total, 7 fecha (en segundos desde 1970, no depende de la zona horaria).
      final result = await pool.execute(
        'SELECT id, student_name, student_course, ticket_code, status, '
        'payment_method, total, UNIX_TIMESTAMP(created_at) '
        'FROM orders ORDER BY created_at DESC, id DESC LIMIT 200',
      );

      final orders = <Map<String, dynamic>>[];
      for (final row in result.rows) {
        // Usamos colAt y toString() para evitar el error del tipo DECIMAL
        orders.add({
          'id': int.parse(row.colAt(0).toString()),
          'studentName': row.colAt(1)?.toString() ?? 'Alumno',
          'course': row.colAt(2)?.toString() ?? 'Curso',
          'ticketCode': row.colAt(3)?.toString() ?? 'Ticket',
          'status': row.colAt(4)?.toString() ?? 'Pending_Payment',
          'paymentMethod': row.colAt(5)?.toString() ?? 'Cash',
          'total': double.parse(row.colAt(6).toString()),
          'createdAt': row.colAt(7) != null
              ? double.tryParse(row.colAt(7).toString())?.toInt()
              : null,
          'items': <Map<String, dynamic>>[],
          'itemCount': 0,
        });
      }

      // Traemos los productos de esos pedidos en una sola consulta.
      // Los ids son números que salieron de la base, por eso se pueden
      // unir de forma segura en el IN (...).
      if (orders.isNotEmpty) {
        final ids = orders.map((o) => o['id'].toString()).join(',');
        final itemsResult = await pool.execute(
          'SELECT oi.order_id, p.name, oi.quantity, oi.price '
          'FROM order_items oi LEFT JOIN products p ON p.id = oi.product_id '
          'WHERE oi.order_id IN ($ids) ORDER BY oi.id',
        );

        final byOrder = <int, Map<String, dynamic>>{};
        for (final o in orders) {
          byOrder[o['id'] as int] = o;
        }
        for (final row in itemsResult.rows) {
          final order = byOrder[int.parse(row.colAt(0).toString())];
          if (order == null) continue;
          final quantity = int.parse(row.colAt(2).toString());
          (order['items'] as List<Map<String, dynamic>>).add({
            'name': row.colAt(1)?.toString() ?? 'Producto eliminado',
            'quantity': quantity,
            'price': double.parse(row.colAt(3).toString()),
          });
          order['itemCount'] = (order['itemCount'] as int) + quantity;
        }
      }

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

      // Todo pedido nuevo entra como 'Pending_Payment' (pendiente de que el
      // vendedor lo acepte o lo rechace), sin importar lo que mande la app.
      final orderResult = await pool.execute(
        "INSERT INTO orders (student_name, student_course, ticket_code, status, payment_method, total) VALUES (:name, :course, :ticket, 'Pending_Payment', :payment, :total)",
        {
          'name': body['studentName'],
          'course': body['course'],
          'ticket': body['ticketCode'],
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

      final id = int.tryParse(body['id'].toString());
      final status = body['status']?.toString();
      if (id == null || status == null || !_validStatuses.contains(status)) {
        return Response.json(
          statusCode: 400,
          body: {'error': 'Pedido o estado inválido'},
        );
      }

      await pool.execute(
        'UPDATE orders SET status = :status WHERE id = :id',
        {'status': status, 'id': id},
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
