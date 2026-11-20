import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_colors.dart';
import '../utils/tactical_formation.dart';

class ManageFormationsScreen extends StatefulWidget {
  final String groupId;

  const ManageFormationsScreen({super.key, required this.groupId});

  @override
  State<ManageFormationsScreen> createState() => _ManageFormationsScreenState();
}

class _ManageFormationsScreenState extends State<ManageFormationsScreen> {
  bool _isLoading = true;
  late SharedPreferences _prefs;
  int _selectedTeamSize = 5; // default 5x5 (4 na linha)

  // Map of team size to selected formation rows label
  final Map<int, String> _currentDefaults = {};

  // Formatos suportados: de 4x4 até 11x11
  static const List<int> _supportedSizes = [4, 5, 6, 7, 8, 9, 10, 11];

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    for (final size in _supportedSizes) {
      // lineCount correspondente (geralmente size - 1 para jogos com goleiro,
      // ou o próprio size se for contagem pura de linha).
      // Salva tanto para o size quanto para size - 1 para máxima compatibilidade.
      final lineCount = size - 1;
      final current = FormationManager.getPreferredFormation(lineCount, _prefs);
      _currentDefaults[size] = formationRowsLabel(current);
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectFormation(int teamSize, List<int> rows) async {
    final lineCount = teamSize - 1;
    await FormationManager.setPreferredFormation(lineCount, rows, _prefs);
    // Também salva para o número cheio caso jogue sem goleiro
    await FormationManager.setPreferredFormation(teamSize, rows, _prefs);

    final label = formationRowsLabel(rows);
    setState(() {
      _currentDefaults[teamSize] = label;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Formação padrão para ${teamSize}x$teamSize definida como $label'),
          duration: const Duration(seconds: 2),
          backgroundColor: AppColors.highlightGreen,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deepBlue,
      appBar: AppBar(
        backgroundColor: AppColors.headerBlue,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Formações Táticas Padrão',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accentBlue))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Banner explicativo
                Container(
                  padding: const EdgeInsets.all(16),
                  color: AppColors.headerBlue.withValues(alpha: 0.5),
                  child: const Row(
                    children: [
                      Icon(Icons.tune, color: AppColors.accentBlue, size: 28),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Escolha a formação tática padrão para cada formato de jogo. Ela será usada no campinho da pelada e no validador de times.',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),

                // Seletor horizontal de formato (4x4 a 11x11)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'FORMATO DO JOGO',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
                SizedBox(
                  height: 48,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: _supportedSizes.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final size = _supportedSizes[index];
                      final isSelected = size == _selectedTeamSize;
                      final currentLabel = _currentDefaults[size] ?? '';

                      return ChoiceChip(
                        selected: isSelected,
                        selectedColor: AppColors.accentBlue,
                        backgroundColor: AppColors.headerBlue,
                        label: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${size}x$size',
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.white70,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            if (currentLabel.isNotEmpty)
                              Text(
                                currentLabel,
                                style: TextStyle(
                                  color: isSelected ? Colors.white70 : Colors.white38,
                                  fontSize: 10,
                                ),
                              ),
                          ],
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _selectedTeamSize = size);
                          }
                        },
                      );
                    },
                  ),
                ),

                const SizedBox(height: 16),
                const Divider(color: Color(0xFF1E3A6E), height: 1),

                // Lista de opções de formações para o tamanho selecionado
                Expanded(
                  child: _buildFormationsListForSize(_selectedTeamSize),
                ),
              ],
            ),
    );
  }

  Widget _buildFormationsListForSize(int teamSize) {
    final lineCount = teamSize - 1;
    final presets = formationPresets(lineCount);
    final currentLabel = _currentDefaults[teamSize] ?? formationRowsLabel(formationRows(lineCount));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            'FORMAÇÕES DISPONÍVEIS PARA ${teamSize}x$teamSize (${lineCount} jogadores de linha + goleiro)',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
        ),
        for (final rows in presets) ...[
          _buildFormationCard(teamSize, rows, currentLabel == formationRowsLabel(rows)),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildFormationCard(int teamSize, List<int> rows, bool isSelected) {
    final label = formationRowsLabel(rows);
    return InkWell(
      onTap: () => _selectFormation(teamSize, rows),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.headerBlue,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.highlightGreen : const Color(0xFF1E3A6E),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.highlightGreen.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            // Miniatura visual do campinho tático
            Container(
              width: 80,
              height: 90,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF152A4A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white12),
              ),
              child: _buildMiniField(rows),
            ),
            const SizedBox(width: 16),
            // Informações da formação
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.highlightGreen.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.highlightGreen, width: 1),
                          ),
                          child: const Text(
                            'PADRÃO',
                            style: TextStyle(
                              color: AppColors.highlightGreen,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _describeFormation(rows),
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
            // Ícone de seleção
            Icon(
              isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isSelected ? AppColors.highlightGreen : Colors.white30,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  /// Desenha uma miniatura estilizada do campinho com as fileiras de pontos
  Widget _buildMiniField(List<int> rows) {
    // Da defesa (base) para o ataque (topo)
    // rows são ordenadas do goleiro para o ataque: rows[0] é defesa, rows.last é ataque
    final displayRows = rows.reversed.toList();

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (final count in displayRows)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (var i = 0; i < count; i++)
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.accentBlue,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        // Goleiro no fundo
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: Colors.amber,
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }

  String _describeFormation(List<int> rows) {
    if (rows.length == 2) {
      return '${rows[0]} defensores, ${rows[1]} atacantes';
    } else if (rows.length == 3) {
      return '${rows[0]} defensores, ${rows[1]} meias, ${rows[2]} atacantes';
    } else if (rows.length == 4) {
      return '${rows[0]} defensores, ${rows[1]} volantes, ${rows[2]} meias, ${rows[3]} atacantes';
    }
    return rows.map((c) => '$c na linha').join(' + ');
  }
}
