import 'package:flutter/material.dart';

class GuidelineDetailScreen extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final Map<String, String>? keyInfo; // { 'title': '...', 'content': '...' }
  final Map<String, dynamic>?
      action; // { 'label': 'Show on Map', 'result': ... }

  const GuidelineDetailScreen({
    super.key,
    required this.title,
    required this.children,
    this.keyInfo,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ⭐️ --- 1. KEY INFO CARD --- ⭐️
            if (keyInfo != null)
              Container(
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lightbulb_outline,
                            color: Colors.amber.shade900),
                        const SizedBox(width: 8),
                        Text(
                          keyInfo!['title']!,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade900,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      keyInfo!['content']!,
                      style:
                          const TextStyle(color: Colors.black87, height: 1.4),
                    ),
                  ],
                ),
              ),

            // 2. MAIN CONTENT
            ...children,

            // ⭐️ --- 3. ACTION BUTTON --- ⭐️
            if (action != null) ...[
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.map),
                  label: Text(action!['label']),
                  onPressed: () {
                    // Pop twice (close Detail, close Guidelines)
                    // and send data back
                    Navigator.of(context).pop(action!['result']);
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],
          ],
        ),
      ),
    );
  }
}

// Helper widgets to make building the content easier
class GuidelineHeader extends StatelessWidget {
  final String text;
  const GuidelineHeader(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).primaryColor,
        ),
      ),
    );
  }
}

class GuidelineText extends StatelessWidget {
  final String text;
  const GuidelineText(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 16, height: 1.5),
    );
  }
}
