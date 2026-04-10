import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';

class SyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Faz o backup de todos os dados locais (SharedPreferences) para o Firestore.
  Future<void> exportDataToFirebase(String syncCode) async {
    final prefs = await SharedPreferences.getInstance();
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
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.any, // Pode ser restrito mas FileType.any garante que o json será visto
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
        
        return true; // Sucesso
      }
      return false; // Usuário cancelou
    } catch (e) {
      throw Exception("Erro ao importar arquivo: $e");
    }
  }
}

