import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_colors.dart';
import '../utils/constants.dart';
import 'package:app_do_fut/app/app_services.dart';
import '../services/avatar_style_manager.dart';
import 'manage_badges_screen.dart';
import 'admin_debug_screen.dart';
import 'manage_members_screen.dart';
import 'manage_seasons_screen.dart';
import 'manage_join_requests_screen.dart';

class SettingsScreen extends StatefulWidget {
  final String groupId;
  final bool isAdmin;

  const SettingsScreen({
    super.key,
    required this.groupId,
    this.isAdmin = false,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoading = true;

  // Preferências simples
  bool _showRadar = true;
  bool _confirmTimerEnabled = true;

  // Comportamentos padrão da partida
  bool _pitchHorizontal = true;
  bool _requireGk = true;
  bool _useCards = false;

  // Estilos de rating no avatar
  AvatarRatingStyle _rankingStyle = AvatarRatingStyle.background;
  AvatarRatingStyle _dashboardStyle = AvatarRatingStyle.background;
  AvatarRatingStyle _statsStyle = AvatarRatingStyle.background;
  AvatarRatingStyle _matchStyle = AvatarRatingStyle.halo;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await AvatarStyleManager.instance.load();
    setState(() {
      _showRadar = prefs.getBool('show_radar_chart') ?? true;
      _confirmTimerEnabled = prefs.getBool(kPrefConfirmTimerEnabled) ?? true;
      _pitchHorizontal = prefs.getBool('pitch_horizontal') ?? true;
      _requireGk = prefs.getBool('require_gk') ?? true;
      _useCards = prefs.getBool('pitch_use_cards') ??
          (!(prefs.getBool('pitch_use_chips') ?? true));

      _rankingStyle = AvatarStyleManager.instance.rankingStyle;
      _dashboardStyle = AvatarStyleManager.instance.dashboardStyle;
      _statsStyle = AvatarStyleManager.instance.statsStyle;
      _matchStyle = AvatarStyleManager.instance.matchStyle;

      _isLoading = false;
    });
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AppColors.accentBlue,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _buildNavigationTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.headerBlue,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          title: Text(
            title,
            style: const TextStyle(
              color: AppColors.textWhite,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: const TextStyle(color: AppColors.textDim, fontSize: 12),
          ),
          trailing: const Icon(Icons.chevron_right, color: AppColors.textDim),
          onTap: onTap,
        ),
      ),
    );
  }

  Widget _buildSwitchCard({
    required String title,
    required String subtitle,
    required bool value,
    required IconData icon,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.headerBlue,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Material(
        color: Colors.transparent,
        child: SwitchListTile(
          activeThumbColor: AppColors.accentBlue,
          secondary: Icon(icon, color: AppColors.accentBlue, size: 22),
          title: Text(
            title,
            style: const TextStyle(
              color: AppColors.textWhite,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: const TextStyle(color: AppColors.textDim, fontSize: 12),
          ),
          value: value,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildAvatarStyleSelector(
    String label,
    AvatarRatingStyle current,
    ValueChanged<AvatarRatingStyle> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textWhite,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SegmentedButton<AvatarRatingStyle>(
            segments: const [
              ButtonSegment(
                value: AvatarRatingStyle.off,
                label: Text('Off', style: TextStyle(fontSize: 11)),
              ),
              ButtonSegment(
                value: AvatarRatingStyle.halo,
                label: Text('Auréola', style: TextStyle(fontSize: 11)),
              ),
              ButtonSegment(
                value: AvatarRatingStyle.background,
                label: Text('Fundo', style: TextStyle(fontSize: 11)),
              ),
            ],
            selected: {current},
            onSelectionChanged: (set) {
              if (set.isNotEmpty) onChanged(set.first);
            },
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppColors.accentBlue;
                }
                return AppColors.deepBlue;
              }),
              foregroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return Colors.white;
                }
                return AppColors.textDim;
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarStyleSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.headerBlue,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accentBlue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.palette_outlined, color: AppColors.accentBlue, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Destaque de Rating nos Ícones',
                      style: TextStyle(
                        color: AppColors.textWhite,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Escolha se os avatares usam auréola externa, fundo colorido pelo rating ou sem destaque.',
                      style: TextStyle(color: AppColors.textDim, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: AppColors.borderSubtle, height: 1),
          const SizedBox(height: 10),
          _buildAvatarStyleSelector(
            'Ranking & Elenco',
            _rankingStyle,
            (val) async {
              setState(() => _rankingStyle = val);
              await AvatarStyleManager.instance.setStyle(AvatarContext.ranking, val);
            },
          ),
          _buildAvatarStyleSelector(
            'Dashboard (Início)',
            _dashboardStyle,
            (val) async {
              setState(() => _dashboardStyle = val);
              await AvatarStyleManager.instance.setStyle(AvatarContext.dashboard, val);
            },
          ),
          _buildAvatarStyleSelector(
            'Estatísticas',
            _statsStyle,
            (val) async {
              setState(() => _statsStyle = val);
              await AvatarStyleManager.instance.setStyle(AvatarContext.stats, val);
            },
          ),
          _buildAvatarStyleSelector(
            'Partida (Campo Tático)',
            _matchStyle,
            (val) async {
              setState(() => _matchStyle = val);
              await AvatarStyleManager.instance.setStyle(AvatarContext.match, val);
            },
          ),
          const SizedBox(height: 12),
          const Text(
            'Atalhos rápidos:',
            style: TextStyle(color: AppColors.textDim, fontSize: 11, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              ActionChip(
                label: const Text('Fundo no Ranking, Auréola na Partida', style: TextStyle(fontSize: 11)),
                backgroundColor: AppColors.deepBlue,
                side: const BorderSide(color: AppColors.borderSubtle),
                onPressed: () async {
                  await AvatarStyleManager.instance.applyPreset(
                    ranking: AvatarRatingStyle.background,
                    dashboard: AvatarRatingStyle.background,
                    stats: AvatarRatingStyle.background,
                    match: AvatarRatingStyle.halo,
                  );
                  setState(() {
                    _rankingStyle = AvatarRatingStyle.background;
                    _dashboardStyle = AvatarRatingStyle.background;
                    _statsStyle = AvatarRatingStyle.background;
                    _matchStyle = AvatarRatingStyle.halo;
                  });
                },
              ),
              ActionChip(
                label: const Text('Tudo Fundo', style: TextStyle(fontSize: 11)),
                backgroundColor: AppColors.deepBlue,
                side: const BorderSide(color: AppColors.borderSubtle),
                onPressed: () async {
                  await AvatarStyleManager.instance.applyPreset(
                    ranking: AvatarRatingStyle.background,
                    dashboard: AvatarRatingStyle.background,
                    stats: AvatarRatingStyle.background,
                    match: AvatarRatingStyle.background,
                  );
                  setState(() {
                    _rankingStyle = AvatarRatingStyle.background;
                    _dashboardStyle = AvatarRatingStyle.background;
                    _statsStyle = AvatarRatingStyle.background;
                    _matchStyle = AvatarRatingStyle.background;
                  });
                },
              ),
              ActionChip(
                label: const Text('Tudo Auréola', style: TextStyle(fontSize: 11)),
                backgroundColor: AppColors.deepBlue,
                side: const BorderSide(color: AppColors.borderSubtle),
                onPressed: () async {
                  await AvatarStyleManager.instance.applyPreset(
                    ranking: AvatarRatingStyle.halo,
                    dashboard: AvatarRatingStyle.halo,
                    stats: AvatarRatingStyle.halo,
                    match: AvatarRatingStyle.halo,
                  );
                  setState(() {
                    _rankingStyle = AvatarRatingStyle.halo;
                    _dashboardStyle = AvatarRatingStyle.halo;
                    _statsStyle = AvatarRatingStyle.halo;
                    _matchStyle = AvatarRatingStyle.halo;
                  });
                },
              ),
              ActionChip(
                label: const Text('Desligar Tudo', style: TextStyle(fontSize: 11)),
                backgroundColor: AppColors.deepBlue,
                side: const BorderSide(color: AppColors.borderSubtle),
                onPressed: () async {
                  await AvatarStyleManager.instance.applyPreset(
                    ranking: AvatarRatingStyle.off,
                    dashboard: AvatarRatingStyle.off,
                    stats: AvatarRatingStyle.off,
                    match: AvatarRatingStyle.off,
                  );
                  setState(() {
                    _rankingStyle = AvatarRatingStyle.off;
                    _dashboardStyle = AvatarRatingStyle.off;
                    _statsStyle = AvatarRatingStyle.off;
                    _matchStyle = AvatarRatingStyle.off;
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final features = AppServices.instance.features;
    final canAdmin = features.canAdminister(widget.isAdmin);

    return Scaffold(
      backgroundColor: AppColors.deepBlue,
      appBar: AppBar(
        backgroundColor: AppColors.headerBlue,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Configurações',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                if (canAdmin) ...[
                  _buildSectionHeader('Customizações & Gestão'),
                  _buildNavigationTile(
                    icon: Icons.workspace_premium,
                    iconColor: Colors.amber,
                    title: 'Gerenciamento de Customizáveis',
                    subtitle: 'Áudios de gol, troféus e efeitos visuais',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              ManageBadgesScreen(groupId: widget.groupId),
                        ),
                      );
                    },
                  ),
                  if (features.hasAdminDebug)
                    _buildNavigationTile(
                      icon: Icons.terminal,
                      iconColor: AppColors.highlightGreen,
                      title: 'Admin & Debug Cache',
                      subtitle: 'Diagnóstico, inspeção de cache e testes',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                AdminDebugScreen(groupId: widget.groupId),
                          ),
                        );
                      },
                    ),
                  if (features.hasMembershipManagement)
                    _buildNavigationTile(
                      icon: Icons.admin_panel_settings,
                      iconColor: AppColors.highlightGreen,
                      title: 'Gerenciar Membros',
                      subtitle: 'Administradores, membros ativos e permissões',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                ManageMembersScreen(groupId: widget.groupId),
                          ),
                        );
                      },
                    ),
                  _buildNavigationTile(
                    icon: Icons.calendar_month,
                    iconColor: AppColors.accentBlue,
                    title: 'Gerenciar Temporadas',
                    subtitle: 'Criar, fechar e ver histórico de temporadas',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              ManageSeasonsScreen(groupId: widget.groupId),
                        ),
                      );
                    },
                  ),
                  if (features.hasMembershipManagement)
                    _buildNavigationTile(
                      icon: Icons.how_to_reg,
                      iconColor: AppColors.highlightGreen,
                      title: 'Solicitações de Entrada',
                      subtitle: 'Aprovar ou recusar novos jogadores',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ManageJoinRequestsScreen(
                                groupId: widget.groupId),
                          ),
                        );
                      },
                    ),
                ],

                _buildSectionHeader('Preferências do Aplicativo'),
                _buildAvatarStyleSection(),
                _buildSwitchCard(
                  icon: Icons.radar,
                  title: 'Exibir Gráfico Radar',
                  subtitle:
                      'Mostra o gráfico pentagonal/hexagonal no perfil e no X1',
                  value: _showRadar,
                  onChanged: (val) async {
                    setState(() => _showRadar = val);
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('show_radar_chart', val);
                  },
                ),
                _buildSwitchCard(
                  icon: Icons.timer_outlined,
                  title: 'Timer de Proteção ao Encerrar',
                  subtitle:
                      'Bloqueia o botão Confirmar por 3s para evitar cliques sem ler',
                  value: _confirmTimerEnabled,
                  onChanged: (val) async {
                    setState(() => _confirmTimerEnabled = val);
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool(kPrefConfirmTimerEnabled, val);
                  },
                ),

                _buildSectionHeader('Comportamentos Padrão da Partida'),
                _buildSwitchCard(
                  icon: Icons.crop_landscape,
                  title: 'Campo Tático Horizontal',
                  subtitle:
                      'Ligado: campo na horizontal (padrão). Desligado: campo na vertical',
                  value: _pitchHorizontal,
                  onChanged: (val) async {
                    setState(() => _pitchHorizontal = val);
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('pitch_horizontal', val);
                  },
                ),
                _buildSwitchCard(
                  icon: Icons.sports_handball,
                  title: 'Obrigatoriedade de Goleiro',
                  subtitle:
                      'Exige que ambos os times tenham goleiros definidos para iniciar',
                  value: _requireGk,
                  onChanged: (val) async {
                    setState(() => _requireGk = val);
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('require_gk', val);
                  },
                ),
                _buildSwitchCard(
                  icon: Icons.badge_outlined,
                  title: 'Formato dos Jogadores no Campo',
                  subtitle:
                      'Ligado: cards estilo FIFA. Desligado: chips com foto (padrão)',
                  value: _useCards,
                  onChanged: (val) async {
                    setState(() => _useCards = val);
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('pitch_use_cards', val);
                    await prefs.setBool('pitch_use_chips', !val);
                  },
                ),
              ],
            ),
    );
  }
}
