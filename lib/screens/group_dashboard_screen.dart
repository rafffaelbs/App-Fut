import 'package:app_do_fut/constants/app_colors.dart';
import 'package:app_do_fut/screens/group_ranking_screen.dart';
import 'package:app_do_fut/screens/players_screen.dart';
import 'package:app_do_fut/screens/sessions_screen.dart';
import 'package:app_do_fut/screens/manage_badges_screen.dart'; // <-- IMPORTANTE
import 'package:app_do_fut/screens/manage_seasons_screen.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GroupDashboardScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const GroupDashboardScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<GroupDashboardScreen> createState() => _GroupDashboardScreenState();
}

class _GroupDashboardScreenState extends State<GroupDashboardScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      SessionsScreen(groupId: widget.groupId), 
      GroupRankingScreen(groupId: widget.groupId),
      PlayersScreen(groupId: widget.groupId),
    ];

    final List<String> titles = ["Peladas", "Estatísticas Gerais", "Elenco"];

    return Scaffold(
      backgroundColor: AppColors.deepBlue,
      appBar: AppBar(
        backgroundColor: AppColors.headerBlue,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          titles[_currentIndex],
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.settings, color: Colors.white),
            color: AppColors.headerBlue,
            onSelected: (value) async {
              // Exige senha 0101
              final TextEditingController passCtrl = TextEditingController();
              bool auth = false;
              await showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: AppColors.headerBlue,
                  title: const Text('Área Administrativa', style: TextStyle(color: Colors.white)),
                  content: TextField(
                    controller: passCtrl,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Senha',
                      labelStyle: TextStyle(color: Colors.white54),
                    ),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.white54))),
                    TextButton(
                      onPressed: () {
                        if (passCtrl.text == '0101') {
                          auth = true;
                          Navigator.pop(ctx);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Senha incorreta!')));
                        }
                      },
                      child: const Text('Entrar', style: TextStyle(color: AppColors.accentBlue)),
                    ),
                  ],
                ),
              );

              if (!auth || !context.mounted) return;

              if (value == 'badges') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ManageBadgesScreen(groupId: widget.groupId)),
                );
              } else if (value == 'seasons') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ManageSeasonsScreen(groupId: widget.groupId)),
                );
              } else if (value == 'settings') {
                showDialog(
                  context: context,
                  builder: (ctx) {
                    return FutureBuilder<SharedPreferences>(
                      future: SharedPreferences.getInstance(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                        final prefs = snapshot.data!;
                        bool showRadar = prefs.getBool('show_radar_chart') ?? true;
                        
                        return StatefulBuilder(
                          builder: (context, setDialogState) {
                            return AlertDialog(
                              backgroundColor: AppColors.headerBlue,
                              title: const Text('Configurações', style: TextStyle(color: Colors.white)),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SwitchListTile(
                                    title: const Text('Exibir Gráfico Radar', style: TextStyle(color: Colors.white)),
                                    subtitle: const Text('Mostra o gráfico no perfil e X1', style: TextStyle(color: Colors.white54, fontSize: 12)),
                                    activeColor: AppColors.accentBlue,
                                    value: showRadar,
                                    onChanged: (val) {
                                      prefs.setBool('show_radar_chart', val);
                                      setDialogState(() { showRadar = val; });
                                    },
                                  ),
                                ],
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('Fechar', style: TextStyle(color: AppColors.accentBlue)),
                                ),
                              ],
                            );
                          }
                        );
                      }
                    );
                  }
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'badges',
                child: Row(children: [Icon(Icons.workspace_premium, color: Colors.amber, size: 20), SizedBox(width: 8), Text('Gerenciar Troféus', style: TextStyle(color: Colors.white))]),
              ),
              const PopupMenuItem(
                value: 'seasons',
                child: Row(children: [Icon(Icons.calendar_month, color: AppColors.accentBlue, size: 20), SizedBox(width: 8), Text('Gerenciar Temporadas', style: TextStyle(color: Colors.white))]),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(children: [Icon(Icons.settings, color: Colors.grey, size: 20), SizedBox(width: 8), Text('Configurações', style: TextStyle(color: Colors.white))]),
              ),
            ],
          ),
        ],
      ),

      body: screens[_currentIndex], 

      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: AppColors.headerBlue,
        selectedItemColor: AppColors.accentBlue,
        unselectedItemColor: Colors.white54,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            label: "Peladas",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: "Ranking",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.groups), label: "Elenco"),
        ],
      ),
    );
  }
}
