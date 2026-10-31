import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';

/// سياسة الخصوصية (نفس النص المنشور في docs/privacy-policy.html).
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TaybahColors.background,
      appBar: AppBar(
        title: Text('سياسة الخصوصية',
            style: GoogleFonts.cairo(fontSize: 19, fontWeight: FontWeight.bold)),
      ),
      body: FutureBuilder<String>(
        future: rootBundle.loadString('assets/data/privacy_policy.md'),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final widgets = <Widget>[];
          for (final raw in snap.data!.split('\n')) {
            final line = raw.trimRight();
            if (line.isEmpty || line.startsWith('# ')) continue;
            if (line.startsWith('## ')) {
              widgets.add(Padding(
                padding: const EdgeInsets.only(top: 18, bottom: 6),
                child: Text(line.substring(3),
                    style: GoogleFonts.cairo(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: TaybahColors.primary)),
              ));
              continue;
            }
            final isBullet = line.startsWith('- ');
            final text = (isBullet ? '• ${line.substring(2)}' : line)
                .replaceAll('**', '');
            widgets.add(Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(text,
                  style: GoogleFonts.cairo(
                      fontSize: 14,
                      height: 1.8,
                      color: TaybahColors.textSecondary)),
            ));
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            children: widgets,
          );
        },
      ),
    );
  }
}
