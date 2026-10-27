import 'package:flutter/material.dart';
import '../content/content_list_screen.dart';
import '../../data/repositories/content_repository.dart';

class EventsScreen extends StatelessWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ContentListScreen(
      titleKey: 'events',
      loader: (ContentRepository repo) => repo.events(),
      icon: Icons.event_outlined,
    );
  }
}
