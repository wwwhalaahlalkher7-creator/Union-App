import 'package:flutter/material.dart';
import '../content/content_list_screen.dart';
import '../../data/repositories/content_repository.dart';

class NewsScreen extends StatelessWidget {
  const NewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ContentListScreen(
      titleKey: 'news',
      loader: (ContentRepository repo) => repo.news(),
      icon: Icons.article_outlined,
    );
  }
}
