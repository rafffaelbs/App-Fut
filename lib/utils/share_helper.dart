import 'dart:typed_data';

import 'share_helper_stub.dart'
    if (dart.library.io) 'share_helper_io.dart' as impl;

/// Compartilha a imagem do ranking renderizada via bytes.
///
/// No celular/desktop (IO), grava em arquivo temporário e abre o diálogo nativo do sistema via `share_plus`.
/// Na web, lança [UnsupportedError] caso invocado indevidamente (o botão deve ser ocultado na interface).
Future<void> shareRankingImage(Uint8List imageBytes) =>
    impl.shareRankingImage(imageBytes);

/// Exporta o histórico completo de partidas em formato JSON indentado.
///
/// No celular/desktop (IO), grava o JSON em arquivo temporário e abre o diálogo nativo de compartilhamento.
/// Na web, lança [UnsupportedError] caso invocado indevidamente (o botão deve ser ocultado na interface).
Future<void> exportHistoryJson(String jsonString) =>
    impl.exportHistoryJson(jsonString);
