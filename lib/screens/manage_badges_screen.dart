import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:file_picker/file_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import '../constants/app_colors.dart';
import '../repositories/supabase_service.dart';
import '../widgets/shared/player_name_text.dart';

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

  Future<void> _pickAndUploadGoalSound(String playerId) async {
    if (!_isAdmin) return;
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: _allowedAudioExtensions,
        withData: true,
      );
      if (result == null || result.files.single.bytes == null) return;

      final file = result.files.single;
      if (file.size > _maxAudioSizeBytes) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Áudio muito grande. Máximo de 2MB.")),
          );
        }
        return;
      }

      setState(() => _uploadingPlayerId = playerId);

      final updated = await SupabaseService.instance.players.uploadGoalSound(
        groupId: widget.groupId,
        playerId: playerId,
        fileBytes: file.bytes!,
        fileExtension: file.extension ?? 'mp3',
      );

      setState(() {
        final idx = _allPlayers.indexWhere((p) => p['id'] == playerId);
        if (idx != -1) _allPlayers[idx]['goal_sound_url'] = updated.goalSoundUrl;
        _uploadingPlayerId = null;
      });
    } catch (e) {
      setState(() => _uploadingPlayerId = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao enviar áudio: $e")),
        );
      }
    }
  }

  /// Abre o card de busca (mesmo padrão de "Adicionar Jogadores" da partida)
  /// pra escolher UM jogador que ainda não tem áudio, e já dispara o upload.
  void _showPickPlayerForAudioDialog() {
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
                                _pickAndUploadGoalSound(filtered[i]['id'].toString());
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
    try {
      final updated = await SupabaseService.instance.players.clearGoalSound(
        groupId: widget.groupId,
        playerId: playerId,
      );
      setState(() {
        final idx = _allPlayers.indexWhere((p) => p['id'] == playerId);
        if (idx != -1) _allPlayers[idx]['goal_sound_url'] = updated.goalSoundUrl;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao remover áudio: $e")),
        );
      }
    }
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

  /// Mini card com rádio (nenhum/dourado/prata/bronze) + checkbox do selo
  /// de craque do mês, pra um jogador já escolhido. Reaberto tanto a partir
  /// da lista (editar) quanto do card de busca (novo).
  void _showEffectConfigDialog(Map<String, dynamic> player) {
    final String playerId = player['id'].toString();
    String? selectedEffect = player['name_effect'] as String?;
    bool monthlyHighlight = player['monthly_highlight'] == true;

    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, st) {
          Widget effectRadio(String? value, String label, Color? swatch) {
            return RadioListTile<String?>(
              value: value,
              groupValue: selectedEffect,
              activeColor: swatch ?? Colors.amber,
              title: Text(label, style: const TextStyle(color: Colors.white)),
              onChanged: (v) => st(() => selectedEffect = v),
            );
          }

          return AlertDialog(
            backgroundColor: AppColors.headerBlue,
            title: Text(
              player['name']?.toString() ?? 'Jogador',
              style: const TextStyle(color: Colors.white),
            ),
            contentPadding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  effectRadio(null, "Nenhum efeito", Colors.white54),
                  effectRadio('gold', "Nome dourado (bola de ouro)", PlayerNameEffectColors.gold),
                  effectRadio('silver', "Nome prata (artilheiro/garçom)", PlayerNameEffectColors.silver),
                  effectRadio('bronze', "Nome bronze", PlayerNameEffectColors.bronze),
                  const Divider(color: Colors.white12),
                  CheckboxListTile(
                    value: monthlyHighlight,
                    activeColor: PlayerNameEffectColors.gold,
                    title: const Text(
                      "Selo de craque do mês",
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: const Text(
                      "Ring dourado + estrela, só no pódio do ranking",
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    onChanged: (v) => st(() => monthlyHighlight = v ?? false),
                  ),
                ],
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
                  if (selectedEffect != player['name_effect']) {
                    await _setNameEffect(playerId, selectedEffect);
                  }
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
        .where((p) =>
            (p['name_effect'] as String?)?.isNotEmpty == true ||
            p['monthly_highlight'] == true)
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
                        final String? effect = player['name_effect'] as String?;
                        final bool highlight = player['monthly_highlight'] == true;
                        final bool isSaving = _savingEffectPlayerId == playerId;
                        final effectColor = PlayerNameEffectColors.forEffect(effect) ?? Colors.amber;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.headerBlue,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: effectColor.withOpacity(0.4)),
                          ),
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: effectColor.withOpacity(0.15),
                              child: Icon(Icons.auto_awesome, color: effectColor),
                            ),
                            title: PlayerNameText(
                              name: player['name']?.toString() ?? 'Jogador',
                              nameEffect: effect,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              [
                                if (effect != null) "Nome: ${effect == 'gold' ? 'Dourado' : effect == 'silver' ? 'Prata' : 'Bronze'}",
                                if (highlight) "Craque do mês",
                              ].join(' • '),
                              style: TextStyle(color: effectColor.withOpacity(0.9), fontSize: 12),
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

  Future<void> _togglePreview(String playerId, String url) async {
    if (_playingPreviewId == playerId) {
      await _previewPlayer.stop();
      setState(() => _playingPreviewId = null);
      return;
    }
    await _previewPlayer.stop();
    setState(() => _playingPreviewId = playerId);
    await _previewPlayer.play(UrlSource(url));
    _previewPlayer.onPlayerComplete.first.then((_) {
      if (mounted) setState(() => _playingPreviewId = null);
    });
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
                          ? "Jogadores com áudio de comemoração próprio (MP3/WAV/OGG/M4A, até 2MB). Quem não estiver aqui usa o som padrão do gol."
                          : "Somente administradores podem alterar os áudios de gol.",
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
                              "Áudio customizado definido",
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
                                          onPressed: () => _pickAndUploadGoalSound(playerId),
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
