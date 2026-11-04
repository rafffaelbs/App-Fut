import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> shareRankingImage(Uint8List imageBytes) async {
  final dir = await getTemporaryDirectory();
  final file = await File(
    '${dir.path}/ranking_pelada.png',
  ).writeAsBytes(imageBytes);

  await Share.shareXFiles([
    XFile(file.path),
  ], text: 'Ranking da Pelada 🏆⚽');
}

Future<void> exportHistoryJson(String jsonString) async {
  final directory = await getTemporaryDirectory();
  final file = File('${directory.path}/match_history_full.json');
  await file.writeAsString(jsonString);

  await Share.shareXFiles([
    XFile(file.path),
  ], text: 'Backup Completo das Partidas');
}
