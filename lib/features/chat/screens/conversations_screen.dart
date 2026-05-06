import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:matchfit/core/theme.dart';
import 'package:matchfit/core/widgets/avatar_widget.dart';
import '../repositories/chat_repository.dart';
import 'package:intl/intl.dart';

class ConversationsScreen extends ConsumerWidget {
  const ConversationsScreen({super.key});

  String _formatTime(String? isoString) {
    if (isoString == null) return '';
    final dt = DateTime.parse(isoString).toLocal();
    final now = DateTime.now();
    final difference = now.difference(dt);

    if (difference.inDays == 0 && now.day == dt.day) {
      return DateFormat('HH:mm').format(dt);
    } else if (difference.inDays < 7) {
      return DateFormat('EEEE').format(dt); // Gün adı
    } else {
      return DateFormat('dd MMM').format(dt);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(conversationsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Mesajlar',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () {
              // Could open a search for friends to start a chat
              context.push('/user-search');
            },
          ),
        ],
      ),
      body: conversationsAsync.when(
        data: (conversations) {
          if (conversations.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 64,
                    color: Colors.white24,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Henüz mesaj yok',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Arkadaşlarınla mesajlaşmaya başla!',
                    style: TextStyle(color: Colors.white38),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(conversationsProvider);
            },
            color: MatchFitTheme.accentGreen,
            child: ListView.builder(
              itemCount: conversations.length,
              itemBuilder: (context, index) {
                final chat = conversations[index];
                final userId = chat['user_id'];
                final fullName = chat['full_name'] ?? 'Kullanıcı';
                final avatarUrl = chat['avatar_url'];
                final lastMessage = chat['last_message'] ?? '';
                final unreadCount = chat['unread_count'] as int? ?? 0;
                final time = _formatTime(chat['last_message_time']);

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  leading: AvatarWidget(
                    name: fullName,
                    avatarUrl: avatarUrl,
                    radius: 26,
                  ),
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          fullName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        time,
                        style: TextStyle(
                          color: unreadCount > 0 ? MatchFitTheme.accentGreen : Colors.white38,
                          fontSize: 12,
                          fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            lastMessage,
                            style: TextStyle(
                              color: unreadCount > 0 ? Colors.white : Colors.white54,
                              fontSize: 14,
                              fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (unreadCount > 0)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: MatchFitTheme.accentGreen,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              unreadCount.toString(),
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  onTap: () {
                    context.push(
                      '/chat',
                      extra: {
                        'targetUserId': userId,
                        'targetUserName': fullName,
                        'targetAvatarUrl': avatarUrl,
                      },
                    ).then((_) {
                      // Refresh conversations when coming back
                      ref.invalidate(conversationsProvider);
                    });
                  },
                );
              },
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: MatchFitTheme.accentGreen),
        ),
        error: (e, _) => Center(
          child: Text(
            'Hata: $e',
            style: const TextStyle(color: Colors.red),
          ),
        ),
      ),
    );
  }
}
