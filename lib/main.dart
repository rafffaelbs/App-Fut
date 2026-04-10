import 'dart:convert';
import 'package:app_do_fut/constants/app_colors.dart';
import 'package:app_do_fut/screens/blank_screen.dart';
import 'package:app_do_fut/screens/group_dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:app_do_fut/firebase_options.dart';
import 'package:app_do_fut/screens/sync_screen.dart';
import 'package:app_do_fut/services/sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Pelada Manager',
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
  List<Map<String, dynamic>> groups = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  // --- PERSISTENCE: LOAD & SAVE ---
  Future<void> _loadGroups() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? savedGroups = prefs.getString('app_groups');

      if (savedGroups != null && savedGroups.isNotEmpty) {
        // Decode the JSON string into a generic List
        final List<dynamic> decodedData = jsonDecode(savedGroups);

        setState(() {
          // Safely map each dynamic item back into a Map<String, dynamic>
          groups = decodedData
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
        });
      }
    } catch (e) {
      // If the saved data is corrupted, we catch the error here so the app doesn't freeze
      debugPrint("Error loading groups: $e");
    } finally {
      // The 'finally' block ensures this line runs NO MATTER WHAT happens above
      setState(() => isLoading = false);
    }
  }

  Future<void> _saveGroups() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_groups', jsonEncode(groups));
  }

  // --- UNIFIED DIALOG: CREATE OR EDIT ---
  void _showGroupDialog({int? index}) {
    final bool isEditing = index != null;
    final group = isEditing ? groups[index] : null;

    final TextEditingController nameController = TextEditingController(
      text: isEditing ? group!['name'] : '',
    );

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
                isEditing ? "Editar Grupo" : "Novo Grupo de Futebol",
                style: const TextStyle(
                  color: AppColors.textWhite,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: nameController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Nome do Grupo",
                  hintText: "Ex: Futebol de Quinta",
                  hintStyle: TextStyle(color: Colors.white24),
                  labelStyle: TextStyle(color: Colors.white54),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: AppColors.accentBlue),
                  ),
                ),
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
                        const SnackBar(
                          content: Text(
                            "O nome do grupo não pode estar vazio!",
                          ),
                        ),
                      );
                      return;
                    }

                    setState(() {
                      final newGroupData = {
                        'id': isEditing
                            ? group!['id']
                            : 'grupo_${DateTime.now().millisecondsSinceEpoch}',
                        'name': nameController.text.trim(),
                        'createdAt': isEditing
                            ? group!['createdAt']
                            : DateTime.now().toIso8601String(),
                      };

                      if (isEditing) {
                        groups[index] = newGroupData;
                      } else {
                        groups.insert(0, newGroupData);
                      }
                    });

                    _saveGroups();
                    Navigator.pop(ctx);
                  },
                  child: Text(
                    isEditing ? "SALVAR ALTERAÇÕES" : "CRIAR GRUPO",
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
  }

  void _deleteGroup(int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.headerBlue,
        title: const Text(
          "Excluir Grupo?",
          style: TextStyle(color: AppColors.textWhite),
        ),
        content: const Text(
          "Tem certeza? Isso removerá o grupo da sua lista principal.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              "Cancelar",
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                groups.removeAt(index);
              });
              _saveGroups();
              Navigator.pop(ctx);
            },
            child: const Text(
              "Excluir",
              style: TextStyle(color: Colors.redAccent),
            ),
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
              child: Text(
                'Pelada App',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.settings, color: Colors.white),
              title: const Text(
                'Configurações',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BlankScreen()),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.cloud_sync, color: Colors.white),
              title: const Text(
                'Sincronização na Nuvem',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SyncScreen()),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.file_upload, color: Colors.white),
              title: const Text(
                'Exportar Banco de Dados',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () async {
                Navigator.pop(context);
                try {
                  await SyncService().exportToFile();
                } catch(e) {
                   if (context.mounted) {
                     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao exportar: $e')));
                   }
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.file_download, color: Colors.white),
              title: const Text(
                'Importar Banco de Dados',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () async {
                Navigator.pop(context);
                try {
                  bool success = await SyncService().importFromFile();
                  if (success && context.mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const HomePage()),
                      (route) => false,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Dados importados com sucesso!"),
                        backgroundColor: Colors.green,
                      )
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Erro ao importar: $e")),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),

      appBar: AppBar(
        backgroundColor: AppColors.headerBlue,
        elevation: 0,
        title: const Text(
          'Meus Grupos',
          style: TextStyle(
            color: AppColors.textWhite,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        centerTitle: true,
      ),

      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accentBlue),
            )
          : groups.isEmpty
          ? const Center(
              child: Text(
                "Nenhum grupo criado ainda.",
                style: TextStyle(color: Colors.white54),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: groups.length,
              itemBuilder: (context, index) {
                final group = groups[index];

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
                            builder: (context) => GroupDashboardScreen(
                              groupId: group['id'],
                              groupName: group['name'],
                            ),
                          ),
                        );
                      },
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        leading: const CircleAvatar(
                          backgroundColor: AppColors.accentBlue,
                          child: Icon(Icons.groups, color: Colors.white),
                        ),
                        title: Text(
                          group['name'],
                          style: const TextStyle(
                            color: AppColors.textWhite,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        subtitle: const Text(
                          "Toque para ver elenco e jogos",
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                        trailing: PopupMenuButton<String>(
                          icon: const Icon(
                            Icons.more_vert,
                            color: Colors.white54,
                          ),
                          color: AppColors.headerBlue,
                          onSelected: (value) {
                            if (value == 'edit') _showGroupDialog(index: index);
                            if (value == 'delete') _deleteGroup(index);
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('Editar'),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text(
                                'Excluir',
                                style: TextStyle(color: Colors.redAccent),
                              ),
                            ),
                          ],
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
        onPressed: () => _showGroupDialog(),
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
              IconButton(
                icon: const Icon(Icons.home, color: Colors.white),
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.bar_chart, color: Colors.white54),
                onPressed: () {},
              ),
              const SizedBox(width: 48), // Space for FAB
              IconButton(
                icon: const Icon(Icons.person, color: Colors.white54),
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.settings, color: Colors.white54),
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }
}
