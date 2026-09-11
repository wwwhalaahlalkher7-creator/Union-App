import 'package:flutter/material.dart';
import '../content/content_list_screen.dart';
import '../../data/repositories/content_repository.dart';

class AnnouncementsScreen extends StatelessWidget {
  const AnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ContentListScreen(
      titleKey: 'announcements',
      loader: (ContentRepository repo) => repo.announcements(),
      icon: Icons.campaign_outlined,
    );
  }
}
