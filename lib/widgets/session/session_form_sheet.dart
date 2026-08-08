import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../constants/app_colors.dart';
import '../../models/session.dart';

/// Abre a bottom sheet de criação/edição de uma [Session].
///
/// Não acessa SharedPreferences — apenas monta/atualiza a [Session] e a entrega
/// via [onSubmit]. Quando [existing] é informado, edita a pelada; caso contrário,
/// cria uma nova (mantendo `id`, `status` e demais chaves legadas).
Future<void> showSessionFormSheet(
  BuildContext context, {
  Session? existing,
  required ValueChanged<Session> onSubmit,
}) async {
  final bool isEditing = existing != null;

  final TextEditingController nameController = TextEditingController(
    text: existing?.title ?? '',
  );
  final TextEditingController playersController = TextEditingController(
    text: isEditing ? '${existing.jogadores}' : '4',
  );
  final TextEditingController timeController = TextEditingController(
    text: isEditing ? '${existing.duration}' : '8',
  );

  bool isInfiniteLimit = isEditing ? existing.hasInfiniteWinLimit : false;
  final TextEditingController winLimitController = TextEditingController(
    text: isEditing && !existing.hasInfiniteWinLimit
        ? '${existing.winLimit}'
        : '3',
  );
  bool isDraftMode = isEditing ? existing.draftMode : false;
  String streakAction = isEditing ? existing.streakAction : 'split';

  DateTime selectedDate = existing?.dateTime ?? DateTime.now();
  final TextEditingController dateController = TextEditingController(
    text: _formatDate(selectedDate),
  );

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.headerBlue,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (BuildContext ctx) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 24,
              right: 24,
              top: 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEditing ? "Editar Pelada" : "Nova Pelada / Sessão",
                  style: const TextStyle(
                    color: AppColors.textWhite,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                _formField(
                  controller: nameController,
                  label: "Nome (ex: Pelada 12/03)",
                ),
                const SizedBox(height: 16),
                _dateField(
                  controller: dateController,
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                      builder: (BuildContext context, Widget? child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.dark(
                              primary: AppColors.accentBlue,
                              onPrimary: Colors.white,
                              surface: AppColors.deepBlue,
                              onSurface: Colors.white,
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (picked != null) {
                      setModalState(() {
                        selectedDate = picked;
                        dateController.text = _formatDate(picked);
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _formField(
                        controller: playersController,
                        label: "Jogadores por Time",
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _formField(
                        controller: timeController,
                        label: "Tempo (minutos)",
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _formField(
                        controller: winLimitController,
                        label: "Limite de Vitórias Seguidas",
                        keyboardType: TextInputType.number,
                        enabled: !isInfiniteLimit,
                        dimmed: isInfiniteLimit,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: isInfiniteLimit,
                          activeColor: AppColors.accentBlue,
                          onChanged: (bool? val) {
                            setModalState(() {
                              isInfiniteLimit = val ?? false;
                            });
                          },
                        ),
                        const Text(
                          "Sem limite",
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (!isInfiniteLimit) ...[
                  const Text(
                    "Ação ao Atingir Limite",
                    style: TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  _segmentedButton(
                    options: const [
                      SegmentedOption('split', 'Dividir Vencedor'),
                      SegmentedOption('dual_exit', 'Ambos Saem'),
                    ],
                    selectedValue: streakAction,
                    onChanged: (String value) {
                      setModalState(() => streakAction = value);
                    },
                  ),
                  const SizedBox(height: 16),
                ],
                const Text(
                  "Modo de Formação de Times",
                  style: TextStyle(color: Colors.white54, fontSize: 14),
                ),
                const SizedBox(height: 8),
                _segmentedSelector(
                  selectedValue: isDraftMode,
                  onChanged: (bool value) {
                    setModalState(() => isDraftMode = value);
                  },
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      if (nameController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Preencha o nome!")),
                        );
                        return;
                      }

                      onSubmit(_buildSession(
                        existing: existing,
                        title: nameController.text.trim(),
                        date: dateController.text.trim(),
                        selectedDate: selectedDate,
                        jogadores: int.tryParse(playersController.text) ?? 5,
                        duration: int.tryParse(timeController.text) ?? 8,
                        winLimit: isInfiniteLimit
                            ? 0
                            : (int.tryParse(winLimitController.text) ?? 3),
                        streakAction: streakAction,
                        draftMode: isDraftMode,
                      ));
                      Navigator.pop(context);
                    },
                    child: Text(
                      isEditing ? "SALVAR ALTERAÇÕES" : "CRIAR",
                      style: const TextStyle(
                        color: Colors.white,
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
      );
    },
  );
}

Session _buildSession({
  required Session? existing,
  required String title,
  required String date,
  required DateTime selectedDate,
  required int jogadores,
  required int duration,
  required int winLimit,
  required String streakAction,
  required bool draftMode,
}) {
  final bool isEditing = existing != null;
  return Session(
    id: isEditing
        ? existing.id
        : 'session_${title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}_${const Uuid().v4().substring(0, 4)}',
    title: title,
    date: date,
    timestamp: selectedDate.toIso8601String(),
    status: isEditing ? existing.status : Session.statusEmAndamento,
    jogadores: jogadores,
    duration: duration,
    winLimit: winLimit,
    streakAction: streakAction,
    draftMode: draftMode,
  );
}

String _formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

Widget _formField({
  required TextEditingController controller,
  required String label,
  TextInputType? keyboardType,
  bool enabled = true,
  bool dimmed = false,
}) {
  return TextField(
    controller: controller,
    enabled: enabled,
    keyboardType: keyboardType,
    style: TextStyle(color: dimmed ? Colors.white38 : Colors.white),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54),
      enabledBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: Colors.white24),
      ),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.accentBlue),
      ),
    ),
  );
}

Widget _dateField({
  required TextEditingController controller,
  required VoidCallback onTap,
}) {
  return TextField(
    controller: controller,
    readOnly: true,
    style: const TextStyle(color: Colors.white),
    decoration: const InputDecoration(
      labelText: "Data",
      labelStyle: TextStyle(color: Colors.white54),
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: Colors.white24),
      ),
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.accentBlue),
      ),
      suffixIcon: Icon(
        Icons.calendar_month,
        color: AppColors.accentBlue,
      ),
    ),
    onTap: onTap,
  );
}

