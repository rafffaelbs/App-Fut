import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
          (() => bootstrapWeb(
                tokenOverride: _currentResult.token,
                initializeFlutterBinding: false,
              ));
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
          _currentResult = BootstrapWebResult.connectionError(
            token: _currentResult.token,
          );
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final token = _currentResult.token;

    if (_currentResult.isSuccess && _currentResult.group != null) {
      final group = _currentResult.group!;
      final routeName = token != null && token.isNotEmpty ? '/g/$token' : '/';

      return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: group.name,
        theme: AppTheme.dark,
        initialRoute: routeName,
        onGenerateInitialRoutes: (initialRoute) {
          return [
            MaterialPageRoute(
              settings: RouteSettings(name: initialRoute),
              builder: (context) => GroupDashboardScreen(
                groupId: group.id,
                groupName: group.name,
              ),
            ),
          ];
        },
        onGenerateRoute: (settings) {
          return MaterialPageRoute(
            settings: settings,
            builder: (context) => GroupDashboardScreen(
              groupId: group.id,
              groupName: group.name,
            ),
          );
        },
        navigatorObservers: [
          if (token != null && token.isNotEmpty) _WebTokenRouteObserver(token),
        ],
      );
    }

    if (_currentResult.isConnectionError) {
      final routeName = token != null && token.isNotEmpty ? '/g/$token' : '/';

      return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Pelada Manager',
        theme: AppTheme.dark,
        initialRoute: routeName,
        onGenerateInitialRoutes: (initialRoute) {
          return [
            MaterialPageRoute(
              settings: RouteSettings(name: initialRoute),
              builder: (context) => ConnectionErrorScreen(
                isLoading: _isLoading,
                onRetry: _retry,
              ),
            ),
          ];
        },
        onGenerateRoute: (settings) {
          return MaterialPageRoute(
            settings: settings,
            builder: (context) => ConnectionErrorScreen(
              isLoading: _isLoading,
              onRetry: _retry,
            ),
          );
        },
        navigatorObservers: [
          if (token != null && token.isNotEmpty) _WebTokenRouteObserver(token),
        ],
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Pelada Manager',
      theme: AppTheme.dark,
      initialRoute: '/',
      onGenerateInitialRoutes: (initialRoute) {
        return [
          MaterialPageRoute(
            settings: RouteSettings(name: initialRoute),
            builder: (context) => const InvalidLinkScreen(),
          ),
        ];
      },
      onGenerateRoute: (settings) {
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => const InvalidLinkScreen(),
        );
      },
    );
  }
}

/// Garante que a URL do navegador mantenha o fragmento com o token durante
/// toda a navegação (ao abrir, ao navegar entre telas, ao voltar e após F5).
class _WebTokenRouteObserver extends NavigatorObserver {
  final String token;

  _WebTokenRouteObserver(this.token);

  void _ensureTokenInUrl() {
    if (token.isNotEmpty) {
      SystemNavigator.routeInformationUpdated(uri: Uri.parse('/g/$token'));
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _ensureTokenInUrl();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _ensureTokenInUrl();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _ensureTokenInUrl();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    _ensureTokenInUrl();
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
