import 'dart:convert';
import 'package:app_do_fut/constants/app_colors.dart';
import 'package:app_do_fut/firebase_options.dart';
import 'package:app_do_fut/screens/blank_screen.dart';
import 'package:app_do_fut/screens/group_dashboard_screen.dart';
import 'package:app_do_fut/screens/sync_screen.dart';
import 'package:app_do_fut/screens/login_screen.dart';
import 'package:app_do_fut/services/sync_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
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
  final SyncService _syncService = SyncService();
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

  // --- DRAWER HELPERS ---
  Widget _buildDrawerSection(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 16, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.white.withOpacity(0.4),
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildDrawerTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.headerBlue.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.accentBlue, size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: Colors.white12,
          size: 20,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deepBlue,

      drawer: Drawer(
        backgroundColor: AppColors.deepBlue,
        width: MediaQuery.of(context).size.width * 0.8,
        child: Column(
          children: [
            // Custom Premium Header
            Container(
              padding: const EdgeInsets.only(
                top: 60,
                left: 24,
                right: 24,
                bottom: 30,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.accentBlue,
                    AppColors.accentBlue.withOpacity(0.7),
                    AppColors.headerBlue,
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white30, width: 1),
                    ),
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 44,
                      height: 44,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Society™',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 20,
                ),
                children: [
                  _buildDrawerSection('DADOS E SINCRONIA'),
                  _buildDrawerTile(
                    icon: Icons.cloud_sync_rounded,
                    title: 'Cloud Sync',
                    subtitle: 'Sincronizar com Firebase',
                    onTap: () {
                      Navigator.pop(context);
                      final user = FirebaseAuth.instance.currentUser;
                      if (user == null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LoginScreen(),
                          ),
                        ).then((success) {
                          if (success == true) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SyncScreen(),
                              ),
                            );
                          }
                        });
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SyncScreen(),
                          ),
                        );
                      }
                    },
                  ),
                  _buildDrawerTile(
                    icon: Icons.download_rounded,
                    title: 'Exportar',
                    subtitle: 'Salvar backup local (JSON)',
                    onTap: () async {
                      Navigator.pop(context);
                      await _syncService.exportToFile();
                    },
                  ),
                  _buildDrawerTile(
                    icon: Icons.upload_file_rounded,
                    title: 'Importar',
                    subtitle: 'Restaurar de arquivo JSON',
                    onTap: () async {
                      Navigator.pop(context);
                      final imported = await _syncService.importFromFile();
                      if (!mounted) return;
                      if (imported) {
                        await _loadGroups();
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Dados importados com sucesso.'),
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  _buildDrawerSection('APLICATIVO'),
                  _buildDrawerTile(
                    icon: Icons.settings_rounded,
                    title: 'Configurações',
                    subtitle: 'Preferências do app',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const BlankScreen(),
                        ),
                      );
                    },
                  ),
                  _buildDrawerTile(
                    icon: Icons.info_outline_rounded,
                    title: 'Sobre',
                    subtitle: 'Versão 1.2.0',
                    onTap: () {},
                  ),
                  if (FirebaseAuth.instance.currentUser != null)
                    _buildDrawerTile(
                      icon: Icons.logout_rounded,
                      title: 'Sair',
                      subtitle: 'Deslogar da conta',
                      onTap: () async {
                        await FirebaseAuth.instance.signOut();
                        setState(() {});
                        if (mounted) Navigator.pop(context);
                      },
                    ),
                ],
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  const Icon(
                    Icons.copyright_rounded,
                    size: 14,
                    color: Colors.white24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Society™ Team 2024',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.15),
                      fontSize: 11,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
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
