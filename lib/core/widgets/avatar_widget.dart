import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:matchfit/core/theme.dart';


class AvatarUploadService {
  static final _sb = Supabase.instance.client;

  static Future<String?> uploadAvatar(String userId, XFile file) async {
    final bytes = await file.readAsBytes();
    final ext = file.name.split('.').last.toLowerCase();
    final path = '$userId/avatar.$ext';

    // Overwrite if exists
    await _sb.storage.from('avatars').uploadBinary(
      path,
      bytes,
      fileOptions: const FileOptions(upsert: true),
    );

    final publicUrl = _sb.storage.from('avatars').getPublicUrl(path);

    // Update profile
    await _sb.from('profiles').update({'avatar_url': publicUrl}).eq('id', userId);

    return publicUrl;
  }
}

// ── Avatar Widget (with optional edit button) ─────────────────────

class AvatarWidget extends StatefulWidget {
  final String name;
  final double radius;
  final String? avatarUrl;
  final bool editable;
  final String? userId;
  final void Function(String newUrl)? onUploaded;

  const AvatarWidget({
    super.key,
    required this.name,
    this.radius = 36,
    this.avatarUrl,
    this.editable = false,
    this.userId,
    this.onUploaded,
  });

  @override
  State<AvatarWidget> createState() => _AvatarWidgetState();
}

class _AvatarWidgetState extends State<AvatarWidget> {
  bool _uploading = false;
  String? _localUrl;

  @override
  void initState() {
    super.initState();
    _localUrl = widget.avatarUrl;
  }

  Future<void> _pickAndUpload() async {
    if (widget.userId == null) return;

    final picker = ImagePicker();
    final XFile? file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );

    if (file == null) return;

    setState(() => _uploading = true);

    try {
      final url = await AvatarUploadService.uploadAvatar(widget.userId!, file);
      if (mounted && url != null) {
        setState(() => _localUrl = url);
        widget.onUploaded?.call(url);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(children: [
              Icon(Icons.check_circle, color: Colors.black),
              SizedBox(width: 8),
              Text('Profile photo updated!'),
            ]),
            backgroundColor: MatchFitTheme.accentGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  String _initials() {
    final parts = widget.name.trim().split(' ').where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final rawUrl = _localUrl ?? widget.avatarUrl;
    // Only trust Supabase Storage URLs — external URLs fail on Flutter Web CanvasKit
    final isSupabaseUrl = rawUrl != null && rawUrl.contains('supabase.co');
    final hasImage = isSupabaseUrl;

    return GestureDetector(
      onTap: widget.editable ? _pickAndUpload : null,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Avatar circle
          Container(
            width: widget.radius * 2,
            height: widget.radius * 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: MatchFitTheme.accentGreen, width: 3),
              gradient: hasImage
                  ? null
                  : const LinearGradient(
                      colors: [Color(0xFF0052FF), Color(0xFF003DB0)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
            ),
            child: ClipOval(
              child: _uploading
                  ? Container(
                      color: Colors.black54,
                      child: const Center(
                        child: CircularProgressIndicator(
                            color: MatchFitTheme.accentGreen, strokeWidth: 2),
                      ),
                    )
                  : hasImage
                      ? Image.network(
                          rawUrl!,
                          fit: BoxFit.cover,
                          width: widget.radius * 2,
                          height: widget.radius * 2,
                          errorBuilder: (_, __, ___) => _initialsWidget(),
                        )
                      : _initialsWidget(),
            ),
          ),

          // Verified badge (bottom right)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: widget.radius * 0.5,
              height: widget.radius * 0.5,
              decoration: BoxDecoration(
                color: MatchFitTheme.accentGreen,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF121212), width: 2),
              ),
              child: Icon(
                widget.editable ? Icons.camera_alt : Icons.verified,
                size: widget.radius * 0.26,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _initialsWidget() {
    return Center(
      child: Text(
        _initials(),
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: widget.radius * 0.65,
        ),
      ),
    );
  }
}
