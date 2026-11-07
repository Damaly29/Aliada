import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// Hoja inferior con PIN de 4 dígitos. Devuelve true si `verify` lo acepta.
Future<bool> showPinSheet(BuildContext context, {required String title, required bool Function(String) verify}) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _PinPad(title: title, verify: verify),
  );
  return ok ?? false;
}

class _PinPad extends StatefulWidget {
  const _PinPad({required this.title, required this.verify});
  final String title;
  final bool Function(String) verify;
  @override
  State<_PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<_PinPad> {
  String _pin = '';
  String? _error;

  void _press(String k) {
    HapticFeedback.selectionClick();
    setState(() {
      _error = null;
      if (k == 'del') {
        if (_pin.isNotEmpty) _pin = _pin.substring(0, _pin.length - 1);
        return;
      }
      if (_pin.length < 4) _pin += k;
    });
    if (_pin.length == 4) {
      if (widget.verify(_pin)) {
        Navigator.pop(context, true);
      } else {
        HapticFeedback.heavyImpact();
        setState(() {
          _pin = '';
          _error = 'PIN incorrecto. Intenta otra vez.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', 'del'];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.grayLight, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text(widget.title, style: AppText.h3, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          const Text('Ingresa tu PIN de 4 dígitos', style: AppText.caption),
          const SizedBox(height: 18),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 0; i < 4; i++)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < _pin.length ? AppColors.primary : Colors.transparent,
                  border: Border.all(color: AppColors.primary, width: 1.5),
                ),
              ),
          ]),
          SizedBox(height: 26, child: Center(child: Text(_error ?? '', style: AppText.caption.copyWith(color: AppColors.danger)))),
          SizedBox(
            width: 260,
            child: GridView.count(
              shrinkWrap: true,
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (final k in keys)
                  k.isEmpty
                      ? const SizedBox()
                      : InkResponse(
                          onTap: () => _press(k),
                          radius: 36,
                          child: Center(
                            child: k == 'del'
                                ? const Icon(Icons.backspace_outlined, color: AppColors.text)
                                : Text(k, style: const TextStyle(fontFamily: AppFonts.title, fontSize: 26, color: AppColors.text)),
                          ),
                        ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}
