import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:matchfit/core/theme.dart';
import 'package:matchfit/core/widgets/avatar_widget.dart';
import 'package:matchfit/features/chat/repositories/chat_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/foundation.dart' as foundation;

class ChatScreen extends ConsumerStatefulWidget {
  final String targetUserId;
  final String targetUserName;
  final String? targetAvatarUrl;

  const ChatScreen({
    super.key,
    required this.targetUserId,
    required this.targetUserName,
    this.targetAvatarUrl,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final String myId = Supabase.instance.client.auth.currentUser?.id ?? '';
  bool _emojiShowing = false;
  FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        setState(() {
          _emojiShowing = false;
        });
      }
    });
    // Mark messages as read when opening the screen
    Future.microtask(() {
      ref.read(chatRepositoryProvider).markAsRead(widget.targetUserId);
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    
    try {
      await ref.read(chatRepositoryProvider).sendMessage(widget.targetUserId, text);
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Mesaj gönderilemedi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 100,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  String _formatTime(String isoString) {
    try {
      final date = DateTime.parse(isoString).toLocal();
      return DateFormat('HH:mm').format(date);
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(chatMessagesProvider(widget.targetUserId));

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF141414),
        elevation: 1,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Row(
          children: [
            AvatarWidget(
              name: widget.targetUserName,
              avatarUrl: widget.targetAvatarUrl,
              radius: 18,
              editable: false,
            ),
            const SizedBox(width: 12),
            Text(
              widget.targetUserName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: MatchFitTheme.accentGreen)),
              error: (e, _) => Center(child: Text('Hata: $e', style: const TextStyle(color: Colors.red))),
              data: (messages) {
                if (messages.isEmpty) {
                  return const Center(
                    child: Text(
                      'Henüz mesaj yok.\nİlk mesajı sen gönder!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                  );
                }

                // Scroll to bottom when new messages arrive
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollToBottom();
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg['sender_id'] == myId;
                    
                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 6, top: 2),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isMe ? MatchFitTheme.accentGreen : const Color(0xFF242424),
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: Radius.circular(isMe ? 16 : 0),
                            bottomRight: Radius.circular(isMe ? 0 : 16),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            Text(
                              msg['content'] ?? '',
                              style: TextStyle(
                                color: isMe ? Colors.black : Colors.white,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _formatTime(msg['created_at']),
                                  style: TextStyle(
                                    color: isMe ? Colors.black54 : Colors.white38,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (isMe) ...[
                                  const SizedBox(width: 4),
                                  Icon(
                                    msg['is_read'] == true ? Icons.done_all : Icons.done,
                                    size: 14,
                                    color: msg['is_read'] == true ? Colors.blue : Colors.black54,
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          
          // Input Area
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF141414),
              border: Border(
                top: BorderSide(color: Colors.white.withOpacity(0.05)),
              ),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF242424),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _messageController,
                        focusNode: _focusNode,
                        style: const TextStyle(color: Colors.white),
                        textCapitalization: TextCapitalization.sentences,
                        minLines: 1,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: 'Mesaj yazın...',
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          prefixIcon: IconButton(
                            icon: Icon(
                              _emojiShowing ? Icons.keyboard : Icons.emoji_emotions_outlined,
                              color: Colors.white54,
                            ),
                            onPressed: () {
                              setState(() {
                                _emojiShowing = !_emojiShowing;
                                if (_emojiShowing) {
                                  _focusNode.unfocus();
                                } else {
                                  _focusNode.requestFocus();
                                }
                              });
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: MatchFitTheme.accentGreen,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.send_rounded,
                        color: Colors.black,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Emoji Picker
          Offstage(
            offstage: !_emojiShowing,
            child: SizedBox(
              height: 250,
              child: EmojiPicker(
                textEditingController: _messageController,
                config: Config(
                  height: 250,
                  checkPlatformCompatibility: true,
                  emojiViewConfig: EmojiViewConfig(
                    backgroundColor: const Color(0xFF141414),
                    columns: 7,
                    emojiSizeMax: 32 * (foundation.defaultTargetPlatform == TargetPlatform.iOS ? 1.30 : 1.0),
                  ),
                  bottomActionBarConfig: const BottomActionBarConfig(
                    backgroundColor: Color(0xFF242424),
                    buttonColor: Color(0xFF242424),
                    buttonIconColor: Colors.white54,
                  ),
                  categoryViewConfig: const CategoryViewConfig(
                    backgroundColor: Color(0xFF141414),
                    indicatorColor: MatchFitTheme.accentGreen,
                    iconColorSelected: MatchFitTheme.accentGreen,
                    iconColor: Colors.white54,
                  ),
                  searchViewConfig: const SearchViewConfig(
                    backgroundColor: Color(0xFF141414),
                  ),
                  skinToneConfig: const SkinToneConfig(
                    dialogBackgroundColor: Color(0xFF1E1E1E),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
