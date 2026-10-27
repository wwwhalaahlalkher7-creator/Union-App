import 'package:flutter/material.dart';
import '../content/content_list_screen.dart';
import '../../data/repositories/content_repository.dart';

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ContentListScreen(
      titleKey: 'achievements',
      loader: (ContentRepository repo) => repo.achievements(),
      icon: Icons.emoji_events_outlined,
    );
  }
}