class SegmentedOption {
  final String value;
  final String label;
  const SegmentedOption(this.value, this.label);
}

Widget _segmentedButton({
  required List<SegmentedOption> options,
  required String selectedValue,
  required ValueChanged<String> onChanged,
}) {
  return Container(
    width: double.infinity,
    height: 40,
    decoration: BoxDecoration(
      color: Colors.white10,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: options.map((option) {
        final bool selected = option.value == selectedValue;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(option.value),
            child: Container(
              decoration: BoxDecoration(
                color: selected ? AppColors.accentBlue : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                option.label,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white54,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    ),
  );
}

Widget _segmentedSelector({
  required bool selectedValue,
  required ValueChanged<bool> onChanged,
}) {
  return Container(
    width: double.infinity,
    height: 40,
    decoration: BoxDecoration(
      color: Colors.white10,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => onChanged(false),
            child: Container(
              decoration: BoxDecoration(
                color: !selectedValue ? AppColors.accentBlue : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                "Sorteio",
                style: TextStyle(
                  color: !selectedValue ? Colors.white : Colors.white54,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: GestureDetector(
            onTap: () => onChanged(true),
            child: Container(
              decoration: BoxDecoration(
                color: selectedValue ? AppColors.accentBlue : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                "Draft (Capitães) - Beta",
                style: TextStyle(
                  color: selectedValue ? Colors.white : Colors.white54,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}