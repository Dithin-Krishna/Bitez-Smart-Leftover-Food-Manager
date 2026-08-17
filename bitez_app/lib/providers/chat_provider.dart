import 'package:flutter/foundation.dart';
import '../models/chat_message.dart';
import '../services/chat_service.dart';

class ChatProvider extends ChangeNotifier {
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isHistoryLoaded = false;
  String? _errorMessage;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  bool get isHistoryLoaded => _isHistoryLoaded;
  String? get errorMessage => _errorMessage;

  static const List<String> defaultSuggestions = [
    '🍳 Recipe from fridge items',
    '🧊 How to keep greens fresh',
    '⚡ Quick 15-min leftover meal',
    '🔄 Common ingredient swaps',
  ];

  ChatProvider() {
    _addInitialWelcomeMessage();
  }

  void _addInitialWelcomeMessage() {
    if (_messages.isEmpty) {
      _messages.add(
        ChatMessage(
          id: 'welcome',
          text: "### 👋 Hi, I'm Chef Bitez!\nYour personal zero-waste AI culinary assistant. Ask me anything about cooking with leftovers, food storage, or ingredient swaps!",
          isUser: false,
          suggestedActions: defaultSuggestions,
        ),
      );
    }
  }

  /// Load persistent chat history from MongoDB backend
  Future<void> loadHistory({String? token}) async {
    if (token == null || _isHistoryLoaded) return;
    _isLoading = true;
    notifyListeners();

    try {
      final savedMessages = await ChatService.instance.fetchHistory(token: token);
      if (savedMessages.isNotEmpty) {
        _messages.clear();
        _messages.addAll(savedMessages);
      }
      _isHistoryLoaded = true;
    } catch (_) {
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> sendMessage(String text, {String? token}) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty || _isLoading) return;

    _errorMessage = null;

    final userMsg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: cleanText,
      isUser: true,
    );

    _messages.add(userMsg);
    _isLoading = true;
    notifyListeners();

    try {
      final aiResponse = await ChatService.instance.sendMessage(
        message: cleanText,
        history: _messages.where((m) => m.id != 'welcome').toList(),
        token: token,
      );

      _messages.add(aiResponse);
    } catch (e) {
      _errorMessage = e.toString();
      _messages.add(
        ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text: "⚠️ **Chef Bitez Warning**: Could not reach AI server. Please check your internet connection or server status.\n\n*Error details: ${e.toString()}*",
          isUser: false,
          status: MessageStatus.error,
          suggestedActions: defaultSuggestions,
        ),
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteSingleMessage(String id, {String? token}) async {
    _messages.removeWhere((m) => m.id == id);
    if (_messages.isEmpty) {
      _addInitialWelcomeMessage();
    }
    notifyListeners();
    if (token != null && id != 'welcome') {
      await ChatService.instance.deleteSingleMessage(id, token: token);
    }
  }

  Future<void> clearChat({String? token}) async {
    _messages.clear();
    _errorMessage = null;
    _addInitialWelcomeMessage();
    notifyListeners();
    if (token != null) {
      await ChatService.instance.clearHistory(token: token);
    }
  }
}
