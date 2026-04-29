import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../constants/app_colors.dart';

class ManageBadgesScreen extends StatefulWidget {
  final String groupId;

  const ManageBadgesScreen({super.key, required this.groupId});

  @override
  State<ManageBadgesScreen> createState() => _ManageBadgesScreenState();
}

class _ManageBadgesScreenState extends State<ManageBadgesScreen> {
  List<Map<String, dynamic>> _customBadges = [];
  bool _isLoading = true;
  static const Uuid _uuid = Uuid();

  // LISTA DE ASSETS QUE VOCÊ VAI COLOCAR NO GITHUB DEPOIS
  final List<String> _availableAssets = [
    'assets/badges/bola_de_ouro.png',
    'assets/badges/craque_do_mes.png',
    'assets/badges/bola_de_prata.png',
    'assets/badges/chuteira_de_ouro.png',
    'assets/badges/luva_de_ouro.png',
    'assets/badges/trofeu_campeao.png',
    'assets/badges/estrela_mes.png',
    'assets/badges/craque_galera.png',
    'assets/badges/bagre_mes.png',
  ];

  @override
  void initState() {
    super.initState();
    _loadBadges();
  }

  Future<void> _loadBadges() async {
    final prefs = await SharedPreferences.getInstance();
    final String key = 'custom_badges_${widget.groupId}';
    if (prefs.containsKey(key)) {
      setState(() {
        _customBadges = List<Map<String, dynamic>>.from(jsonDecode(prefs.getString(key)!));
      });
    }
    setState(() => _isLoading = false);
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
    String selectedIcon = badgeToEdit != null ? badgeToEdit['icon'] : _availableAssets.first;
    if (!_availableAssets.contains(selectedIcon)) selectedIcon = _availableAssets.first;

    final titleController = TextEditingController(text: badgeToEdit?['title'] ?? '');
    final descController = TextEditingController(text: badgeToEdit?['desc'] ?? '');
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
              left: 20, right: 20, top: 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.workspace_premium, color: Colors.amber),
                    const SizedBox(width: 8),
                    Text(isEditing ? "Editar Troféu" : "Criar Novo Troféu", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 20),
                const Text("Escolha o Ícone (Assets):", style: TextStyle(color: Colors.white70, fontSize: 12)),
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
                            color: isSelected ? AppColors.headerBlue : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isSelected ? Colors.amber : Colors.white12, width: isSelected ? 2 : 1),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Image.asset(
                              asset,
                              fit: BoxFit.contain,
                              // Caso a imagem não exista ainda, mostra um ícone genérico
                              errorBuilder: (c, e, s) => const Icon(Icons.image_not_supported, color: Colors.white24),
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
                  decoration: const InputDecoration(labelText: "Nome do Prêmio (ex: Melhor de Março)", labelStyle: TextStyle(color: Colors.white54)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: "Descrição curta (ex: Artilheiro e MVP)", labelStyle: TextStyle(color: Colors.white54)),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, padding: const EdgeInsets.symmetric(vertical: 14)),
                    onPressed: () {
                      if (titleController.text.trim().isNotEmpty) {
                        if (isEditing && editIndex != null) {
                          _editBadge(editIndex, titleController.text.trim(), descController.text.trim(), selectedIcon);
                        } else {
                          _addBadge(titleController.text.trim(), descController.text.trim(), selectedIcon);
                        }
                        Navigator.pop(ctx);
                      }
                    },
                    child: Text(isEditing ? "Salvar Alterações" : "Salvar Troféu", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deepBlue,
      appBar: AppBar(
        backgroundColor: AppColors.headerBlue,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text("Fábrica de Troféus", style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accentBlue))
          : _customBadges.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.emoji_events_outlined, color: Colors.white24, size: 80),
                      const SizedBox(height: 16),
                      const Text("Nenhum troféu criado.", style: TextStyle(color: Colors.white54, fontSize: 16)),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                        icon: const Icon(Icons.add, color: Colors.black),
                        label: const Text("Criar Primeiro Troféu", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                        onPressed: () => _showBadgeSheet(),
                      )
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _customBadges.length,
                  itemBuilder: (ctx, i) {
                    final badge = _customBadges[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppColors.headerBlue,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: Container(
                          width: 50, height: 50,
                          decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Image.asset(
                              badge['icon'],
                              errorBuilder: (c, e, s) => const Icon(Icons.broken_image, color: Colors.white54),
                            ),
                          ),
                        ),
                        title: Text(badge['title'], style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 16)),
                        subtitle: Text(badge['desc'], style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: Colors.amber),
                              onPressed: () => _showBadgeSheet(badgeToEdit: badge, editIndex: i),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (c) => AlertDialog(
                                    backgroundColor: AppColors.headerBlue,
                                    title: const Text("Remover Troféu?", style: TextStyle(color: Colors.white)),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(c), child: const Text("Cancelar", style: TextStyle(color: Colors.white54))),
                                      TextButton(onPressed: () { _removeBadge(i); Navigator.pop(c); }, child: const Text("Remover", style: TextStyle(color: Colors.redAccent))),
                                    ],
                                  )
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: _customBadges.isNotEmpty
          ? FloatingActionButton.extended(
              backgroundColor: Colors.amber,
              onPressed: () => _showBadgeSheet(),
              icon: const Icon(Icons.add, color: Colors.black),
              label: const Text("Novo Troféu", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }
}
