import 'event_models.dart';

/// Métodos de pago previstos para la compra de entradas.
enum EventPaymentMethod { yape, plin, card }

extension EventPaymentMethodCopy on EventPaymentMethod {
  String get label => switch (this) {
        EventPaymentMethod.yape => 'Yape',
        EventPaymentMethod.plin => 'Plin',
        EventPaymentMethod.card => 'Tarjeta',
      };

  String get description => switch (this) {
        EventPaymentMethod.yape => 'Paga con tu número de celular',
        EventPaymentMethod.plin => 'Escanea el código QR',
        EventPaymentMethod.card => 'Visa, Mastercard y más',
      };
}

enum EventPaymentStatus { success, pendingIntegration, failed }

class EventPaymentResult {
  const EventPaymentResult(this.status, {this.message});

  const EventPaymentResult.pendingIntegration()
      : this(
          EventPaymentStatus.pendingIntegration,
          message: 'La pasarela de pagos aún no está conectada. No se ha realizado ningún cobro ni se ha confirmado tu inscripción.',
        );

  const EventPaymentResult.failed([String? message])
      : this(EventPaymentStatus.failed, message: message);

  final EventPaymentStatus status;
  final String? message;
}

/// Contrato que deberá implementar la pasarela real.
///
/// La app solo inicia el checkout. La confirmación de la inscripción debe
/// ocurrir en el backend, después de validar el pago (webhook + service_role),
/// invocando `confirm_event_payment`. La app nunca confirma pagos por sí sola.
abstract class EventPaymentGateway {
  Future<EventPaymentResult> startCheckout({
    required Event event,
    required String userId,
    required EventPaymentMethod method,
  });
}

/// Implementación temporal: muestra la interfaz sin simular un pago real.
class PendingEventPaymentGateway implements EventPaymentGateway {
  const PendingEventPaymentGateway();

  @override
  Future<EventPaymentResult> startCheckout({
    required Event event,
    required String userId,
    required EventPaymentMethod method,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 650));
    return const EventPaymentResult.pendingIntegration();
  }
}

class EventPayments {
  EventPayments._();

  /// Punto de extensión para conectar Culqi, Mercado Pago, Niubiz, etc.
  static EventPaymentGateway gateway = const PendingEventPaymentGateway();
}
