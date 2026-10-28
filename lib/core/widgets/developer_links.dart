import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_colors.dart';
import 'arabic_text.dart';

class DeveloperLinks extends StatefulWidget {
  final bool dark;
  const DeveloperLinks({super.key, this.dark = false});
  @override
  State<DeveloperLinks> createState() => _DeveloperLinksState();
}

class _DeveloperLinksState extends State<DeveloperLinks> {
  // Supply the real links at build time; absent links remain visibly disabled.
  static const _website = String.fromEnvironment(
    'AGENDA_WEBSITE',
    defaultValue: 'https://ahkam.app/',
  );
  static const _linkedin = String.fromEnvironment(
    'AGENDA_LINKEDIN',
    defaultValue: 'https://www.linkedin.com/in/moateflawyer/',
  );
  static const _github = String.fromEnvironment(
    'AGENDA_GITHUB',
    defaultValue: 'https://github.com/matef-hub',
  );
  String? _error;

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !(uri.scheme == 'https' || uri.scheme == 'http') ||
        uri.host.isEmpty) {
      setState(() => _error = 'رابط غير صالح.');
      return;
    }
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw StateError('Cannot open link');
      }
      if (mounted) setState(() => _error = null);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر فتح الرابط على هذا الجهاز.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.dark ? Colors.white : AppColors.primaryOlive;
    Widget link(FaIconData icon, String name, String url) => IconButton(
      tooltip: url.isEmpty ? '$name — لم يُضف الرابط بعد' : name,
      onPressed: url.isEmpty ? null : () => _open(url),
      color: color,
      disabledColor: color.withValues(alpha: .35),
      icon: FaIcon(icon, size: 18),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            link(FontAwesomeIcons.globe, 'الموقع الإلكتروني', _website),
            link(FontAwesomeIcons.linkedin, 'LinkedIn', _linkedin),
            link(FontAwesomeIcons.github, 'GitHub', _github),
          ],
        ),
        if (_error != null)
          ArabicText(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: color, fontSize: 11),
          ),
      ],
    );
  }
}
