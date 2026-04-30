import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:matchfit/core/theme.dart';
import '../../content/repositories/content_manager_repository.dart';

class ShareEventPostScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> event;

  const ShareEventPostScreen({super.key, required this.event});

  @override
  ConsumerState<ShareEventPostScreen> createState() => _ShareEventPostScreenState();
}

class _ShareEventPostScreenState extends ConsumerState<ShareEventPostScreen> {
  final TextEditingController _captionController = TextEditingController();
  String _visibility = 'public';
  bool _isPosting = false;

  String get _sportName => widget.event['sports']?['name'] as String? ?? 'Sport';
  String get _eventTitle => widget.event['title'] as String? ?? 'Event';
  String get _location => widget.event['location_name'] as String? ?? 'Unknown';
  String get _date => widget.event['event_date'] as String? ?? '';

  IconData get _sportIcon {
    switch (_sportName.toLowerCase()) {
      case 'tennis': return Icons.sports_tennis;
      case 'running': return Icons.directions_run;
      case 'basketball': return Icons.sports_basketball;
      case 'football': return Icons.sports_soccer;
      default: return Icons.sports;
    }
  }

  Future<void> _publish() async {
    setState(() => _isPosting = true);
    try {
      final contentManager = ref.read(contentManagerProvider);
      await contentManager.createEventPost(
        eventId: widget.event['id'].toString(),
        caption: _captionController.text.isEmpty
            ? 'Just completed a ${_sportName} session! 🏆'
            : _captionController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_outline, color: Colors.black),
                SizedBox(width: 8),
                Text('@ContentManager: Post shared!'),
              ],
            ),
            backgroundColor: MatchFitTheme.accentGreen,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not post: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Share Moment', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              onPressed: _isPosting ? null : _publish,
              style: FilledButton.styleFrom(
                backgroundColor: MatchFitTheme.accentGreen,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: _isPosting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Text('Publish', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // @ContentManager Banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: MatchFitTheme.accentGreen.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: MatchFitTheme.accentGreen.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: MatchFitTheme.accentGreen, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '@ContentManager will auto-enrich this post with event data.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Auto-generated Event Data Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    MatchFitTheme.primaryBlue.withOpacity(0.25),
                    MatchFitTheme.primaryBlue.withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: MatchFitTheme.primaryBlue.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: MatchFitTheme.accentGreen.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(_sportIcon, color: MatchFitTheme.accentGreen, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _eventTitle,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                            ),
                            Text(
                              _sportName,
                              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: MatchFitTheme.accentGreen,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'COMPLETED',
                          style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white12),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _DataChip(icon: Icons.location_on_outlined, label: _location),
                      const SizedBox(width: 8),
                      _DataChip(icon: Icons.calendar_today_outlined, label: _date),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Caption Input
            const Text('Add a caption', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            TextField(
              controller: _captionController,
              maxLines: 4,
              maxLength: 280,
              decoration: InputDecoration(
                hintText: 'How was it? Share the experience...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: MatchFitTheme.accentGreen),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
              ),
            ),
            const SizedBox(height: 24),

            // Visibility Toggle
            const Text('Who can see this?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            Row(
              children: [
                _VisibilityChip(
                  icon: Icons.public,
                  label: 'Public',
                  value: 'public',
                  selected: _visibility,
                  onTap: (v) => setState(() => _visibility = v),
                ),
                const SizedBox(width: 10),
                _VisibilityChip(
                  icon: Icons.people_outline,
                  label: 'Friends Only',
                  value: 'friends_only',
                  selected: _visibility,
                  onTap: (v) => setState(() => _visibility = v),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DataChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _DataChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.white54),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    );
  }
}

class _VisibilityChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String selected;
  final void Function(String) onTap;

  const _VisibilityChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = value == selected;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? MatchFitTheme.accentGreen.withOpacity(0.15) : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? MatchFitTheme.accentGreen : Colors.white12,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: isSelected ? MatchFitTheme.accentGreen : Colors.white54),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? MatchFitTheme.accentGreen : Colors.white60,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
