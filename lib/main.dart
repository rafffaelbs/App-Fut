import 'dart:convert';
import 'package:app_do_fut/constants/app_colors.dart';
import 'package:app_do_fut/screens/blank_screen.dart';
import 'package:app_do_fut/screens/group_dashboard_screen.dart';
import 'package:app_do_fut/screens/sync_screen.dart';
import 'package:app_do_fut/screens/login_screen.dart';
import 'package:app_do_fut/screens/complete_profile_screen.dart';
import 'package:app_do_fut/screens/join_group_screen.dart';
import 'package:app_do_fut/services/sync_service.dart';
import 'package:app_do_fut/services/fix_event_times_service.dart';
import 'package:app_do_fut/config/supabase_config.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:app_do_fut/models/group_model.dart';
import 'package:app_do_fut/models/player_model.dart';
import 'package:app_do_fut/repositories/supabase_service.dart';

// Global route observer for tracking navigation
final RouteObserver routeObserver = RouteObserver();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseConfig.initialize();


  // para armazenamento remoto de dados.

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
      navigatorObservers: [routeObserver],
      home: const AuthGate(),
    );
  }
}

/// Decides what to show based on auth + profile-completion state:
/// not logged in -> LoginScreen; logged in but no player profile linked ->
/// CompleteProfileScreen; otherwise -> HomePage ("Meus Grupos").
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: SupabaseConfig.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = SupabaseConfig.client.auth.currentSession;
        if (session == null) {
          return const LoginScreen();
        }
        return _ProfileCheck(key: ValueKey(session.user.id));
      },
    );
  }
}

/// Auto-claims any "ghost" player matching this user's e-mail, then routes
/// to CompleteProfileScreen (no player yet) or HomePage.
class _ProfileCheck extends StatefulWidget {
  const _ProfileCheck({super.key});

  @override
  State<_ProfileCheck> createState() => _ProfileCheckState();
}

class _ProfileCheckState extends State<_ProfileCheck> {
  bool _loading = true;
  bool _hasProfile = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    try {
      // Automatically links "ghost" players with the same email.
      await SupabaseService.instance.players.claimGhostProfiles();
      final myPlayers = await SupabaseService.instance.players.getMyPlayers();
      if (mounted) setState(() => _hasProfile = myPlayers.isNotEmpty);
    } catch (e) {
      debugPrint('Error checking profile: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.deepBlue,
        body: Center(child: CircularProgressIndicator(color: AppColors.accentBlue)),
      );
    }

    if (!_hasProfile) {
      final email = SupabaseConfig.currentUser?.email ?? '';
      return CompleteProfileScreen(
        initialEmail: email,
        onDone: (name) {
          // The player itself is only created when the person creates or joins
          // a group (players needs to exist linked to a group_members).
          // We store the chosen name and move on to Home, which uses that
          // name as a suggestion in both flows.
          setState(() {
            _pendingName = name;
            _hasProfile = true; // moves on to Home; the group will create the player
          });
        },
      );
    }

    return HomePage(suggestedName: _pendingName);
  }

  String? _pendingName;
}

class HomePage extends StatefulWidget {
  final String? suggestedName;

  const HomePage({super.key, this.suggestedName});

