import 'package:flutter/foundation.dart';

/// Interface abstrata para a fila de envio ("outbox") de partidas finalizadas.
/// Protege o fluxo de encerramento de partidas contra perdas e quedas de conexão.
abstract class MatchOutbox {
  /// Quantidade de partidas atualmente na fila aguardando upload.
  ValueListenable<int> get pending;

  /// Última mensagem de erro capturada durante a tentativa de envio (null se ok).
  ValueListenable<String?> get lastError;

  /// Enfileira uma partida finalizada localmente e agenda o envio assíncrono.
  Future<void> enqueue(Map<String, dynamic> job);

  /// Tenta enviar as partidas pendentes ao destino remoto ou banco local.
  Future<void> flush();
}
