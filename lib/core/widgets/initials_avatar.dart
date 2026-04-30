import 'package:flutter/material.dart';
import 'package:matchfit/core/theme.dart';

/// Reusable avatar widget that displays user initials instead of
/// relying on external image services like i.pravatar.cc (which are
/// blocked by CORS in web environments).
class InitialsAvatar extends StatelessWidget {
  final String name;
  final double radius;
  final Color? backgroundColor;
  final double? fontSize;

  const InitialsAvatar({
    super.key,
    required this.name,
    this.radius = 20,
    this.backgroundColor,
    this.fontSize,
  });

  String get _initials {
    final parts = name.trim().split(' ').where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? MatchFitTheme.primaryBlue,
      child: Text(
        _initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: fontSize ?? (radius * 0.7),
        ),
      ),
    );
  }
}
