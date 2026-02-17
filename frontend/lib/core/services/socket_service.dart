import 'package:campus_social_media/core/constants/api_constants.dart';
import 'package:campus_social_media/core/services/storage_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

final socketServiceProvider = Provider<SocketService>((ref) {
  return SocketService(ref.watch(storageServiceProvider));
});

class SocketService {
  late IO.Socket _socket;
  final StorageService _storage;
  bool _isConnected = false;

  SocketService(this._storage);

  void initSocket() async {
    final token = await _storage.read(key: 'auth_token');
    if (token == null) return;

    // Remove /api from the end if it exists, as socket connects to root
    final baseUrl = ApiConstants.baseUrl; 

    _socket = IO.io(baseUrl, IO.OptionBuilder()
      .setTransports(['websocket'])
      .disableAutoConnect()
      .setAuth({'token': token})
      .build()
    );

    _socket.connect();

    _socket.onConnect((_) {
      print('✅ Socket Connected');
      _isConnected = true;
    });

    _socket.onDisconnect((_) {
      print('❌ Socket Disconnected');
      _isConnected = false;
    });

    _socket.onError((data) => print('Socket Error: $data'));
  }

  void disconnect() {
    _socket.disconnect();
  }

  // Chat Methods
  void joinConversation(String conversationId) {
    if (!_isConnected) initSocket(); // improved auto-reconnect
    _socket.emit('join_conversation', conversationId);
  }

  void sendTyping(String conversationId) {
    _socket.emit('typing', conversationId);
  }

  void sendStopTyping(String conversationId) {
    _socket.emit('stop_typing', conversationId);
  }

  // Listeners
  void onNewMessage(Function(dynamic) callback) {
    _socket.on('new_message', callback);
  }

  void onTyping(Function(dynamic) callback) {
    _socket.on('typing', callback);
  }

  void onStopTyping(Function(dynamic) callback) {
    _socket.on('stop_typing', callback);
  }
  
  void off(String event) {
    _socket.off(event);
  }
}
