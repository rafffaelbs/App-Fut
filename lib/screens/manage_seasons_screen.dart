import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../constants/app_colors.dart';

class ManageSeasonsScreen extends StatefulWidget {
  final String groupId;

  const ManageSeasonsScreen({super.key, required this.groupId});

  @override
  State<ManageSeasonsScreen> createState() => _ManageSeasonsScreenState();
}

class _ManageSeasonsScreenState extends State<ManageSeasonsScreen> {
  static const Uuid _uuid = Uuid();
  List<Map<String, dynamic>> _seasons = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSeasons();
  }

  Future<void> _loadSeasons() async {
    final prefs = await SharedPreferences.getInstance();
    final String key = 'seasons_${widget.groupId}';
    if (prefs.containsKey(key)) {
      final List<dynamic> decoded = jsonDecode(prefs.getString(key)!);
      setState(() {
        _seasons = List<Map<String, dynamic>>.from(decoded);
      });
    }
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _saveSeasons() async {
    final prefs = await SharedPreferences.getInstance();
    final String key = 'seasons_${widget.groupId}';
    await prefs.setString(key, jsonEncode(_seasons));
  }

  void _showSeasonDialog({Map<String, dynamic>? season}) {
    final TextEditingController nameCtrl = TextEditingController(text: season?['name']);
    DateTime? startDate = season != null ? DateTime.tryParse(season['startDate'] ?? '') : null;
    DateTime? endDate = season != null ? DateTime.tryParse(season['endDate'] ?? '') : null;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: AppColors.headerBlue,
              title: Text(season == null ? 'Nova Temporada' : 'Editar Temporada', style: const TextStyle(color: Colors.white)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Nome (ex: 2026.1)',
                        labelStyle: TextStyle(color: Colors.white54),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.accentBlue)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.deepBlue),
                            onPressed: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: startDate ?? DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (date != null) setStateDialog(() => startDate = date);
                            },
                            child: Text(startDate == null ? 'Início' : '${startDate!.day}/${startDate!.month}/${startDate!.year}', style: const TextStyle(color: Colors.white70)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.deepBlue),
                            onPressed: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: endDate ?? DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (date != null) setStateDialog(() => endDate = date);
                            },
                            child: Text(endDate == null ? 'Fim' : '${endDate!.day}/${endDate!.month}/${endDate!.year}', style: const TextStyle(color: Colors.white70)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
                ),
                TextButton(
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty || startDate == null || endDate == null) return;
                    if (startDate!.isAfter(endDate!)) {
                       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A data de início deve ser menor ou igual à data de fim.')));
                       return;
                    }

                    setState(() {
                      if (season == null) {
                        _seasons.add({
                          'id': _uuid.v4(),
                          'name': nameCtrl.text.trim(),
                          'startDate': startDate!.toIso8601String(),
                          'endDate': endDate!.toIso8601String(),
                        });
                      } else {
                        season['name'] = nameCtrl.text.trim();
                        season['startDate'] = startDate!.toIso8601String();
                        season['endDate'] = endDate!.toIso8601String();
                      }
                      // Ordena temporadas da mais recente para a mais antiga (baseado no endDate)
                      _seasons.sort((a, b) => DateTime.parse(b['endDate']).compareTo(DateTime.parse(a['endDate'])));
                    });
                    await _saveSeasons();
                    if (context.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Salvar', style: TextStyle(color: AppColors.highlightGreen)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _deleteSeason(int index) async {
    setState(() {
      _seasons.removeAt(index);
    });
    await _saveSeasons();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deepBlue,
      appBar: AppBar(
        title: const Text('Gerenciar Temporadas', style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.headerBlue,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _seasons.isEmpty
              ? const Center(
                  child: Text('Nenhuma temporada cadastrada.\nClique no + para criar.',
                      textAlign: TextAlign.center, style: TextStyle(color: Colors.white54)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _seasons.length,
                  itemBuilder: (context, index) {
                    final s = _seasons[index];
                    final start = DateTime.parse(s['startDate']);
                    final end = DateTime.parse(s['endDate']);
                    return Card(
                      color: AppColors.headerBlue,
                      child: ListTile(
                        title: Text(s['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          '${start.day.toString().padLeft(2, '0')}/${start.month.toString().padLeft(2, '0')}/${start.year} - ${end.day.toString().padLeft(2, '0')}/${end.month.toString().padLeft(2, '0')}/${end.year}',
                          style: const TextStyle(color: Colors.white54),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: AppColors.accentBlue),
                              onPressed: () => _showSeasonDialog(season: s),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.redAccent),
                              onPressed: () => _deleteSeason(index),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.accentBlue,
        onPressed: () => _showSeasonDialog(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
