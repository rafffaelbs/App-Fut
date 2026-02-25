import 'package:app_do_fut/constants/app_colors.dart';
import 'package:app_do_fut/screens/blank_screen.dart';
import 'package:app_do_fut/screens/tournament_screen.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Torneios App',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff0E6BA8),
          brightness: Brightness.dark,
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Mutable list of tournaments
  List<Map<String, dynamic>> tournaments = [
    {
      'id': 'torneio_padrao_1', 
      'title': 'Fut INF',
      'date': '14 Fev, 2026',
      'status': 'Em Andamento',
      'jogadores': 5, 
      'duration': 8, 
    },
  ];

  // --- UNIFIED FUNCTION: CREATES OR EDITS A TOURNAMENT ---
  // If 'index' is passed, it edits. If 'index' is null, it creates a new one.
  void _showTournamentDialog({int? index}) {
    final bool isEditing = index != null;
    final tournament = isEditing ? tournaments[index] : null;

    final TextEditingController nameController = TextEditingController(text: isEditing ? tournament!['title'] : '');
    final TextEditingController dateController = TextEditingController(text: isEditing ? tournament!['date'] : '');
    final TextEditingController playersController = TextEditingController(text: isEditing ? tournament!['jogadores'].toString() : '5');
    final TextEditingController timeController = TextEditingController(text: isEditing ? tournament!['duration'].toString() : '8');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, 
      backgroundColor: AppColors.headerBlue,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext ctx) {
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
                isEditing ? "Editar Torneio" : "Novo Torneio/Pelada",
                style: const TextStyle(
                  color: AppColors.textWhite,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Nome",
                  labelStyle: TextStyle(color: Colors.white54),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.accentBlue)),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: dateController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Data (ex: 20 Fev, 2026)",
                  labelStyle: TextStyle(color: Colors.white54),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.accentBlue)),
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: playersController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: "Jogadores por Time",
                        labelStyle: TextStyle(color: Colors.white54),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.accentBlue)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: timeController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: "Tempo (minutos)",
                        labelStyle: TextStyle(color: Colors.white54),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.accentBlue)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    if (nameController.text.trim().isEmpty || dateController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Preencha o nome e a data!")),
                      );
                      return;
                    }

                    setState(() {
                      final newTournamentData = {
                        // --- NEW: Generate a unique ID based on the exact millisecond ---
                        'id': isEditing ? tournament!['id'] : DateTime.now().millisecondsSinceEpoch.toString(),
                        'title': nameController.text.trim(),
                        'date': dateController.text.trim(),
                        'status': isEditing ? tournament!['status'] : 'Em Andamento',
                        'jogadores': int.tryParse(playersController.text) ?? 5,
                        'duration': int.tryParse(timeController.text) ?? 8,
                      };

                      if (isEditing) {
                        tournaments[index] = newTournamentData;
                      } else {
                        tournaments.insert(0, newTournamentData);
                      }
                    });
                    Navigator.pop(ctx);
                  },
                  child: Text(
                    isEditing ? "SALVAR ALTERAÇÕES" : "CRIAR",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  // --- NEW: FUNCTION TO DELETE TOURNAMENT ---
  void _deleteTournament(int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.headerBlue,
        title: const Text("Excluir Torneio?", style: TextStyle(color: AppColors.textWhite)),
        content: const Text("Tem certeza que deseja excluir este torneio?", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar", style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                tournaments.removeAt(index);
              });
              Navigator.pop(ctx);
            },
            child: const Text("Excluir", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deepBlue,

      drawer: Drawer(
        backgroundColor: const Color(0xff001c55),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Color(0xff0E6BA8)),
              child: Text('Menu', style: TextStyle(color: Colors.white, fontSize: 24)),
            ),
            ListTile(
              leading: const Icon(Icons.settings, color: Colors.white),
              title: const Text('Configurações', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const BlankScreen()));
              },
            ),
          ],
        ),
      ),

      appBar: AppBar(
        backgroundColor: AppColors.headerBlue,
        elevation: 0,
        title: const Text(
          'Meus Torneios',
          style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.bold, letterSpacing: 1.0),
        ),
        centerTitle: true,
      ),

      body: tournaments.isEmpty 
          ? const Center(child: Text("Nenhum torneio criado.", style: TextStyle(color: Colors.white54)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: tournaments.length,
              itemBuilder: (context, index) {
                final item = tournaments[index];
                final isLive = item['status'] == 'Em Andamento';

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Material(
                    color: AppColors.headerBlue,
                    borderRadius: BorderRadius.circular(16),
                    elevation: 4,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TournamentScreen( // Or TournamentScreen
                              tournamentName: item['title'],
                              tournamentId: item['id'], // --- NEW: Pass the ID ---
                            ),
                          ),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: isLive ? Border.all(color: AppColors.accentBlue, width: 1.5) : null,
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: CircleAvatar(
                            backgroundColor: isLive ? AppColors.accentBlue : Colors.white10,
                            child: Icon(Icons.emoji_events, color: isLive ? Colors.white : Colors.white38),
                          ),
                          title: Text(
                            item['title'],
                            style: const TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(item['date'], style: const TextStyle(color: Colors.grey)),
                                const SizedBox(width: 16),
                                const Icon(Icons.people, size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text('${item['jogadores']}x${item['jogadores']}', style: const TextStyle(color: Colors.grey)),
                                const SizedBox(width: 16),
                                const Icon(Icons.timer, size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text('${item['duration']}m', style: const TextStyle(color: Colors.grey)),
                              ],
                            ),
                          ),
                          
                          // --- UPDATED: POPUP MENU FOR EDIT / DELETE ---
                          trailing: PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, color: Colors.white54),
                            color: AppColors.headerBlue,
                            onSelected: (String value) {
                              if (value == 'edit') {
                                _showTournamentDialog(index: index);
                              } else if (value == 'delete') {
                                _deleteTournament(index);
                              }
                            },
                            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                              const PopupMenuItem<String>(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit, color: Colors.white, size: 20),
                                    SizedBox(width: 8),
                                    Text('Editar', style: TextStyle(color: Colors.white)),
                                  ],
                                ),
                              ),
                              const PopupMenuItem<String>(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete, color: Colors.redAccent, size: 20),
                                    SizedBox(width: 8),
                                    Text('Excluir', style: TextStyle(color: Colors.redAccent)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          // ----------------------------------------------
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.accentBlue,
        elevation: 10,
        shape: const CircleBorder(),
        // Just call it without arguments to create a NEW tournament
        onPressed: () => _showTournamentDialog(), 
        child: const Icon(Icons.add, color: Colors.white, size: 30),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      bottomNavigationBar: BottomAppBar(
        color: AppColors.headerBlue,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        child: SizedBox(
          height: 60.0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(icon: const Icon(Icons.home, color: Colors.white), onPressed: () {}, tooltip: 'Início'),
              IconButton(icon: const Icon(Icons.bar_chart, color: Colors.white54), onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (context) => const BlankScreen())); }, tooltip: 'Estatísticas'),
              const SizedBox(width: 48),
              IconButton(icon: const Icon(Icons.groups, color: Colors.white54), onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (context) => const BlankScreen())); }, tooltip: 'Jogadores'),
              IconButton(icon: const Icon(Icons.settings, color: Colors.white54), onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (context) => const BlankScreen())); }, tooltip: 'Configurações'),
            ],
          ),
        ),
      ),
    );
  }
}