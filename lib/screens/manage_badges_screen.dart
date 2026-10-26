import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:audioplayers/audioplayers.dart';
import '../constants/app_colors.dart';
import '../repositories/supabase_service.dart';
import '../constants/cosmetic_effects.dart';
import '../models/cosmetic_effect.dart';
import '../utils/constants.dart';
import '../utils/cosmetic_resolver.dart';
import '../widgets/shared/player_name_text.dart';
import '../widgets/shared/player_avatar_frame.dart';

class ManageBadgesScreen extends StatefulWidget {
  final String groupId;

  const ManageBadgesScreen({super.key, required this.groupId});

  @override
  State<ManageBadgesScreen> createState() => _ManageBadgesScreenState();
}

class _ManageBadgesScreenState extends State<ManageBadgesScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _customBadges = [];
  List<Map<String, dynamic>> _allPlayers = [];
  bool _isLoading = true;
  bool _isAdmin = false;
  static const Uuid _uuid = Uuid();
  late final TabController _tabController;
  int _currentTabIndex = 0;

  // Aba de Áudios
  final AudioPlayer _previewPlayer = AudioPlayer();
  String? _playingPreviewId; // id do jogador cujo áudio está tocando agora
  String? _uploadingPlayerId; // id do jogador com upload em andamento

  // Aba de Efeitos
  String? _savingEffectPlayerId; // id do jogador com efeito sendo salvo agora

  static const int _maxAudioSizeBytes = 2 * 1024 * 1024; // 2MB
  static const List<String> _allowedAudioExtensions = ['mp3', 'wav', 'ogg', 'm4a'];

  @override
  void dispose() {
    _previewPlayer.dispose();
    _tabController.dispose();
    super.dispose();
  }

  final List<String> _availableAssets = [
    'assets/badges/bola_de_ouro.png',
    'assets/badges/craque_do_mes.png',
    'assets/badges/bola_de_prata.png',
    'assets/badges/chuteira_de_ouro.png',
    'assets/badges/luva_de_ouro.png',
    'assets/badges/estrela_mes.png',
    'assets/badges/craque_galera.png',
    'assets/badges/bagre_mes.png',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging || _tabController.index != _currentTabIndex) {
        setState(() => _currentTabIndex = _tabController.index);
      }
    });
    _loadBadges();
  }

  Future<void> _loadBadges() async {
    final prefs = await SharedPreferences.getInstance();
    final String key = 'custom_badges_${widget.groupId}';
    if (prefs.containsKey(key)) {
      setState(() {
        _customBadges = List<Map<String, dynamic>>.from(
          jsonDecode(prefs.getString(key)!),
        );
      });
    }

    try {
      final fetched = await SupabaseService.instance.players.getPlayersByGroup(
        widget.groupId,
      );
      _allPlayers = fetched
          .map(
            (j) => {
              'id': j.id,
              'name': j.name,
              'manual_badges': j.manualBadges.map((b) => b.toMap()).toList(),
              'goal_sound_url': j.goalSoundUrl,
              'name_effect': j.nameEffect,
              'monthly_highlight': j.monthlyHighlight,
              'advanced_stats': j.advancedStats,
            },
          )
          .toList();
    } catch (_) {
      final String playersKey = 'players_${widget.groupId}';
      if (prefs.containsKey(playersKey)) {
        _allPlayers = List<Map<String, dynamic>>.from(
          jsonDecode(prefs.getString(playersKey)!),
        );
      }
    }

    try {
      _isAdmin = await SupabaseService.instance.groupMembers.isCurrentUserAdmin(
        widget.groupId,
      );
    } catch (_) {
      _isAdmin = false;
    }

    setState(() => _isLoading = false);
  }

  /// Define o áudio customizado de gol para um jogador a partir dos assets locais.
  Future<void> _setGoalAudioForPlayer(String playerId, String? audioFile) async {
    if (!_isAdmin) return;
    setState(() => _uploadingPlayerId = playerId);
    try {
      final updated = await SupabaseService.instance.players.setGoalSound(
        playerId: playerId,
        audioFileName: audioFile,
        groupId: widget.groupId,
      );
      setState(() {
        final idx = _allPlayers.indexWhere((p) => p['id'] == playerId);
        if (idx != -1) _allPlayers[idx]['goal_sound_url'] = updated.goalSoundUrl;
        _uploadingPlayerId = null;
      });

      // Atualiza o snapshot local em SharedPreferences
      try {
        final prefs = await SharedPreferences.getInstance();
        final key = 'players_${widget.groupId}';
        final raw = prefs.getString(key);
        if (raw != null) {
          final list = List<Map<String, dynamic>>.from(jsonDecode(raw));
          final idx = list.indexWhere((p) => p['id'] == playerId);
          if (idx != -1) {
            list[idx]['goal_sound_url'] = updated.goalSoundUrl;
            await prefs.setString(key, jsonEncode(list));
          }
        }
      } catch (_) {}

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              audioFile != null
                  ? "Áudio salvo: ${getGoalAudioLabel(audioFile)}"
                  : "Áudio redefinido para o padrão",
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _uploadingPlayerId = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao salvar áudio: $e")),
        );
      }
    }
  }

  /// Abre modal para escolher qual áudio da pasta assets/audio atribuir ao jogador.
  void _showAudioPickerModal(String playerId, String playerName) {
    if (!_isAdmin) return;
    final currentPlayer = _allPlayers.firstWhere(
      (p) => p['id'] == playerId,
      orElse: () => {},
    );
    final String? currentAudio = currentPlayer['goal_sound_url']?.toString();
    final List<String> selectedFiles =
        List<String>.from(parseGoalSounds(currentAudio));
    String? playingFile;
    final localPlayer = AudioPlayer();
    StreamSubscription? completeSub;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Container(
            decoration: const BoxDecoration(
              color: AppColors.headerBlue,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  "Som de Gol: $playerName",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  "Toque nos sons na ordem desejada para criar um loop de gols (1º gol, 2º gol...).",
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                if (selectedFiles.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.deepBlue.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Sequência do Loop (${selectedFiles.length} ${selectedFiles.length == 1 ? 'som' : 'sons'}):",
                          style: const TextStyle(
                            color: Colors.amber,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (int i = 0; i < selectedFiles.length; i++)
                              Chip(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                backgroundColor: Colors.amber.withValues(alpha: 0.2),
                                side: const BorderSide(color: Colors.amber, width: 0.8),
                                label: Text(
                                  "${i + 1}º ${getGoalAudioLabel(selectedFiles[i])}",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                deleteIcon: const Icon(
                                  Icons.close,
                                  size: 14,
                                  color: Colors.amber,
                                ),
                                onDeleted: () {
                                  setModalState(() {
                                    selectedFiles.removeAt(i);
                                  });
                                },
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.4,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: availableGoalAudios.length,
                    separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
                    itemBuilder: (c, idx) {
                      final item = availableGoalAudios[idx];
                      final file = item['file']!;
                      final label = item['label']!;
                      final orderIndex = selectedFiles.indexOf(file);
                      final isSelected = orderIndex != -1;
                      final isPlayingThis = playingFile == file;

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: IconButton(
                          icon: Icon(
                            isPlayingThis ? Icons.stop_circle : Icons.play_circle_fill,
                            color: Colors.amber,
                            size: 28,
                          ),
                          onPressed: () async {
                            if (isPlayingThis) {
                              await localPlayer.stop();
                              setModalState(() => playingFile = null);
                            } else {
                              await localPlayer.stop();
                              setModalState(() => playingFile = file);
                              completeSub?.cancel();
                              completeSub =
                                  localPlayer.onPlayerComplete.listen((_) {
                                if (ctx.mounted) {
                                  setModalState(() => playingFile = null);
                                }
                              });
                              await localPlayer.play(AssetSource('audio/$file'));
                            }
                          },
                        ),
                        title: Text(
                          label,
                          style: TextStyle(
                            color: isSelected ? Colors.amber : Colors.white,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          file,
                          style: const TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                        trailing: IconButton(
                          icon: isSelected
                              ? Container(
                                  width: 28,
                                  height: 28,
                                  alignment: Alignment.center,
                                  decoration: const BoxDecoration(
                                    color: Colors.amber,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    "${orderIndex + 1}º",
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              : const Icon(
                                  Icons.add_circle,
                                  color: Colors.amber,
                                  size: 28,
                                ),
                          tooltip: isSelected
                              ? "Remover do loop"
                              : "Adicionar ao loop",
                          onPressed: () {
                            setModalState(() {
                              if (isSelected) {
                                selectedFiles.remove(file);
                              } else {
                                selectedFiles.add(file);
                              }
                            });
                          },
                        ),
                        onTap: () {
                          setModalState(() {
                            if (isSelected) {
                              selectedFiles.remove(file);
                            } else {
                              selectedFiles.add(file);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.check, size: 20),
                    label: Text(
                      selectedFiles.isEmpty
                          ? "Usar Som Padrão"
                          : selectedFiles.length == 1
                              ? "Salvar Som Selecionado"
                              : "Salvar Loop (${selectedFiles.length} Sons)",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _setGoalAudioForPlayer(playerId, formatGoalSounds(selectedFiles));
                    },
                  ),
                ),
                if (currentAudio != null && currentAudio.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                      ),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text("Redefinir para Padrão"),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _setGoalAudioForPlayer(playerId, null);
                      },
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    ).whenComplete(() async {
      await completeSub?.cancel();
      try {
        await localPlayer.dispose();
      } catch (_) {}
    });
  }

  /// Abre o card de busca para escolher UM jogador que ainda não tem áudio customizado.
  void _showPickPlayerForAudioDialog() {
    if (!_isAdmin) return;
    final candidates = _allPlayers
        .where((p) => (p['goal_sound_url'] as String?)?.isNotEmpty != true)
        .toList()
      ..sort((a, b) => (a['name']?.toString() ?? '')
          .toLowerCase()
          .compareTo((b['name']?.toString() ?? '').toLowerCase()));

    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Todos os jogadores já têm áudio definido.")),
      );
      return;
    }

    String searchQuery = '';
    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, st) {
          final filtered = candidates
              .where((p) => (p['name']?.toString() ?? '')
                  .toLowerCase()
                  .contains(searchQuery.toLowerCase()))
              .toList();

          return AlertDialog(
            backgroundColor: AppColors.headerBlue,
            title: const Text(
              "Escolher Jogador",
              style: TextStyle(color: Colors.white),
            ),
            contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            content: SizedBox(
              width: double.maxFinite,
              height: MediaQuery.of(context).size.height * 0.6,
              child: Column(
                children: [
                  TextField(
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Buscar nome...",
                      hintStyle: const TextStyle(color: Colors.white30),
                      prefixIcon: const Icon(Icons.search, color: Colors.white54),
                      filled: true,
                      fillColor: AppColors.deepBlue,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (val) => st(() => searchQuery = val),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(
                            child: Text(
                              "Nenhum jogador encontrado.",
                              style: TextStyle(color: Colors.white54),
                            ),
                          )
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (c, i) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.person, color: Colors.white54),
                              title: Text(
                                filtered[i]['name']?.toString() ?? '',
                                style: const TextStyle(color: Colors.white),
                              ),
                              onTap: () {
                                Navigator.pop(c);
                                _showAudioPickerModal(
                                  filtered[i]['id'].toString(),
                                  filtered[i]['name']?.toString() ?? 'Jogador',
                                );
                              },
                            ),
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text("Cancelar", style: TextStyle(color: Colors.redAccent)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _removeGoalSound(String playerId) async {
    if (!_isAdmin) return;
    await _setGoalAudioForPlayer(playerId, null);
  }

  Future<void> _setNameEffect(String playerId, String? effect) async {
    if (!_isAdmin) return;
    setState(() => _savingEffectPlayerId = playerId);
    try {
      final updated = await SupabaseService.instance.players.setNameEffect(
        groupId: widget.groupId,
        playerId: playerId,
        effect: effect,
      );
      setState(() {
        final idx = _allPlayers.indexWhere((p) => p['id'] == playerId);
        if (idx != -1) _allPlayers[idx]['name_effect'] = updated.nameEffect;
        _savingEffectPlayerId = null;
      });
    } catch (e) {
      setState(() => _savingEffectPlayerId = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao salvar efeito: $e")),
        );
      }
    }
  }

  Future<void> _setAdvancedStat(String playerId, Map<String, dynamic> patch) async {
    if (!_isAdmin) return;
    setState(() => _savingEffectPlayerId = playerId);
    try {
      final updated = await SupabaseService.instance.players.setAdvancedStat(
        groupId: widget.groupId,
        playerId: playerId,
        patch: patch,
      );
      setState(() {
        final idx = _allPlayers.indexWhere((p) => p['id'] == playerId);
        if (idx != -1) {
          _allPlayers[idx]['advanced_stats'] = updated.advancedStats;
        }
        _savingEffectPlayerId = null;
      });
    } catch (e) {
      setState(() => _savingEffectPlayerId = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $e')),
        );
      }
    }
  }

  /// Resolve quantas vezes o jogador ganhou Craque do Mês a partir do mapa local.
  int _resolveCraqueCountLocal(Map<String, dynamic> player) {
    final advStats = player['advanced_stats'];
    if (advStats is Map) {
      final v = advStats['craque_mes_count'];
      if (v is num) return v.toInt();
    }
    return 1;
  }

  Future<void> _setMonthlyHighlight(String playerId, bool value) async {
    if (!_isAdmin) return;
    setState(() => _savingEffectPlayerId = playerId);
    try {
      final updated = await SupabaseService.instance.players.setMonthlyHighlight(
        groupId: widget.groupId,
        playerId: playerId,
        value: value,
      );
      setState(() {
        final idx = _allPlayers.indexWhere((p) => p['id'] == playerId);
        if (idx != -1) _allPlayers[idx]['monthly_highlight'] = updated.monthlyHighlight;
        _savingEffectPlayerId = null;
      });
    } catch (e) {
      setState(() => _savingEffectPlayerId = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao salvar selo de craque do mês: $e")),
        );
      }
    }
  }

  /// Mini card de configuração de efeitos com:
  /// - Bola de Ouro (exclusivo para 1 jogador)
  /// - Efeitos de nome com molduras correspondentes (Ouro, Diamante, Fogo, Prata, Bronze)
  /// - Craque do Mês com seletor de 1x–6x vitórias
  void _showEffectConfigDialog(Map<String, dynamic> player) {
    final String playerId = player['id'].toString();

    // Detecta efeito atual: nome base (gold/silver/bronze) OU extra (fire/diamond)
    final advStats = player['advanced_stats'];
    final extraEffect = advStats is Map ? advStats['name_effect_extra']?.toString() : null;
    String? selectedEffect = extraEffect?.isNotEmpty == true
        ? extraEffect
        : player['name_effect'] as String?;
    bool isBolaDeOuro = advStats is Map && advStats['bola_de_ouro'] == true;
    bool monthlyHighlight = player['monthly_highlight'] == true;
    int craqueCount = _resolveCraqueCountLocal(player);

    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, st) {
          Widget effectRadio(String? value, String label, Color? swatch, String desc) {
            return RadioListTile<String?>(
              value: value,
              groupValue: selectedEffect,
              activeColor: swatch ?? Colors.amber,
              title: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: Text(desc, style: const TextStyle(color: Colors.white54, fontSize: 11)),
              onChanged: (v) => st(() => selectedEffect = v),
            );
          }

          return AlertDialog(
            backgroundColor: AppColors.headerBlue,
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    player['name']?.toString() ?? 'Jogador',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            contentPadding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 👑 BOLA DE OURO (Melhor da Temporada - Exclusivo)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isBolaDeOuro
                            ? Colors.amber.withValues(alpha: 0.15)
                            : Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isBolaDeOuro ? Colors.amber : Colors.white12,
                          width: isBolaDeOuro ? 1.5 : 1,
                        ),
                      ),
                      child: SwitchListTile(
                        value: isBolaDeOuro,
                        activeColor: Colors.amber,
                        title: const Text(
                          "👑 Bola de Ouro",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        subtitle: const Text(
                          "Melhor da temporada (moldura dourada)",
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                        onChanged: (v) {
                          st(() {
                            isBolaDeOuro = v;
                            if (v && selectedEffect == null) {
                              selectedEffect = 'gold';
                            }
                          });
                        },
                      ),
                    ),

                    const SizedBox(height: 8),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Text(
                        "Efeito de Nome e Moldura",
                        style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),

                    // Ordem lógica e hierárquica dos efeitos:
                    effectRadio(null, kNoCosmeticEffectLabel, Colors.white54, kNoCosmeticEffectDescription),
                    for (final d in kCosmeticEffects)
                      effectRadio(d.effect.dbValue, d.legendLabel, d.frameColor, d.description),

                    const Divider(color: Colors.white12),

                    // Craque do Mês
                    CheckboxListTile(
                      value: monthlyHighlight,
                      activeColor: const Color(0xFF00E5FF),
                      title: const Text(
                        "Craque do Mês 🏅",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text(
                        "Moldura safira + estrelas cumulativas no card",
                        style: TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                      onChanged: (v) => st(() => monthlyHighlight = v ?? false),
                    ),

                    // Seletor de quantidade (1x a 6x)
                    if (monthlyHighlight) ...[
                      Padding(
                        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Quantas vezes ganhou?",
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children: List.generate(6, (i) {
                                final n = i + 1;
                                final selected = craqueCount == n;
                                return GestureDetector(
                                  onTap: () => st(() => craqueCount = n),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? const Color(0xFF2979FF)
                                          : AppColors.deepBlue,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: selected
                                            ? const Color(0xFF00E5FF)
                                            : Colors.white24,
                                        width: selected ? 1.5 : 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '$n',
                                          style: TextStyle(
                                            color: selected ? Colors.white : Colors.white54,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                          ),
                                        ),
                                        Icon(
                                          Icons.star_rounded,
                                          color: selected
                                              ? const Color(0xFFFFD700)
                                              : Colors.white24,
                                          size: 13,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text("Cancelar", style: TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                onPressed: () async {
                  Navigator.pop(c);

                  // 1. Se marcou bola de ouro, remove dos outros jogadores para ser exclusivo
                  if (isBolaDeOuro) {
                    for (final p in _allPlayers) {
                      final otherId = p['id'].toString();
                      if (otherId != playerId) {
                        final otherAdv = p['advanced_stats'];
                        if (otherAdv is Map && otherAdv['bola_de_ouro'] == true) {
                          await _setAdvancedStat(otherId, {'bola_de_ouro': false});
                        }
                      }
                    }
                  }

                  // 2. Determina se o efeito vai no name_effect (gold/silver/bronze)
                  // ou em advanced_stats.name_effect_extra (fire/diamond)
                  final baseEffects = {'gold', 'silver', 'bronze'};
                  final isBaseEffect = selectedEffect != null && baseEffects.contains(selectedEffect);
                  final isExtraEffect = selectedEffect != null && !baseEffects.contains(selectedEffect);

                  final newBaseEffect = isBaseEffect ? selectedEffect : null;
                  final currentBaseEffect = player['name_effect'] as String?;
                  if (newBaseEffect != currentBaseEffect) {
                    await _setNameEffect(playerId, newBaseEffect);
                  }

                  // 3. Salva advanced_stats (name_effect_extra, craque_mes_count, bola_de_ouro)
                  final newExtra = isExtraEffect ? selectedEffect : null;
                  final currentExtra = extraEffect;
                  final newCount = monthlyHighlight ? craqueCount : null;
                  final currentCount = player['monthly_highlight'] == true
                      ? _resolveCraqueCountLocal(player)
                      : null;
                  final currentBolaDeOuro = advStats is Map && advStats['bola_de_ouro'] == true;

                  if (newExtra != currentExtra ||
                      newCount != currentCount ||
                      isBolaDeOuro != currentBolaDeOuro) {
                    await _setAdvancedStat(playerId, {
                      'name_effect_extra': newExtra,
                      'craque_mes_count': newCount,
                      'bola_de_ouro': isBolaDeOuro,
                    });
                  }

                  // 4. Salva monthly_highlight
                  if (monthlyHighlight != (player['monthly_highlight'] == true)) {
                    await _setMonthlyHighlight(playerId, monthlyHighlight);
                  }
                },
                child: const Text("Salvar", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Card de busca (mesmo padrão do áudio) pra escolher um jogador e abrir
  /// o mini card de configuração de efeitos.
  void _showPickPlayerForEffectDialog() {
    final candidates = List<Map<String, dynamic>>.from(_allPlayers)
      ..sort((a, b) => (a['name']?.toString() ?? '')
          .toLowerCase()
          .compareTo((b['name']?.toString() ?? '').toLowerCase()));

    String searchQuery = '';
    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, st) {
          final filtered = candidates
              .where((p) => (p['name']?.toString() ?? '')
                  .toLowerCase()
                  .contains(searchQuery.toLowerCase()))
              .toList();

          return AlertDialog(
            backgroundColor: AppColors.headerBlue,
            title: const Text("Escolher Jogador", style: TextStyle(color: Colors.white)),
            contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            content: SizedBox(
              width: double.maxFinite,
              height: MediaQuery.of(context).size.height * 0.6,
              child: Column(
                children: [
                  TextField(
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Buscar nome...",
                      hintStyle: const TextStyle(color: Colors.white30),
                      prefixIcon: const Icon(Icons.search, color: Colors.white54),
                      filled: true,
                      fillColor: AppColors.deepBlue,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (val) => st(() => searchQuery = val),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(
                            child: Text("Nenhum jogador encontrado.", style: TextStyle(color: Colors.white54)),
                          )
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (c, i) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.person, color: Colors.white54),
                              title: PlayerNameText(
                                name: filtered[i]['name']?.toString() ?? '',
                                nameEffect: filtered[i]['name_effect']?.toString(),
                                style: const TextStyle(color: Colors.white),
                              ),
                              onTap: () {
                                Navigator.pop(c);
                                _showEffectConfigDialog(filtered[i]);
                              },
                            ),
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text("Cancelar", style: TextStyle(color: Colors.redAccent)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEffectsTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accentBlue));
    }

    final withEffect = _allPlayers
        .where((p) {
          final adv = p['advanced_stats'];
          final hasExtra = adv is Map && adv['name_effect_extra'] != null;
          final hasBolaOuro = adv is Map && adv['bola_de_ouro'] == true;
          final hasNameEffect = (p['name_effect'] as String?)?.isNotEmpty == true;
          final isCraqueMes = p['monthly_highlight'] == true;
          return hasExtra || hasBolaOuro || hasNameEffect || isCraqueMes;
        })
        .toList()
      ..sort((a, b) => (a['name']?.toString() ?? '')
          .toLowerCase()
          .compareTo((b['name']?.toString() ?? '').toLowerCase()));

    return Stack(
      children: [
        Column(
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.headerBlue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.white54, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isAdmin
                          ? "Nome dourado/prata/bronze aparece em toda tela (partida, ranking, elenco, etc). O selo de craque do mês só aparece no pódio do ranking."
                          : "Somente administradores podem alterar efeitos de jogadores.",
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: withEffect.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.auto_awesome_outlined, color: Colors.white24, size: 64),
                          SizedBox(height: 12),
                          Text("Nenhum efeito definido ainda.", style: TextStyle(color: Colors.white54)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                      itemCount: withEffect.length,
                      itemBuilder: (ctx, i) {
                        final player = withEffect[i];
                        final String playerId = player['id'].toString();
                        // Efeito completo: base (gold/silver/bronze) ou extra (fire/diamond de advanced_stats)
                        final advStats = player['advanced_stats'];
                        final extraEffect = advStats is Map ? advStats['name_effect_extra']?.toString() : null;
                        final String? effect = (extraEffect?.isNotEmpty == true)
                            ? extraEffect
                            : player['name_effect'] as String?;
                        final bool highlight = player['monthly_highlight'] == true;
                        final bool isSaving = _savingEffectPlayerId == playerId;
                        final effectColor = cosmeticEffectColor(CosmeticEffect.fromDb(effect)) ?? Colors.amber;
                        final frame = resolvePlayerFrame(player);
                        final craqueCount = _resolveCraqueCountLocal(player);

                        String effectLabel(String? e) {
                          final d = cosmeticEffectDef(CosmeticEffect.fromDb(e));
                          return d == null ? (e ?? '') : d.legendLabel;
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.headerBlue,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: effectColor.withValues(alpha: 0.4)),
                          ),
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: PlayerAvatarFrame(
                              frame: frame,
                              compact: true,
                              isCircular: true,
                              child: CircleAvatar(
                                backgroundColor: effectColor.withValues(alpha: 0.15),
                                backgroundImage: (player['icon'] != null && (player['icon'] as String).isNotEmpty)
                                    ? AssetImage(player['icon'] as String)
                                    : null,
                                child: (player['icon'] == null || (player['icon'] as String).isEmpty)
                                    ? Icon(Icons.auto_awesome, color: effectColor, size: 18)
                                    : null,
                              ),
                            ),
                            title: PlayerNameText(
                              name: player['name']?.toString() ?? 'Jogador',
                              nameEffect: effect,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              [
                                if (advStats is Map && advStats['bola_de_ouro'] == true) '👑 Bola de Ouro (Melhor da Temporada)',
                                if (effect != null) 'Nome: ${effectLabel(effect)}',
                                if (highlight)
                                  craqueCount > 1
                                      ? 'Craque do Mês (${craqueCount}x ⭐)'
                                      : 'Craque do Mês ⭐',
                                if (frame.type == PlayerFrameType.artilheiro) '🔥 Artilheiro',
                              ].toSet().join(' • '),
                              style: TextStyle(color: effectColor.withValues(alpha: 0.9), fontSize: 12),
                            ),
                            trailing: isSaving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentBlue),
                                  )
                                : IconButton(
                                    icon: const Icon(Icons.edit_outlined, color: Colors.white70),
                                    tooltip: "Editar efeito",
                                    onPressed: _isAdmin ? () => _showEffectConfigDialog(player) : null,
                                  ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
        if (_isAdmin)
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.extended(
              backgroundColor: Colors.amber,
              onPressed: _showPickPlayerForEffectDialog,
              icon: const Icon(Icons.add, color: Colors.black),
              label: const Text("Novo Efeito", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ),
      ],
    );
  }

  Future<void> _togglePreview(String playerId, String soundRef) async {
    if (_playingPreviewId == playerId) {
      await _previewPlayer.stop();
      setState(() => _playingPreviewId = null);
      return;
    }
    await _previewPlayer.stop();
    setState(() => _playingPreviewId = playerId);
    final sounds = parseGoalSounds(soundRef);
    final soundToPlay = sounds.isNotEmpty ? sounds.first : soundRef;
    if (soundToPlay.startsWith('http://') || soundToPlay.startsWith('https://')) {
      await _previewPlayer.play(UrlSource(soundToPlay));
    } else {
      await _previewPlayer.play(AssetSource('audio/$soundToPlay'));
    }
    _previewPlayer.onPlayerComplete.first.then((_) {
      if (mounted) setState(() => _playingPreviewId = null);
    }).catchError((_) {});
  }

  Future<void> _saveBadges() async {
    final prefs = await SharedPreferences.getInstance();
    final String key = 'custom_badges_${widget.groupId}';
    await prefs.setString(key, jsonEncode(_customBadges));
  }

  void _addBadge(String title, String desc, String iconPath) {
    setState(() {
      _customBadges.add({
        'id': _uuid.v4(),
        'title': title,
        'desc': desc,
        'icon': iconPath,
        'created_at': DateTime.now().toIso8601String(),
      });
    });
    _saveBadges();
  }

  void _editBadge(int index, String title, String desc, String iconPath) {
    setState(() {
      _customBadges[index]['title'] = title;
      _customBadges[index]['desc'] = desc;
      _customBadges[index]['icon'] = iconPath;
    });
    _saveBadges();
  }

  void _removeBadge(int index) {
    setState(() {
      _customBadges.removeAt(index);
    });
    _saveBadges();
  }

  void _showBadgeSheet({Map<String, dynamic>? badgeToEdit, int? editIndex}) {
    String selectedIcon = badgeToEdit != null
        ? badgeToEdit['icon']
        : _availableAssets.first;
    if (!_availableAssets.contains(selectedIcon))
      selectedIcon = _availableAssets.first;

    final titleController = TextEditingController(
      text: badgeToEdit?['title'] ?? '',
    );
    final descController = TextEditingController(
      text: badgeToEdit?['desc'] ?? '',
    );
    final isEditing = badgeToEdit != null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.deepBlue,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.workspace_premium, color: Colors.amber),
                    const SizedBox(width: 8),
                    Text(
                      isEditing ? "Editar Troféu" : "Criar Novo Troféu",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  "Escolha o Ícone (Assets):",
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 70,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _availableAssets.length,
                    itemBuilder: (context, i) {
                      final asset = _availableAssets[i];
                      final isSelected = selectedIcon == asset;
                      return GestureDetector(
                        onTap: () => setSheetState(() => selectedIcon = asset),
                        child: Container(
                          width: 60,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.headerBlue
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? Colors.amber : Colors.white12,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Image.asset(
                              asset,
                              fit: BoxFit.contain,
                              // Caso a imagem não exista ainda, mostra um ícone genérico
                              errorBuilder: (c, e, s) => const Icon(
                                Icons.image_not_supported,
                                color: Colors.white24,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: "Nome do Prêmio (ex: Melhor de Março)",
                    labelStyle: TextStyle(color: Colors.white54),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: "Descrição curta (ex: Artilheiro e MVP)",
                    labelStyle: TextStyle(color: Colors.white54),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () {
                      if (titleController.text.trim().isNotEmpty) {
                        if (isEditing && editIndex != null) {
                          _editBadge(
                            editIndex,
                            titleController.text.trim(),
                            descController.text.trim(),
                            selectedIcon,
                          );
                        } else {
                          _addBadge(
                            titleController.text.trim(),
                            descController.text.trim(),
                            selectedIcon,
                          );
                        }
                        Navigator.pop(ctx);
                      }
                    },
                    child: Text(
                      isEditing ? "Salvar Alterações" : "Salvar Troféu",
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAudiosTab() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accentBlue),
      );
    }

    final withAudio = _allPlayers
        .where((p) => (p['goal_sound_url'] as String?)?.isNotEmpty == true)
        .toList()
      ..sort((a, b) => (a['name']?.toString() ?? '')
          .toLowerCase()
          .compareTo((b['name']?.toString() ?? '').toLowerCase()));

    return Stack(
      children: [
        Column(
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.headerBlue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.white54, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isAdmin
                          ? "Jogadores com áudio de comemoração configurado (assets/audio). Quem não estiver aqui usa o som padrão do gol."
                          : "Somente administradores podem alterar os áudios de gol por esta tela.",
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: withAudio.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.music_off, color: Colors.white24, size: 64),
                          const SizedBox(height: 12),
                          const Text(
                            "Nenhum jogador com áudio customizado ainda.",
                            style: TextStyle(color: Colors.white54),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                      itemCount: withAudio.length,
                      itemBuilder: (ctx, i) {
                        final player = withAudio[i];
                        final String playerId = player['id'].toString();
                        final String soundUrl = player['goal_sound_url'].toString();
                        final bool isUploading = _uploadingPlayerId == playerId;
                        final bool isPlaying = _playingPreviewId == playerId;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.headerBlue,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.amber.withOpacity(0.4)),
                          ),
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: Colors.amber.withOpacity(0.15),
                              child: const Icon(Icons.music_note, color: Colors.amber),
                            ),
                            title: Text(
                              player['name']?.toString() ?? 'Jogador',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              getGoalAudioLabel(soundUrl),
                              style: TextStyle(color: Colors.amber.shade200, fontSize: 12),
                            ),
                            trailing: isUploading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.accentBlue,
                                    ),
                                  )
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          isPlaying ? Icons.stop_circle : Icons.play_circle_fill,
                                          color: Colors.amber,
                                        ),
                                        onPressed: () => _togglePreview(playerId, soundUrl),
                                      ),
                                      if (_isAdmin)
                                        IconButton(
                                          icon: const Icon(Icons.swap_horiz, color: Colors.white70),
                                          tooltip: "Trocar áudio",
                                          onPressed: () => _showAudioPickerModal(
                                            playerId,
                                            player['name']?.toString() ?? 'Jogador',
                                          ),
                                        ),
                                      if (_isAdmin)
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                          tooltip: "Remover áudio",
                                          onPressed: () => _removeGoalSound(playerId),
                                        ),
                                    ],
                                  ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
        if (_isAdmin)
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.extended(
              backgroundColor: Colors.amber,
              onPressed: _showPickPlayerForAudioDialog,
              icon: const Icon(Icons.add, color: Colors.black),
              label: const Text(
                "Novo Áudio",
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deepBlue,
      appBar: AppBar(
        backgroundColor: AppColors.headerBlue,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          "Customizações",
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amber,
          labelColor: Colors.amber,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: "Troféus", icon: Icon(Icons.emoji_events)),
            Tab(text: "Efeitos", icon: Icon(Icons.auto_awesome)),
            Tab(text: "Áudios", icon: Icon(Icons.music_note)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
            // ABA 1: Troféus
            _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.accentBlue,
                    ),
                  )
                : _customBadges.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.emoji_events_outlined,
                          color: Colors.white24,
                          size: 80,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "Nenhum troféu criado.",
                          style: TextStyle(color: Colors.white54, fontSize: 16),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber,
                          ),
                          icon: const Icon(Icons.add, color: Colors.black),
                          label: const Text(
                            "Criar Primeiro Troféu",
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: () => _showBadgeSheet(),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _customBadges.length,
                    itemBuilder: (ctx, i) {
                      final badge = _customBadges[i];
                      String? claimedByName;
                      for (final p in _allPlayers) {
                        final pBadges =
                            p['manual_badges'] as List<dynamic>? ?? [];
                        for (final b in pBadges) {
                          if (b is Map && b['id'] == badge['id']) {
                            claimedByName = p['name']?.toString();
                            break;
                          }
                        }
                        if (claimedByName != null) break;
                      }
                      final bool isClaimed = claimedByName != null;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppColors.headerBlue,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isClaimed
                                ? Colors.white10
                                : Colors.amber.withOpacity(0.3),
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: ColorFiltered(
                                colorFilter: isClaimed
                                    ? const ColorFilter.matrix([
                                        0.2126,
                                        0.7152,
                                        0.0722,
                                        0,
                                        0,
                                        0.2126,
                                        0.7152,
                                        0.0722,
                                        0,
                                        0,
                                        0.2126,
                                        0.7152,
                                        0.0722,
                                        0,
                                        0,
                                        0,
                                        0,
                                        0,
                                        1,
                                        0,
                                      ])
                                    : const ColorFilter.mode(
                                        Colors.transparent,
                                        BlendMode.multiply,
                                      ),
                                child: Image.asset(
                                  badge['icon'],
                                  errorBuilder: (c, e, s) => const Icon(
                                    Icons.broken_image,
                                    color: Colors.white54,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          title: Text(
                            badge['title'],
                            style: TextStyle(
                              color: isClaimed ? Colors.white54 : Colors.amber,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Text(
                            isClaimed
                                ? 'Resgatado por $claimedByName'
                                : badge['desc'],
                            style: TextStyle(
                              color: isClaimed
                                  ? Colors.redAccent.withOpacity(0.8)
                                  : Colors.white70,
                              fontSize: 12,
                              fontStyle: isClaimed
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.edit_outlined,
                                  color: Colors.amber,
                                ),
                                onPressed: () => _showBadgeSheet(
                                  badgeToEdit: badge,
                                  editIndex: i,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.redAccent,
                                ),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (c) => AlertDialog(
                                      backgroundColor: AppColors.headerBlue,
                                      title: const Text(
                                        "Remover Troféu?",
                                        style: TextStyle(color: Colors.white),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(c),
                                          child: const Text(
                                            "Cancelar",
                                            style: TextStyle(
                                              color: Colors.white54,
                                            ),
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            _removeBadge(i);
                                            Navigator.pop(c);
                                          },
                                          child: const Text(
                                            "Remover",
                                            style: TextStyle(
                                              color: Colors.redAccent,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

            // ABA 2: Efeitos
            _buildEffectsTab(),

            // ABA 3: Áudios
            _buildAudiosTab(),
          ],
        ),
        floatingActionButton: (_currentTabIndex == 0 && _customBadges.isNotEmpty)
            ? FloatingActionButton.extended(
                backgroundColor: Colors.amber,
                onPressed: () => _showBadgeSheet(),
                icon: const Icon(Icons.add, color: Colors.black),
                label: const Text(
                  "Novo Troféu",
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : null,
    );
  }
}
