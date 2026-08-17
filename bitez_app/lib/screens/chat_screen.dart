import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/chat_message.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final token = context.read<AuthProvider>().token;
      context.read<ChatProvider>().loadHistory(token: token);
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleSend([String? presetText]) {
    final text = presetText ?? _inputController.text;
    if (text.trim().isEmpty) return;

    if (presetText == null) {
      _inputController.clear();
    }

    final token = context.read<AuthProvider>().token;
    context.read<ChatProvider>().sendMessage(text, token: token);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final chatProvider = context.watch<ChatProvider>();

    // Scroll down whenever message count changes
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    primaryColor,
                    const Color(0xFFE07A5F),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Center(
                child: Text(
                  '🍳',
                  style: TextStyle(fontSize: 20),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Chef Bitez AI',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Smart Food & Waste Assistant',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white60 : Colors.black54,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear Chat',
            onPressed: () {
              final token = context.read<AuthProvider>().token;
              chatProvider.clearChat(token: token);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Messages area
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: chatProvider.messages.length + (chatProvider.isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == chatProvider.messages.length) {
                    return _buildTypingIndicator(isDark, primaryColor);
                  }
                  final msg = chatProvider.messages[index];
                  return _buildMessageBubble(msg, isDark, primaryColor);
                },
              ),
            ),

            // Preset Suggestions Bar
            _buildPresetSuggestions(chatProvider, isDark),

            // Input Bar
            _buildInputBar(isDark, primaryColor),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteMessage(ChatMessage msg) {
    if (msg.id == 'welcome') return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Message'),
        content: const Text('Remove this message from your chat history and database?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              final token = context.read<AuthProvider>().token;
              context.read<ChatProvider>().deleteSingleMessage(msg.id, token: token);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, bool isDark, Color primaryColor) {
    final isUser = msg.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser) ...[
                CircleAvatar(
                  radius: 16,
                  backgroundColor: primaryColor.withValues(alpha: 0.15),
                  child: const Text('🍳', style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(width: 8),
              ],

              Flexible(
                child: GestureDetector(
                  onLongPress: () => _confirmDeleteMessage(msg),
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.78,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isUser
                          ? primaryColor
                          : (isDark ? const Color(0xFF1E2B3C) : const Color(0xFFF0F4F8)),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(isUser ? 18 : 4),
                        bottomRight: Radius.circular(isUser ? 4 : 18),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFormattedText(
                          msg.text,
                          isUser
                              ? Colors.white
                              : (isDark ? Colors.white : Colors.black87),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Suggested quick actions below AI message
          if (!isUser && msg.suggestedActions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: msg.suggestedActions.map((action) {
                  return ActionChip(
                    label: Text(
                      action,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white70 : primaryColor,
                      ),
                    ),
                    backgroundColor: isDark
                        ? const Color(0xFF253447)
                        : primaryColor.withValues(alpha: 0.08),
                    shape: StadiumBorder(
                      side: BorderSide(
                        color: primaryColor.withValues(alpha: 0.3),
                      ),
                    ),
                    onPressed: () => _handleSend(action),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Simple rich text parser for markdown headers, bullet points, and bold text
  Widget _buildFormattedText(String text, Color defaultColor) {
    final lines = text.split('\n');
    final List<Widget> children = [];

    for (var line in lines) {
      if (line.trim().isEmpty) {
        children.add(const SizedBox(height: 6));
        continue;
      }

      if (line.startsWith('### ')) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 4),
            child: Text(
              line.replaceFirst('### ', ''),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: defaultColor,
              ),
            ),
          ),
        );
      } else if (line.startsWith('#### ')) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 2),
            child: Text(
              line.replaceFirst('#### ', ''),
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: defaultColor,
              ),
            ),
          ),
        );
      } else if (line.startsWith('- ') || line.startsWith('* ')) {
        final content = line.substring(2);
        children.add(
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 2, bottom: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• ', style: TextStyle(fontWeight: FontWeight.bold, color: defaultColor)),
                Expanded(
                  child: _buildSpanText(content, defaultColor),
                ),
              ],
            ),
          ),
        );
      } else {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: _buildSpanText(line, defaultColor),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  Widget _buildSpanText(String line, Color defaultColor) {
    final parts = line.split('**');
    if (parts.length <= 1) {
      return Text(
        line,
        style: TextStyle(fontSize: 14, color: defaultColor, height: 1.35),
      );
    }

    final List<TextSpan> spans = [];
    for (int i = 0; i < parts.length; i++) {
      if (parts[i].isEmpty) continue;
      spans.add(
        TextSpan(
          text: parts[i],
          style: TextStyle(
            fontWeight: i % 2 == 1 ? FontWeight.bold : FontWeight.normal,
            color: defaultColor,
            fontSize: 14,
          ),
        ),
      );
    }

    return RichText(
      text: TextSpan(children: spans),
    );
  }

  Widget _buildTypingIndicator(bool isDark, Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: primaryColor.withValues(alpha: 0.15),
            child: const Text('🍳', style: TextStyle(fontSize: 16)),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2B3C) : const Color(0xFFF0F4F8),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Chef Bitez is thinking...',
                  style: TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetSuggestions(ChatProvider provider, bool isDark) {
    if (provider.messages.length > 2) return const SizedBox.shrink();

    return Container(
      height: 44,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: ChatProvider.defaultSuggestions.length,
        itemBuilder: (context, index) {
          final suggestion = ChatProvider.defaultSuggestions[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(
                suggestion,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
              selected: false,
              backgroundColor: isDark ? const Color(0xFF1E2A38) : Colors.white,
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isDark ? Colors.white24 : Colors.black12,
                ),
              ),
              onSelected: (_) => _handleSend(suggestion),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputBar(bool isDark, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141E2B) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              focusNode: _focusNode,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Ask Chef Bitez anything...',
                hintStyle: TextStyle(
                  color: isDark ? Colors.white38 : Colors.black38,
                  fontSize: 14,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                filled: true,
                fillColor: isDark ? const Color(0xFF1E2C3D) : const Color(0xFFF4F6F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _handleSend(),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: primaryColor,
            shape: const CircleBorder(),
            elevation: 2,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => _handleSend(),
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
