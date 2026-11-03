import 'package:flutter/foundation.dart';

/// Interface abstrata para a fila de envio ("outbox") de partidas finalizadas.
/// Protege o fluxo de encerramento de partidas contra perdas e quedas de conexão.
abstract class MatchOutbox {
  /// Quantidade de partidas atualmente na fila aguardando upload.
  ValueListenable<int> get pending;

  /// Quantidade de partidas na fila com erro permanente (status 'failed').
  ValueListenable<int> get failed;

  /// Última mensagem de erro capturada durante a tentativa de envio (null se ok).
  ValueListenable<String?> get lastError;

  /// Enfileira uma partida finalizada localmente e agenda o envio assíncrono.
  Future<void> enqueue(Map<String, dynamic> job);

  /// Tenta enviar as partidas pendentes ao destino remoto ou banco local.
  Future<void> flush();

  /// Lê a fila em SharedPreferences e atualiza os ValueListenable pending e failed SEM enviar nada.
  Future<void> refreshCounts();

  /// Retorna os jobs que falharam com erro permanente (status 'failed').
  Future<List<Map<String, dynamic>>> failedJobs();

  /// Reinicia a tentativa de envio de um job failed (zera status/permanent_failures/attempts) e chama flush.
  Future<void> retryFailed(String matchId);

  /// Remove apenas aquele job e somente se ele estiver com status 'failed'; ignora silenciosamente se não for.
  Future<void> discardFailed(String matchId);
}
