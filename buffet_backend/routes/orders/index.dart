import 'dart:convert';
import 'package:dart_frog/dart_frog.dart';
import '../../lib/src/database.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: 405);
  }

  final body = await context.request.json() as Map<String, dynamic>;
  final pool = await Database.pool;

  // Usamos :nombre en lugar de ? y pasamos un Map
  final result = await pool.execute(
    'INSERT INTO orders (student_name, student_course, ticket_code, status, payment_method, total) VALUES (:studentName, :course, :ticketCode, :status, :paymentMethod, :total)',
    {
      'studentName': body['studentName'],
      'course': body['course'],
      'ticketCode': body['ticketCode'],
      'status': body['status'],
      'paymentMethod': body['paymentMethod'],
      'total': body['total'],
    },
  );

  return Response.json(body: {'orderId': result.lastInsertID});
}
