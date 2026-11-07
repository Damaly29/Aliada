import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/app_theme.dart';
import 'event_models.dart';

String eventShareText(Event event) {
  final location = event.address == null || event.address!.isEmpty
      ? event.venue
      : '${event.venue}, ${event.address}';
  return [
    '💜 ${event.title}',
    '${formatEventDateLong(event.startAt)} · ${formatEventRange(event)}',
    location,
    event.priceLabel,
    '',
    'Lo vi en Aliada.',
  ].join('\n');
}

Future<void> showEventShareSheet(BuildContext context, Event event) async {
  final messenger = ScaffoldMessenger.of(context);
  final text = eventShareText(event);

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (sheetContext) {
      void close() => Navigator.of(sheetContext).pop();

      Future<void> openUrl(Uri uri) async {
        close();
        try {
          final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
          if (!opened) {
            messenger.showSnackBar(const SnackBar(content: Text('No pudimos abrir la aplicación.')));
          }
        } catch (_) {
          messenger.showSnackBar(const SnackBar(content: Text('No pudimos abrir la aplicación.')));
        }
      }

      return SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(color: AppColors.grayLight, borderRadius: BorderRadius.circular(99)),
                ),
              ),
              const SizedBox(height: 18),
              Text('Compartir evento', style: AppText.h2.copyWith(fontSize: 20)),
              const SizedBox(height: 4),
              Text(event.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.caption),
              const SizedBox(height: 16),
              _ShareOption(
                icon: Icons.copy_rounded,
                title: 'Copiar texto',
                subtitle: 'Pega los detalles en cualquier app',
                onTap: () async {
                  try {
                    await Clipboard.setData(ClipboardData(text: text));
                    close();
                    messenger.showSnackBar(const SnackBar(content: Text('Texto del evento copiado.')));
                  } catch (_) {
                    close();
                    messenger.showSnackBar(const SnackBar(content: Text('No pudimos copiar el texto del evento.')));
                  }
                },
              ),
              _ShareOption(
                icon: Icons.chat_rounded,
                title: 'WhatsApp',
                subtitle: 'Envíaselo a tus amigas',
                onTap: () => openUrl(Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}')),
              ),
              _ShareOption(
                icon: Icons.mail_outline_rounded,
                title: 'Correo',
                subtitle: 'Comparte por email',
                onTap: () => openUrl(
                  Uri(scheme: 'mailto', queryParameters: {'subject': event.title, 'body': text}),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _ShareOption extends StatelessWidget {
  const _ShareOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.backgroundSoft,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppText.bodyStrong),
                      Text(subtitle, style: AppText.caption),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.gray),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
