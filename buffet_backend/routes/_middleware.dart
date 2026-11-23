import 'package:dart_frog/dart_frog.dart';

Handler middleware(Handler handler) {
  return handler.use(requestLogger()).use((handler) {
    return (context) async {
      // Si el navegador envía una petición de verificación (OPTIONS)
      if (context.request.method == HttpMethod.options) {
        return Response(statusCode: 204, headers: _corsHeaders);
      }

      // Para cualquier otra petición, agregamos los encabezados CORS a la respuesta
      final response = await handler(context);
      return response.copyWith(headers: {...response.headers, ..._corsHeaders});
    };
  });
}

const _corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  // IMPORTANTE: Agregamos PATCH aquí
  'Access-Control-Allow-Methods': 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Origin, Content-Type, Accept, Authorization',
};
