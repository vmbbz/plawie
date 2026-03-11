import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Documentation'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      backgroundColor: const Color(0xFF0D1B2A),
      body: FutureBuilder<String>(
        future: rootBundle.loadString('README.md'),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Failed to load documentation.',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            );
          }

          final content = snapshot.data ?? 'No content available.';

          return Markdown(
            data: content,
            selectable: true,
            styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
              p: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
              h1: theme.textTheme.headlineMedium?.copyWith(
                  color: Colors.white, fontWeight: FontWeight.bold),
              h2: theme.textTheme.headlineSmall?.copyWith(
                  color: Colors.white, fontWeight: FontWeight.bold),
              h3: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white, fontWeight: FontWeight.bold),
              codeblockDecoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(8),
              ),
              code: theme.textTheme.bodyMedium?.copyWith(
                backgroundColor: Colors.transparent,
                color: Colors.greenAccent,
                fontFamily: 'monospace',
              ),
              blockquoteDecoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: theme.colorScheme.primary, width: 4),
                ),
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
            onTapLink: (text, url, title) {
              if (url != null && url.startsWith('http')) {
                launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
              }
            },
          );
        },
      ),
    );
  }
}
