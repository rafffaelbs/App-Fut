import 'package:flutter/material.dart';

import 'bootstrap_web.dart';
import 'constants/app_colors.dart';
import 'screens/group_dashboard_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final result = await bootstrapWeb(initializeFlutterBinding: false);
  runApp(AppWeb(result: result));
}

/// Aplicação Flutter Web em modo somente leitura via token.
class AppWeb extends StatelessWidget {
  final BootstrapWebResult result;

  const AppWeb({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    if (result.isValid && result.group != null) {
      final group = result.group!;
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: group.name,
        theme: AppTheme.dark,
        home: GroupDashboardScreen(
          groupId: group.id,
          groupName: group.name,
        ),
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Pelada Manager',
      theme: AppTheme.dark,
      home: const InvalidLinkScreen(),
    );
  }
}

/// Tela exibida quando o link não possui token ou o token é inválido/revogado.
class InvalidLinkScreen extends StatelessWidget {
  const InvalidLinkScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.deepBlue,
      body: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.0),
          child: Text(
            'Link inválido ou desativado. Peça um novo link ao administrador.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
