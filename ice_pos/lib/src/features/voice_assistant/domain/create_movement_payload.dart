/// Parsed fields for [VoiceIntent.createMovement].
class CreateMovementPayload {
  const CreateMovementPayload({
    required this.type,
    required this.amount,
    required this.reason,
    this.account = 'CAJA',
  });

  /// ENTRADA | SALIDA
  final String type;
  final double amount;
  final String reason;
  /// CAJA | BANCO
  final String account;

  CreateMovementPayload copyWith({
    String? type,
    double? amount,
    String? reason,
    String? account,
  }) {
    return CreateMovementPayload(
      type: type ?? this.type,
      amount: amount ?? this.amount,
      reason: reason ?? this.reason,
      account: account ?? this.account,
    );
  }
}