  @override
  State createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final SyncService _syncService = SyncService();
  List<GroupModel> groups = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _openJoinGroupScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => JoinGroupScreen(defaultName: widget.suggestedName ?? ''),
      ),
    );
    await _loadGroups();
  }

  // --- PERSISTENCE: LOAD ---
  Future _loadGroups() async {
    setState(() => isLoading = true);
    try {
      final fetchedGroups = await SupabaseService.instance.groups.getMyGroups();
      setState(() {
        groups = fetchedGroups;
      });
    } catch (e) {
      debugPrint("Error loading groups: $e");
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  // --- MAINTENANCE: Fix event times from backup ---
  Future<void> _runFixEventTimes() async {
    Navigator.pop(context); // fecha o drawer

    // Caminho absoluto do arquivo de backup
    const backupPath = '/home/marinho/Documents/github/App-Fut/pelada_backup_1789226662128.json';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final List<String> progressLines = ['Iniciando...'];
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.headerBlue,
              title: const Text('Corrigindo Tempos', style: TextStyle(color: Colors.white)),
              content: SizedBox(
                width: double.maxFinite,
                height: 280,
                child: ListView.builder(
                  itemCount: progressLines.length,
                  itemBuilder: (_, i) => Text(
                    progressLines[i],
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    try {
      final result = await FixEventTimesService().run(
        backupJsonPath: backupPath,
        onProgress: (msg) => debugPrint(msg),
      );

      if (mounted) Navigator.pop(context); // fecha o loading dialog

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.headerBlue,
            title: const Text('Concluído!', style: TextStyle(color: Colors.white)),
            content: Text(
              '✅ ${result['updated']} eventos atualizados\n⏭️ ${result['skipped']} partidas sem alteração\n❌ ${(result['errors'] as List).length} erros',
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK', style: TextStyle(color: AppColors.accentBlue)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // --- UNIFIED DIALOG: CREATE OR EDIT ---
  void _showGroupDialog({int? index}) {
    final bool isEditing = index != null;
    final group = isEditing ? groups[index] : null;

    final TextEditingController nameController = TextEditingController(
      text: isEditing ? group!.name : '',
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
                  onPressed: () async {
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

                    Navigator.pop(ctx);
                    setState(() => isLoading = true);

                    try {
                      if (isEditing) {
                        final updatedGroup = group!.copyWith(name: nameController.text.trim());
                        await SupabaseService.instance.groups.updateGroup(updatedGroup);
                      } else {
                        await SupabaseService.instance.groups.createGroup(
                          name: nameController.text.trim(),
                          adminPlayerName: widget.suggestedName,
                        );
                      }
                      await _loadGroups();
                    } catch (e) {
                      debugPrint('Error saving group: $e');
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Erro: ${e.toString()}')),
                        );
                      }
                    } finally {
                      if (mounted) {
                        setState(() => isLoading = false);
                      }
                    }
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
          "Tem certeza? Isso removerá o grupo e todos os dados associados.",
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
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => isLoading = true);
              try {
                await SupabaseService.instance.groups.deleteGroup(groups[index].id);
                await _loadGroups();
              } catch (e) {
                debugPrint('Error deleting group: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erro: ${e.toString()}')),
                  );
                }
              } finally {
                if (mounted) {
                  setState(() => isLoading = false);
                }
              }
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
                  _buildDrawerTile(
                    icon: Icons.info_outline_rounded,
                    title: 'Sobre',
                    subtitle: 'Versão 1.2.0',
                    onTap: () {},
                  ),
                  _buildDrawerTile(
                    icon: Icons.timer_rounded,
                    title: 'Corrigir Tempos',
                    subtitle: 'Restaurar horários dos eventos do backup',
                    onTap: () => _runFixEventTimes(),
                  ),
                  _buildDrawerTile(
                    icon: Icons.group_add_rounded,
                    title: 'Entrar em um grupo',
                    subtitle: 'Solicitar entrada com um código de convite',
                    onTap: () {
                      Navigator.pop(context);
                      _openJoinGroupScreen();
                    },
                  ),
                  _buildDrawerTile(
                    icon: Icons.logout_rounded,
                    title: 'Sair',
                    subtitle: SupabaseConfig.currentUser?.email ?? '',
                    onTap: () async {
                      Navigator.pop(context);
                      await SupabaseConfig.client.auth.signOut();
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
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Nenhum grupo ainda.",
                    style: TextStyle(color: Colors.white54),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _openJoinGroupScreen,
                    icon: const Icon(Icons.group_add_rounded, color: Colors.white),
                    label: const Text('Entrar com código de convite'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.headerBlue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "ou toque no + para criar seu próprio grupo",
                    style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12),
                  ),
                ],
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
                              groupId: group.id,
                              groupName: group.name,
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
                          group.name,
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
                        trailing: PopupMenuButton(
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
