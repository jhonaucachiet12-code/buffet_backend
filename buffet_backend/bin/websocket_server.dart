import 'dart:io';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

// Lista global para guardar los clientes conectados (las 2 cuentas admin)
final List<WebSocketChannel> _clients = [];

void main() async {
  final handler = webSocketHandler((webSocket, protocol) {
    _clients.add(webSocket);
    print('Cliente conectado. Total: ${_clients.length}');

    webSocket.stream.listen(
      (message) {
        // Aquí podrías reenviar el mensaje a todos los clientes
        for (final client in _clients) {
          client.sink.add(message);
        }
      },
      onDone: () {
        _clients.remove(webSocket);
        print('Cliente desconectado.');
      },
    );
  });

  final server = await shelf_io.serve(handler, 'localhost', 8081);
  print('WebSocket server en ws://${server.address.host}:${server.port}');
}
