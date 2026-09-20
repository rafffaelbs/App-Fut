import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/season_model.dart';
import '../repositories/supabase_service.dart';

class ManageSeasonsScreen extends StatefulWidget {
  final String groupId;

  const ManageSeasonsScreen({super.key, required this.groupId});

  @override
  State<ManageSeasonsScreen> createState() => _ManageSeasonsScreenState();
}

class _ManageSeasonsScreenState extends State<ManageSeasonsScreen> {
  List<SeasonModel> _seasons = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSeasons();
  }

  Future<void> _loadSeasons() async {
    setState(() => _isLoading = true);
    try {
      final fetched = await SupabaseService.instance.seasons.getSeasons(widget.groupId);
      setState(() => _seasons = fetched);
    } catch (e) {
      debugPrint('Error loading seasons: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSeasonDialog({SeasonModel? season}) {
    final TextEditingController nameCtrl = TextEditingController(text: season?.name);
    DateTime? startDate = season?.startDate;
    DateTime? endDate = season?.endDate;
    bool isActiveFlag = season?.isActive ?? false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: AppColors.headerBlue,
              title: Text(
                season == null ? 'Nova Temporada' : 'Editar Temporada',
                style: const TextStyle(color: Colors.white),
              ),
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
                        enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white24)),
                        focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: AppColors.accentBlue)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.deepBlue),
                            onPressed: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: startDate ?? DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (date != null) setStateDialog(() => startDate = date);
                            },
                            child: Text(
                              startDate == null
                                  ? 'Início'
                                  : '${startDate!.day}/${startDate!.month}/${startDate!.year}',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.deepBlue),
                            onPressed: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: endDate ?? DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (date != null) setStateDialog(() => endDate = date);
                            },
                            child: Text(
                              endDate == null
                                  ? 'Fim'
                                  : '${endDate!.day}/${endDate!.month}/${endDate!.year}',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    CheckboxListTile(
                      title: const Text('Temporada atual?',
                          style: TextStyle(color: Colors.white)),
                      value: isActiveFlag,
                      activeColor: AppColors.accentBlue,
                      checkColor: Colors.white,
                      onChanged: (val) {
                        setStateDialog(() => isActiveFlag = val ?? false);
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar',
                      style: TextStyle(color: Colors.white54)),
                ),
                TextButton(
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty) return;
                    if (startDate != null &&
                        endDate != null &&
                        startDate!.isAfter(endDate!)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'A data de início deve ser menor ou igual à data de fim.')),
                      );
                      return;
                    }

                    Navigator.pop(ctx);
                    setState(() => _isLoading = true);

                    try {
                      if (season == null) {
                        await SupabaseService.instance.seasons.createSeason(
                          groupId: widget.groupId,
                          name: nameCtrl.text.trim(),
                          startDate: startDate,
                          endDate: endDate,
                          isActive: isActiveFlag,
                        );
                      } else {
                        final updated = season.copyWith(
                          name: nameCtrl.text.trim(),
                          startDate: startDate,
                          endDate: endDate,
                          isActive: isActiveFlag,
                        );
                        await SupabaseService.instance.seasons.updateSeason(updated);
                      }
                      await _loadSeasons();
                    } catch (e) {
                      debugPrint('Error saving season: $e');
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Erro: ${e.toString()}')),
                        );
                      }
                    } finally {
                      if (mounted) setState(() => _isLoading = false);
                    }
                  },
                  child: const Text('Salvar',
                      style: TextStyle(color: AppColors.highlightGreen)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteSeason(SeasonModel season) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.headerBlue,
        title: const Text('Excluir temporada?',
            style: TextStyle(color: Colors.white)),
        content: Text(
          'Deseja excluir "${season.name}"? Isso removerá as sessões e partidas vinculadas.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      await SupabaseService.instance.seasons.deleteSeason(
        groupId: widget.groupId,
        seasonId: season.id,
      );
      await _loadSeasons();
    } catch (e) {
      debugPrint('Error deleting season: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deepBlue,
      appBar: AppBar(
        title: const Text('Gerenciar Temporadas',
            style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.headerBlue,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accentBlue))
          : _seasons.isEmpty
              ? const Center(
                  child: Text(
                    'Nenhuma temporada cadastrada.\nClique no + para criar.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _seasons.length,
                  itemBuilder: (context, index) {
                    final s = _seasons[index];
                    return Card(
                      color: AppColors.headerBlue,
                      child: ListTile(
                        title: Row(
                          children: [
                            Text(
                              s.name,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                            if (s.isActive) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.highlightGreen,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Atual',
                                  style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ]
                          ],
                        ),
                        subtitle: s.startDate != null && s.endDate != null
                            ? Text(
                                '${s.startDate!.day.toString().padLeft(2, '0')}/${s.startDate!.month.toString().padLeft(2, '0')}/${s.startDate!.year}'
                                ' - '
                                '${s.endDate!.day.toString().padLeft(2, '0')}/${s.endDate!.month.toString().padLeft(2, '0')}/${s.endDate!.year}',
                                style: const TextStyle(color: Colors.white54),
                              )
                            : const Text('Sem datas definidas',
                                style: TextStyle(color: Colors.white38)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit,
                                  color: AppColors.accentBlue),
                              onPressed: () => _showSeasonDialog(season: s),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete,
                                  color: Colors.redAccent),
                              onPressed: () => _deleteSeason(s),
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
