import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../core/cloud.dart';
import '../features/events/event_models.dart';
import '../features/events/event_payment.dart';
import '../theme/app_theme.dart';
import 'event_ui.dart';

/// Interfaz de compra de una entrada. No confirma pagos: sólo inicia el checkout.
Future<void> showEventCheckoutSheet(BuildContext context, Event event) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _EventCheckoutSheet(event: event),
  );
}

class _EventCheckoutSheet extends StatefulWidget {
  const _EventCheckoutSheet({required this.event});

  final Event event;

  @override
  State<_EventCheckoutSheet> createState() => _EventCheckoutSheetState();
}

class _EventCheckoutSheetState extends State<_EventCheckoutSheet>
    with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  EventPaymentMethod _method = EventPaymentMethod.yape;
  bool _processing = false;
  bool _checkingStatus = false;
  bool _paymentExpired = false;
  String? _createdOrderId;
  WebViewController? _checkoutController;
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    final user = Cloud.instance.ready.value
        ? Cloud.instance.db.auth.currentUser
        : null;
    _emailController = TextEditingController(text: user?.email ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _createdOrderId != null) {
      unawaited(_refreshPaymentStatus());
    }
  }

  Future<void> _continue() async {
    if (_processing || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _processing = true);

    EventPaymentResult result;
    try {
      result = await EventPayments.gateway.startCheckout(
        event: widget.event,
        userId: Cloud.instance.uid ?? '',
        method: _method,
        payerEmail: _emailController.text.trim(),
        payerPhone: _phoneController.text.trim(),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _processing = false);
      await _showResultDialog(
        title: 'No pudimos iniciar el pago',
        message:
            'Inténtalo de nuevo en unos minutos. No se realizó ningún cobro.',
      );
      return;
    }
    if (!mounted) return;
    setState(() => _processing = false);

    if (result.status == EventPaymentStatus.pendingIntegration) {
      await _showResultDialog(
        title: 'Pago de prueba no disponible',
        message: result.message ?? 'La pasarela de pagos aún no está conectada. No se realizó ningún cobro ni se confirmó tu inscripción.',
      );
    } else if (result.status == EventPaymentStatus.failed) {
      await _showResultDialog(
        title: 'No pudimos iniciar el pago',
        message: result.message ?? 'Inténtalo de nuevo en unos minutos.',
      );
    } else if (result.status == EventPaymentStatus.checkoutReady &&
        result.checkoutUrl != null &&
        result.orderId != null) {
      _createdOrderId = result.orderId;
      _paymentExpired = false;
      _checkoutController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(AppColors.backgroundSoft)
        ..loadRequest(result.checkoutUrl!);
      _statusTimer?.cancel();
      _statusTimer = Timer.periodic(const Duration(seconds: 4), (_) {
        unawaited(_refreshPaymentStatus());
      });
      setState(() {});
    }
  }

  Future<void> _showResultDialog({
    required String title,
    required String message,
  }) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          10,
          20,
          18 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.grayLight,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Confirmar compra',
                    style: AppText.h2.copyWith(fontSize: 20),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: AppColors.gray),
                  tooltip: 'Cerrar',
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.backgroundSoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  EventImage(
                    imageUrl: event.imageUrl,
                    height: 74,
                    width: 88,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.bodyStrong,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          formatEventDateChip(event.startAt),
                          style: AppText.caption,
                        ),
                        Text(
                          event.venue,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.caption,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.backgroundSoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _PriceRow(label: 'Entrada general', value: event.priceLabel),
                  const SizedBox(height: 8),
                  const _PriceRow(
                    label: 'Cargo por servicio',
                    value: 'S/ 0.00',
                  ),
                  const Divider(height: 22, color: AppColors.border),
                  _PriceRow(
                    label: 'Total',
                    value: event.priceLabel,
                    bold: true,
                  ),
                ],
              ),
            ),
            if (_createdOrderId != null) ...[
              const SizedBox(height: 14),
              Container(
                height: 430,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: AppColors.backgroundSoft,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                ),
                child: _checkoutController == null
                    ? const Center(child: CircularProgressIndicator())
                    : WebViewWidget(controller: _checkoutController!),
              ),
              const SizedBox(height: 10),
              Text(
                'Completa el pago aquí. La inscripción se confirmará cuando Culqi valide la operación.',
                textAlign: TextAlign.center,
                style: AppText.caption.copyWith(height: 1.4),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _processing ? null : _checkPayment,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Verificar pago'),
              ),
            ] else ...[
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Correo electrónico',
                      ),
                      validator: (value) =>
                          RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                              .hasMatch((value ?? '').trim())
                          ? null
                          : 'Escribe un correo válido',
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Celular peruano',
                      ),
                      validator: (value) {
                        final digits = (value ?? '').replaceAll(
                          RegExp(r'\D'),
                          '',
                        );
                        return digits.length == 9 ||
                                (digits.length == 11 && digits.startsWith('51'))
                            ? null
                            : 'Escribe un celular peruano válido';
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text('Método de pago', style: AppText.h3.copyWith(fontSize: 15)),
              const SizedBox(height: 8),
              for (final method in EventPaymentMethod.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _PaymentMethodTile(
                    method: method,
                    selected: _method == method,
                    onTap: () => setState(() => _method = method),
                  ),
                ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.lock_outline_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Pago seguro de prueba. La inscripción solo se confirma cuando Culqi valida el pago.',
                        style: AppText.caption.copyWith(
                          color: AppColors.primaryDark,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _processing ? null : _continue,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.primary.withValues(
                      alpha: 0.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: AppText.button.copyWith(fontSize: 15),
                  ),
                  child: _processing
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _paymentExpired
                              ? 'Crear otra orden'
                              : 'Continuar al pago',
                        ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Para eventos de pago, la inscripción se activa únicamente después de validar el pago.',
                textAlign: TextAlign.center,
                style: AppText.caption.copyWith(height: 1.4),
              ),
              if (_paymentExpired)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'La orden venció. Puedes intentarlo otra vez.',
                    textAlign: TextAlign.center,
                    style: AppText.caption.copyWith(
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _checkPayment() async {
    if (_processing) return;
    setState(() => _processing = true);
    final status = await _refreshPaymentStatus();
    if (!mounted) return;
    setState(() => _processing = false);
    if (status == EventOrderStatus.pending) {
      await _showResultDialog(
        title: 'Pago en proceso',
        message: 'Aún no llega la confirmación de Culqi. Tu inscripción está pendiente y se actualizará en Agenda cuando se valide.',
      );
    } else if (status == null) {
      await _showResultDialog(
        title: 'No pudimos revisar el pago',
        message: 'Revisa tu conexión e inténtalo otra vez.',
      );
    }
  }

  Future<EventOrderStatus?> _refreshPaymentStatus() async {
    final orderId = _createdOrderId;
    if (orderId == null || _checkingStatus) return null;
    _checkingStatus = true;
    EventOrderStatus? status;
    try {
      status = await EventPayments.gateway.paymentStatus(orderId);
    } catch (_) {
      status = null;
    } finally {
      _checkingStatus = false;
    }
    if (!mounted || status == null) return status;
    if (status == EventOrderStatus.paid) {
      _statusTimer?.cancel();
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('¡Pago confirmado! Ya estás inscrita.')),
      );
    } else if (status == EventOrderStatus.expired) {
      _statusTimer?.cancel();
      setState(() {
        _createdOrderId = null;
        _checkoutController = null;
        _paymentExpired = true;
      });
    }
    return status;
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: bold ? AppText.bodyStrong : AppText.body),
        ),
        Text(
          value,
          style: bold
              ? AppText.h3.copyWith(color: AppColors.primary, fontSize: 16)
              : AppText.bodyStrong,
        ),
      ],
    );
  }
}

class _PaymentMethodTile extends StatelessWidget {
  const _PaymentMethodTile({
    required this.method,
    required this.selected,
    required this.onTap,
  });

  final EventPaymentMethod method;
  final bool selected;
  final VoidCallback onTap;

  IconData get _icon => switch (method) {
    EventPaymentMethod.yape => Icons.phone_android_rounded,
    EventPaymentMethod.plin => Icons.qr_code_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primarySoft : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: selected ? Colors.white : AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(method.label, style: AppText.bodyStrong),
                    Text(method.description, style: AppText.caption),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected ? AppColors.primary : AppColors.gray,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
