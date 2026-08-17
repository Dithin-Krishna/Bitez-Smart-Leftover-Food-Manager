import '../models/chat_message.dart';
import 'api_service.dart';

class ChatService {
  ChatService._();
  static final ChatService instance = ChatService._();

  /// Fetch user chat history from GET /api/chat/history
  Future<List<ChatMessage>> fetchHistory({String? token}) async {
    if (token == null) return [];
    try {
      final response = await ApiService.instance.get('/api/chat/history', token: token);
      if (response['success'] == true && response['data'] is List) {
        final list = response['data'] as List;
        return list.map((item) => ChatMessage.fromJson(item as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Clear chat history from DELETE /api/chat/history
  Future<void> clearHistory({String? token}) async {
    if (token == null) return;
    try {
      await ApiService.instance.delete('/api/chat/history', token: token);
    } catch (_) {}
  }

  /// Delete a single message from DELETE /api/chat/message/:id
  Future<void> deleteSingleMessage(String id, {String? token}) async {
    if (token == null || id.isEmpty) return;
    try {
      await ApiService.instance.delete('/api/chat/message/$id', token: token);
    } catch (_) {}
  }

  /// Send message to AI Chatbot backend route /api/chat/send
  Future<ChatMessage> sendMessage({
    required String message,
    required List<ChatMessage> history,
    String? token,
  }) async {
    try {
      final formattedHistory = history
          .map((m) => {
                'role': m.isUser ? 'user' : 'model',
                'text': m.text,
              })
          .toList();

      final response = await ApiService.instance.post(
        '/api/chat/send',
        {
          'message': message,
          'history': formattedHistory,
        },
        token: token,
      );

      if (response['success'] == true && response['data'] != null) {
        final data = response['data'] as Map<String, dynamic>;
        return ChatMessage(
          id: data['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
          text: data['reply']?.toString() ?? 'No response received.',
          isUser: false,
          timestamp: data['timestamp'] != null
              ? DateTime.tryParse(data['timestamp'].toString()) ?? DateTime.now()
              : DateTime.now(),
          suggestedActions: (data['suggestedActions'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              const [],
          status: MessageStatus.sent,
        );
      } else {
        throw ApiException(response['message']?.toString() ?? 'Failed to get response from Chef Bitez AI.');
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Chef Bitez AI connection error: ${e.toString()}');
    }
  }
}
