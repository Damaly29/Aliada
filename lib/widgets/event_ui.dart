import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

const double eventCardRadius = 22;
const List<BoxShadow> eventCardShadow = [
  BoxShadow(color: Color(0x14000000), blurRadius: 18, offset: Offset(0, 8)),
];

/// Imagen de evento con placeholder, estados de carga y fallback local.
class EventImage extends StatelessWidget {
  const EventImage({
    super.key,
    this.imageUrl,
    this.height = 160,
    this.width,
    this.borderRadius,
  });

  final String? imageUrl;
  final double height;
  final double? width;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      height: height,
      width: width ?? double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
      ),
      child: const Center(child: Icon(Icons.event_available_rounded, color: Colors.white, size: 40)),
    );

    Widget image;
    final url = imageUrl?.trim() ?? '';
    if (url.isEmpty) {
      image = fallback;
    } else {
      image = Image.network(
        url,
        height: height,
        width: width ?? double.infinity,
        fit: BoxFit.cover,
        cacheWidth: 1000,
        filterQuality: FilterQuality.medium,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            height: height,
            width: width ?? double.infinity,
            color: AppColors.primarySoft,
            alignment: Alignment.center,
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: AppColors.primary,
                value: progress.expectedTotalBytes == null
                    ? null
                    : progress.cumulativeBytesLoaded / progress.expectedTotalBytes!,
              ),
            ),
          );
        },
        errorBuilder: (_, _, _) => fallback,
      );
    }

    if (borderRadius == null) return image;
    return ClipRRect(borderRadius: borderRadius!, child: image);
  }
}

/// Etiqueta compacta reutilizable para categorías, modalidad y precio.
class EventPill extends StatelessWidget {
  const EventPill({
    super.key,
    required this.label,
    this.icon,
    this.background = AppColors.primarySoft,
    this.foreground = AppColors.primaryDark,
    this.borderColor,
  });

  final String label;
  final IconData? icon;
  final Color background;
  final Color foreground;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(99),
        border: borderColor == null ? null : Border.all(color: borderColor!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: foreground),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppFonts.ui,
                fontWeight: FontWeight.w600,
                fontSize: 11.5,
                color: foreground,
                height: 1.15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Encabezado de sección con acción "Ver todo / Ver menos".
class EventSectionHeader extends StatelessWidget {
  const EventSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.actionIcon = Icons.arrow_forward_rounded,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData actionIcon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.h2.copyWith(fontSize: 19)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: AppText.caption),
                ],
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    actionLabel!,
                    style: const TextStyle(
                      fontFamily: AppFonts.ui,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(actionIcon, size: 16),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Botón circular flotante sobre imágenes (regresar, favorito, compartir).
class EventCircleButton extends StatelessWidget {
  const EventCircleButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.foreground = AppColors.text,
    this.background = Colors.white,
    this.size = 42,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final Color foreground;
  final Color background;
  final double size;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
        boxShadow: const [BoxShadow(color: Color(0x24000000), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Icon(icon, size: size * 0.48, color: foreground),
        ),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

/// Fila de información del detalle (fecha, horario, lugar, precio, etc.).
class EventInfoRow extends StatelessWidget {
  const EventInfoRow({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    this.subtitle,
    this.valueColor,
  });

  final IconData icon;
  final String title;
  final String value;
  final String? subtitle;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, size: 19, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppText.caption.copyWith(fontSize: 11.5)),
              const SizedBox(height: 1),
              Text(value, style: AppText.bodyStrong.copyWith(color: valueColor ?? AppColors.text)),
              if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                const SizedBox(height: 1),
                Text(subtitle!, style: AppText.caption),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Estado vacío / error reutilizable con acción opcional.
class EventEmptyState extends StatelessWidget {
  const EventEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(eventCardRadius),
        boxShadow: eventCardShadow,
      ),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
            child: Icon(icon, color: AppColors.primary, size: 27),
          ),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center, style: AppText.h3),
          const SizedBox(height: 4),
          Text(message, textAlign: TextAlign.center, style: AppText.caption.copyWith(height: 1.45)),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              height: 42,
              child: FilledButton(
                onPressed: onAction,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  textStyle: AppText.button.copyWith(fontSize: 13.5),
                ),
                child: Text(actionLabel!),
              ),
            ),
          ],
          if (secondaryActionLabel != null && onSecondaryAction != null) ...[
            const SizedBox(height: 4),
            TextButton(
              onPressed: onSecondaryAction,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                textStyle: AppText.caption.copyWith(fontWeight: FontWeight.w700, fontSize: 12.5),
              ),
              child: Text(secondaryActionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
