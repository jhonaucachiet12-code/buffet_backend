import 'package:dart_frog/dart_frog.dart';

Handler middleware(Handler handler) {
  return handler.use(requestLogger()).use(
    (handler) {
      return (context) async {
        // Si es una petición pre-vuelo (OPTIONS) de un navegador
        if (context.request.method == HttpMethod.options) {
          return Response(statusCode: 204, headers: _corsHeaders);
        }
        
        final response = await handler(context);
        return response.copyWith(headers: {...response.headers, ..._corsHeaders});
      };
    },
  );
}

const _corsHeaders = {
  'Access-Control-Allow-Origin': '*', // Permite cualquier origen (en producción pon tu dominio)
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Origin, Content-Type, Accept, Authorization',
};