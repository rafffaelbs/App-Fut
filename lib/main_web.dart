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
class AppWeb extends StatefulWidget {
  final BootstrapWebResult result;
  final Future<BootstrapWebResult> Function()? bootstrapCaller;

  const AppWeb({
    super.key,
    required this.result,
    this.bootstrapCaller,
  });

  @override
  State<AppWeb> createState() => _AppWebState();
}

class _AppWebState extends State<AppWeb> {
  late BootstrapWebResult _currentResult;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentResult = widget.result;
  }

  @override
  void didUpdateWidget(covariant AppWeb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.result != oldWidget.result) {
      _currentResult = widget.result;
    }
  }

  Future<void> _retry() async {
    setState(() => _isLoading = true);
    try {
      final caller = widget.bootstrapCaller ??
          (() => bootstrapWeb(initializeFlutterBinding: false));
      final res = await caller();
      if (mounted) {
        setState(() {
          _currentResult = res;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _currentResult = BootstrapWebResult.connectionError();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentResult.isSuccess && _currentResult.group != null) {
      final group = _currentResult.group!;
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

    if (_currentResult.isConnectionError) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Pelada Manager',
        theme: AppTheme.dark,
        home: ConnectionErrorScreen(
          isLoading: _isLoading,
          onRetry: _retry,
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

/// Tela exibida quando ocorre falha de conexão na carga dos dados da web.
class ConnectionErrorScreen extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onRetry;

  const ConnectionErrorScreen({
    super.key,
    required this.isLoading,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deepBlue,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Não foi possível carregar. Verifique a internet',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),
              if (isLoading)
                const CircularProgressIndicator(color: AppColors.accentBlue)
              else
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  onPressed: onRetry,
                  child: const Text(
                    'Tentar de novo',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
            ],
          ),
        ),
      ),
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
