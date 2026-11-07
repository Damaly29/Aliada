import '../../core/cloud.dart';
import 'event_models.dart';

enum EventPaymentMethod { yape, plin }

extension EventPaymentMethodCopy on EventPaymentMethod {
  String get label => switch (this) {
    EventPaymentMethod.yape => 'Yape',
    EventPaymentMethod.plin => 'Plin',
  };

  String get description => switch (this) {
    EventPaymentMethod.yape => 'Paga con el QR de Yape',
    EventPaymentMethod.plin => 'Paga con el QR de Plin',
  };
}

enum EventPaymentStatus { checkoutReady, pendingIntegration, failed }

enum EventOrderStatus { pending, paid, expired }

class EventPaymentResult {
  const EventPaymentResult(
    this.status, {
    this.message,
    this.checkoutUrl,
    this.orderId,
  });

  const EventPaymentResult.pendingIntegration([String? message])
    : this(
        EventPaymentStatus.pendingIntegration,
        message: message ?? 'No está configurado el pago de prueba en Supabase. No se hizo ningún cobro.',
      );

  const EventPaymentResult.failed([String? message])
    : this(EventPaymentStatus.failed, message: message);

  final EventPaymentStatus status;
  final String? message;
  final Uri? checkoutUrl;
  final String? orderId;
}

abstract class EventPaymentGateway {
  Future<EventPaymentResult> startCheckout({
    required Event event,
    required String userId,
    required EventPaymentMethod method,
    required String payerEmail,
    required String payerPhone,
  });

  Future<EventOrderStatus?> paymentStatus(String orderId);
}

class CulqiEventPaymentGateway implements EventPaymentGateway {
  const CulqiEventPaymentGateway();

  @override
  Future<EventPaymentResult> startCheckout({
    required Event event,
    required String userId,
    required EventPaymentMethod method,
    required String payerEmail,
    required String payerPhone,
  }) async {
    try {
      final response = await Cloud.instance.db.functions.invoke(
        'event-payment',
        body: {
          'action': 'create-order',
          'event_id': event.id,
          'payment_method': method.name,
          'payer_email': payerEmail.trim(),
          'payer_phone': payerPhone.trim(),
        },
      );
      final data = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : const <String, dynamic>{};
      if (response.status < 200 || response.status >= 300) {
        return EventPaymentResult.failed(
          data['message']?.toString() ?? 'No pudimos iniciar el pago.',
        );
      }
      final url = Uri.tryParse(data['checkout_url']?.toString() ?? '');
      final orderId = data['order_id']?.toString();
      if (url == null ||
          url.scheme != 'https' ||
          orderId == null ||
          orderId.isEmpty) {
        return EventPaymentResult.failed('Culqi no devolvió una orden válida.');
      }
      return EventPaymentResult(
        EventPaymentStatus.checkoutReady,
        checkoutUrl: url,
        orderId: orderId,
      );
    } catch (_) {
      return const EventPaymentResult.pendingIntegration();
    }
  }

  @override
  Future<EventOrderStatus?> paymentStatus(String orderId) async {
    final response = await Cloud.instance.db.functions.invoke(
      'event-payment',
      body: {'action': 'payment-status', 'order_id': orderId},
    );
    if (response.status < 200 ||
        response.status >= 300 ||
        response.data is! Map) {
      return null;
    }
    final data = response.data as Map;
    return switch (data['status']) {
      'paid' => EventOrderStatus.paid,
      'expired' => EventOrderStatus.expired,
      'pending' => EventOrderStatus.pending,
      _ => null,
    };
  }
}

class EventPayments {
  EventPayments._();

  static const EventPaymentGateway gateway = CulqiEventPaymentGateway();
}
