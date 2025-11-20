import 'package:flutter/material.dart';
import '../screens/guidelines_screen.dart';

class ResponsibleTourismDialog extends StatelessWidget {
  final bool isGuideRequired;

  const ResponsibleTourismDialog({
    super.key,
    this.isGuideRequired = false,
  });

  @override
  Widget build(BuildContext context) {
    final guideSubtitle = isGuideRequired
        ? 'This destination requires an accredited guide.'
        : 'For certain sites, a guide may be required. Please verify at the Tourism Office.';

    final primaryColor = Theme.of(context).primaryColor;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      insetPadding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 24,
      ),
      contentPadding: EdgeInsets.zero,
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // GIF Animation
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                child: Image.asset(
                  'assets/gifs/tourist_walk.gif',
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 20),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    Text(
                      'Be a Responsible Tourist!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Information List
                    ListTile(
                      leading: Icon(Icons.app_registration,
                          color: Colors.blue.shade700),
                      title: const Text('Register First',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text(
                          'Always register at the Municipal Tourism Office before proceeding.'),
                      dense: true,
                    ),
                    ListTile(
                      leading: Icon(Icons.person_search,
                          color: Colors.green.shade700),
                      title: const Text('Secure a Guide',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(guideSubtitle),
                      dense: true,
                    ),
                    ListTile(
                      leading: Icon(Icons.eco, color: Colors.orange.shade700),
                      title: const Text('Leave No Trace',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text(
                          'Respect environment & local culture. Take your trash with you.'),
                      dense: true,
                    ),
                    const SizedBox(height: 5),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        Column(
          children: [
            // "Read Full Guidelines" button
            TextButton(
              child: const Text('Read Full Tour Guidelines'),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const GuidelinesScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 4),

            // "I Understand" button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                child: const Text('I Understand'),
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ),
          ],
        )
      ],
    );
  }
}
