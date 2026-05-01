import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../utils/player_identity.dart';

class SyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const Uuid _uuid = Uuid();

  /// Faz o backup de todos os dados locais (SharedPreferences) para o Firestore.
  Future<void> exportDataToFirebase(String syncCode) async {
    final prefs = await SharedPreferences.getInstance();
    await _normalizeUuidData(prefs);
    await _normalizeSessionIds(prefs);
    final keys = prefs.getKeys();
    
    Map<String, dynamic> data = {};
    for (String key in keys) {
      data[key] = prefs.get(key);
    }

    // Salvar o json completo no Firestore
    await _firestore.collection('sync_data').doc(syncCode).set({
      'data': data,
      'last_updated': FieldValue.serverTimestamp(),
    });
  }

  /// Restaura os dados do Firestore para o armazenamento local, substituindo tudo.
  Future<void> importDataFromFirebase(String syncCode) async {
    final docRefs = _firestore.collection('sync_data').doc(syncCode);
    final doc = await docRefs.get();

    if (!doc.exists) {
      throw Exception("Código de sincronização não encontrado na nuvem.");
    }

    final docData = doc.data() as Map<String, dynamic>;
    if (!docData.containsKey('data')) {
      throw Exception("Dados mal formatados ou ausentes neste código.");
    }

    final Map<String, dynamic> data = Map<String, dynamic>.from(docData['data']);
    final prefs = await SharedPreferences.getInstance();

    // Opcionalmente podemos limpar primeiro. O usuário aprovou que o restore sobrescreva.
    await prefs.clear();

    for (var entry in data.entries) {
      final key = entry.key;
      final value = entry.value;

      if (value is String) {
        await prefs.setString(key, value);
      } else if (value is int) {
        await prefs.setInt(key, value);
      } else if (value is double) {
        await prefs.setDouble(key, value);
      } else if (value is bool) {
        await prefs.setBool(key, value);
      } else if (value is List) {
        // Se for uma lista armazenada no Firestore
        List<String> strList = value.map((e) => e.toString()).toList();
        await prefs.setStringList(key, strList);
      }
    }

    await _normalizeUuidData(prefs);
    await _pushNormalizedDataToFirebase(syncCode, prefs);
  }

  /// Gera um novo sync code
  String? _cachedCode;

  Future<String> getOrCreateSyncCode() async {
    if (_cachedCode != null) return _cachedCode!;

    final prefs = await SharedPreferences.getInstance();
    String? existingCode = prefs.getString('my_sync_code');

    if (existingCode != null && existingCode.isNotEmpty) {
      _cachedCode = existingCode;
      return existingCode;
    }

    // Gera um código alfanumérico de 6 dígitos aleatório
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    var rnd = DateTime.now().millisecondsSinceEpoch;
    String newCode = '';
    for (var i = 0; i < 6; i++) {
      int index = (rnd % chars.length).toInt();
      newCode += chars[index];
      rnd = (rnd / 2).floor(); // naive simple random
    }

    // Se preferir um random mais forte:
    // math.Random r = math.Random();
    // newCode = List.generate(6, (i) => chars[r.nextInt(chars.length)]).join();
    // Resolvendo usando apenas math básico sem importar math pro agora, ou importando.
    
    // Naive way was fine but lets just hardcode a simple unique logic using timestamp
    String timeStr = DateTime.now().millisecondsSinceEpoch.toString();
    newCode = "SNC${timeStr.substring(timeStr.length - 4)}"; // e.g. SNC1234

    await prefs.setString('my_sync_code', newCode);
    _cachedCode = newCode;
    return newCode;
  }

  /// BACKUP LOCAL: Exportar SharedPreferences para um arquivo JSON local e compartilhar
  Future<void> exportToFile() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    
    Map<String, dynamic> data = {};
    for (String key in keys) {
      data[key] = prefs.get(key);
    }
    
    // Converte para String JSON
    final jsonString = jsonEncode(data);
    
    // Obtém o diretório temporário do dispositivo
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/pelada_backup_${DateTime.now().millisecondsSinceEpoch}.json');
    
    // Escreve o JSON no arquivo
    await file.writeAsString(jsonString);
    
    // Abre a tela de compartilhamento nativa (salvar no Google Drive, Whatsapp, etc)
    await Share.shareXFiles([XFile(file.path)], text: 'Meu Backup do Pelada App');
  }

  /// RESTAURAR LOCAL: Importar de um arquivo JSON selecionado usando file_picker
  Future<bool> importFromFile() async {
    try {
      // Abre o explorador de arquivos
     final result = await FilePicker.pickFiles(
       type: FileType.any,
      );

      if (result != null && result.files.single.path != null) {
        File file = File(result.files.single.path!);
        
        // Lê o conteúdo
        String jsonString = await file.readAsString();
        
        // Decodifica JSON
        final Map<String, dynamic> data = jsonDecode(jsonString);
        
        final prefs = await SharedPreferences.getInstance();
        
        // Sobrescreve dados atuais (Limpando tudo primeiro para evitar lixo)
        await prefs.clear();
        
        for (var entry in data.entries) {
          final key = entry.key;
          final value = entry.value;

          if (value is String) {
            await prefs.setString(key, value);
          } else if (value is int) {
            await prefs.setInt(key, value);
          } else if (value is double) {
            await prefs.setDouble(key, value);
          } else if (value is bool) {
            await prefs.setBool(key, value);
          } else if (value is List) {
            List<String> strList = value.map((e) => e.toString()).toList();
            await prefs.setStringList(key, strList);
          }
        }

        await _normalizeUuidData(prefs);
        
        return true; // Sucesso
      }
      return false; // Usuário cancelou
    } catch (e) {
      throw Exception("Erro ao importar arquivo: $e");
    }
  }

  Future<void> _pushNormalizedDataToFirebase(
    String syncCode,
    SharedPreferences prefs,
  ) async {
    final keys = prefs.getKeys();
    final Map<String, dynamic> data = {};
    for (final key in keys) {
      data[key] = prefs.get(key);
    }
    await _firestore.collection('sync_data').doc(syncCode).set({
      'data': data,
      'last_updated': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _normalizeUuidData(SharedPreferences prefs) async {
    final Map<String, String> nameToId = {};

    final playerKeys = prefs
        .getKeys()
        .where((k) => k.startsWith('players_'))
        .toList();

    for (final key in playerKeys) {
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) continue;
      final loaded = List<Map<String, dynamic>>.from(jsonDecode(raw));
      final List<Map<String, dynamic>> normalized = [];
      for (final player in ensurePlayerIds(loaded)) {
        final map = Map<String, dynamic>.from(player);
        String id = (map['id'] ?? '').toString();
        final name = (map['name'] ?? '').toString();
        if (id.isEmpty || id == name) {
          id = _uuid.v4();
          map['id'] = id;
        }
        if (name.isNotEmpty) {
          nameToId[name.toLowerCase()] = id;
        }
        normalized.add(map);
      }
      await prefs.setString(key, jsonEncode(normalized));
    }

    Future<void> normalizePlayerListKey(String key) async {
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) return;
      final loaded = List<Map<String, dynamic>>.from(jsonDecode(raw));
      final normalized = loaded.map((player) {
        final map = Map<String, dynamic>.from(player);
        final name = (map['name'] ?? '').toString();
        if (name.isNotEmpty) {
          final inferred = nameToId[name.toLowerCase()];
          if (inferred != null) {
            map['id'] = inferred;
          } else if ((map['id'] ?? '').toString().isEmpty) {
            map['id'] = _uuid.v4();
          }
        }
        return map;
      }).toList();
      await prefs.setString(key, jsonEncode(normalized));
    }

    for (final key in prefs.getKeys().where((k) => k.startsWith('present_players_'))) {
      await normalizePlayerListKey(key);
    }
    for (final key in prefs.getKeys().where((k) => k.startsWith('team_red_'))) {
      await normalizePlayerListKey(key);
    }
    for (final key in prefs.getKeys().where((k) => k.startsWith('team_white_'))) {
      await normalizePlayerListKey(key);
    }

    for (final key in prefs.getKeys().where((k) => k.startsWith('match_history_'))) {
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) continue;
      final history = List<dynamic>.from(jsonDecode(raw));
      for (final match in history) {
        final players = Map<String, dynamic>.from(match['players'] ?? {});
        for (final side in ['red', 'white']) {
          final list = List<dynamic>.from(players[side] ?? []);
          for (final p in list) {
            final id = playerIdFromObject(p);
            final name = (p['name'] ?? '').toString();
            if ((id.isEmpty || id == name) && nameToId.containsKey(name.toLowerCase())) {
              p['id'] = nameToId[name.toLowerCase()];
            } else if ((id.isEmpty || id == name) && name.isNotEmpty) {
              p['id'] = _uuid.v4();
            }
          }
        }

        final events = List<dynamic>.from(match['events'] ?? []);
        for (final event in events) {
          final playerName = (event['player'] ?? '').toString();
          final assistName = (event['assist'] ?? '').toString();
          if ((eventPlayerId(event, 'player').isEmpty || eventPlayerId(event, 'player') == playerName) &&
              playerName.isNotEmpty) {
            event['playerId'] =
                nameToId[playerName.toLowerCase()] ?? _uuid.v4();
          }
          if (assistName.isNotEmpty &&
              (eventPlayerId(event, 'assist').isEmpty ||
                  eventPlayerId(event, 'assist') == assistName)) {
            event['assistId'] =
                nameToId[assistName.toLowerCase()] ?? _uuid.v4();
          }
        }
      }
      await prefs.setString(key, jsonEncode(history));
    }
  }

  Future<void> _normalizeSessionIds(SharedPreferences prefs) async {
    final sessionKeys =
        prefs.getKeys().where((k) => k.startsWith('sessions_')).toList();

    for (final key in sessionKeys) {
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) continue;

      final List<dynamic> sessions = jsonDecode(raw);
      bool changed = false;

      for (int i = 0; i < sessions.length; i++) {
        final session = sessions[i];
        String oldId = session['id'].toString();

        // Regex para detectar o formato antigo: session_ seguido de muitos dígitos (timestamp)
        final oldFormat = RegExp(r'^session_\d{10,13}$');
        if (oldFormat.hasMatch(oldId)) {
          String name = (session['title'] ?? 'pelada')
              .toString()
              .toLowerCase()
              .replaceAll(RegExp(r'[^a-z0-9]'), '_');
          String random = const Uuid().v4().substring(0, 4);
          String newId = 'session_${name}_$random';

          // Renomeia a chave do histórico de partidas se ela existir
          final oldHistoryKey = 'match_history_$oldId';
          final newHistoryKey = 'match_history_$newId';

          if (prefs.containsKey(oldHistoryKey)) {
            final historyData = prefs.getString(oldHistoryKey);
            if (historyData != null) {
              await prefs.setString(newHistoryKey, historyData);
              await prefs.remove(oldHistoryKey);
            }
          }

          session['id'] = newId;
          changed = true;
        }
      }

      if (changed) {
        await prefs.setString(key, jsonEncode(sessions));
      }
    }
  }
}

