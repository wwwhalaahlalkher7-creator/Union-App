import 'package:flutter/material.dart';
import '../content/content_list_screen.dart';
import '../../data/repositories/content_repository.dart';

class ActivitiesScreen extends StatelessWidget {
  const ActivitiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ContentListScreen(
      titleKey: 'activities',
      loader: (ContentRepository repo) => repo.activities(),
      icon: Icons.event_outlined,
    );
  }
}
