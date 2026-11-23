import 'dart:convert';
import 'package:dart_frog/dart_frog.dart';
import '../../lib/src/database.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post)
    return Response(statusCode: 405);

  final body = await context.request.json() as Map<String, dynamic>;
  final pool = await Database.pool;

  // Quitamos 'params:'
  final result = await pool.execute(
    'SELECT * FROM users WHERE email = :email AND dni = :dni AND role = "admin"',
    {'email': body['email'], 'dni': body['dni']},
  );

  if (result.rows.isEmpty) {
    return Response.json(
      statusCode: 401,
      body: {'error': 'Credenciales inválidas'},
    );
  }

  final user = result.rows.first;
  if (user.colAt(4) != body['password']) {
    return Response.json(
      statusCode: 401,
      body: {'error': 'Contraseña incorrecta'},
    );
  }

  return Response.json(
    body: {'message': 'Login exitoso', 'name': user.colAt(2)},
  );
}
