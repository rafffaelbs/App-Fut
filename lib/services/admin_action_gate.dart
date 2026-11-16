import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_colors.dart';

/// Interface para abstrair a autenticação biométrica ou credenciais do aparelho.
/// Permite o uso de fakes/stubs em testes sem depender do hardware real.
abstract class DeviceAuthenticator {
  Future<bool> isDeviceSupported();
  Future<bool> authenticate({required String localizedReason});
}

/// Implementação padrão de [DeviceAuthenticator] usando o pacote `local_auth`.
class LocalAuthDeviceAuthenticator implements DeviceAuthenticator {
  final LocalAuthentication _auth = LocalAuthentication();

  @override
  Future<bool> isDeviceSupported() async {
    if (kIsWeb) return false;
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> authenticate({required String localizedReason}) async {
    if (kIsWeb) return false;
    try {
      return await _auth.authenticate(
        localizedReason: localizedReason,
        options: const AuthenticationOptions(
          biometricOnly: false, // Digital OU PIN/padrão do aparelho
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}

/// Chaves de SharedPreferences para o controle de ação do administrador.
class AdminGatePrefs {
  static const String mode = 'admin_gate_mode';
  static const String passHash = 'admin_gate_pass_hash';
  static const String passSalt = 'admin_gate_pass_salt';

  static const String modeDevice = 'device';
  static const String modePassword = 'password';
}

/// Utilitários de hash para senhas usando SHA-256 e sal aleatório via Random.secure.
class AdminGateSecurity {
  static String generateSalt([int length = 16]) {
    final random = Random.secure();
    final values = List<int>.generate(length, (_) => random.nextInt(256));
    return values.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static String hashPassword(String password, String salt) {
    final bytes = utf8.encode('$salt:$password');
    return sha256.convert(bytes).toString();
  }
}

/// Gerenciador da confirmação de ações do administrador.
class AdminActionGate {
  static AdminActionGate instance = AdminActionGate();

  DeviceAuthenticator authenticator;

  AdminActionGate({DeviceAuthenticator? authenticator})
      : authenticator = authenticator ?? LocalAuthDeviceAuthenticator();

  // Estado em memória para rate limiting
  int _failedAttempts = 0;
  DateTime? _lockoutUntil;

  int get failedAttempts => _failedAttempts;
  bool get isLocked => _lockoutUntil != null && DateTime.now().isBefore(_lockoutUntil!);
  int get lockoutRemainingSeconds =>
      isLocked ? (_lockoutUntil!.difference(DateTime.now()).inSeconds + 1) : 0;

  void recordFailedAttempt() {
    _failedAttempts++;
    if (_failedAttempts >= 5) {
      _lockoutUntil = DateTime.now().add(const Duration(seconds: 30));
    }
  }

  void resetFailedAttempts() {
    _failedAttempts = 0;
    _lockoutUntil = null;
  }

  Future<String> getMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mode = prefs.getString(AdminGatePrefs.mode);
      if (mode == AdminGatePrefs.modePassword) {
        return AdminGatePrefs.modePassword;
      }
      return AdminGatePrefs.modeDevice;
    } catch (_) {
      return AdminGatePrefs.modeDevice;
    }
  }

  Future<void> setMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AdminGatePrefs.mode, mode);
  }

  Future<bool> hasPasswordConfigured() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hash = prefs.getString(AdminGatePrefs.passHash);
      final salt = prefs.getString(AdminGatePrefs.passSalt);
      return hash != null && hash.isNotEmpty && salt != null && salt.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> savePassword(String password) async {
    final prefs = await SharedPreferences.getInstance();
    final salt = AdminGateSecurity.generateSalt();
    final hash = AdminGateSecurity.hashPassword(password, salt);
    await prefs.setString(AdminGatePrefs.passSalt, salt);
    await prefs.setString(AdminGatePrefs.passHash, hash);
    resetFailedAttempts();
  }

  Future<bool> verifyEnteredPassword(String password) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hash = prefs.getString(AdminGatePrefs.passHash);
      final salt = prefs.getString(AdminGatePrefs.passSalt);
      if (hash == null || salt == null) return false;
      final computed = AdminGateSecurity.hashPassword(password, salt);
      return computed == hash;
    } catch (_) {
      return false;
    }
  }
}

/// Função única para confirmação de ações destrutivas do administrador.
/// Retorna `true` apenas se a autenticação tiver sucesso garantido.
/// Qualquer erro, exceção ou cancelamento retorna `false`.
Future<bool> confirmAdminAction(
  BuildContext context, {
  required String motivo,
  AdminActionGate? gate,
}) async {
  final g = gate ?? AdminActionGate.instance;

  try {
    final mode = await g.getMode();
    if (!context.mounted) return false;

    if (mode == AdminGatePrefs.modePassword) {
      return await _confirmViaPassword(context, motivo: motivo, gate: g);
    } else {
      return await _confirmViaDevice(context, motivo: motivo, gate: g);
    }
  } catch (e) {
    debugPrint('Erro em confirmAdminAction: $e');
    return false;
  }
}

void _showGateMessage(BuildContext context, String message, {bool isError = true}) {
  if (!context.mounted) return;
  try {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 4),
      ),
    );
  } catch (_) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.headerBlue,
        title: Text(isError ? 'Aviso' : 'Sucesso', style: const TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(color: AppColors.accentBlue)),
          ),
        ],
      ),
    );
  }
}

Future<bool> _confirmViaDevice(
  BuildContext context, {
  required String motivo,
  required AdminActionGate gate,
}) async {
  try {
    // isDeviceSupported cobre digital, PIN, padrão e senha de tela.
    final isSupported = await gate.authenticator.isDeviceSupported();

    if (!context.mounted) return false;

    if (!isSupported) {
      _showGateMessage(
        context,
        "Ative um bloqueio de tela no celular ou escolha 'Usar senha' nas Configurações",
        isError: true,
      );
      return false;
    }

    final success = await gate.authenticator.authenticate(
      localizedReason: 'Confirme para $motivo',
    );
    return success;
  } catch (_) {
    return false;
  }
}

Future<bool> _confirmViaPassword(
  BuildContext context, {
  required String motivo,
  required AdminActionGate gate,
}) async {
  if (!context.mounted) return false;

  final hasPass = await gate.hasPasswordConfigured();
  if (!context.mounted) return false;

  if (!hasPass) {
    _showGateMessage(
      context,
      "Defina a senha nas Configurações",
      isError: true,
    );
    return false;
  }

  if (gate.isLocked) {
    _showGateMessage(
      context,
      "Muitas tentativas incorretas. Tente novamente em ${gate.lockoutRemainingSeconds} segundos.",
      isError: true,
    );
    return false;
  }

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AdminPasswordDialog(
      motivo: motivo,
      gate: gate,
      hostContext: context,
    ),
  );

  return result ?? false;
}

/// Diálogo para digitação da senha do administrador.
class AdminPasswordDialog extends StatefulWidget {
  final String motivo;
  final AdminActionGate gate;

  /// Contexto da tela que abriu o diálogo. Continua válido depois que o
  /// diálogo fecha (usado no fluxo "Esqueci a senha").
  final BuildContext? hostContext;

  const AdminPasswordDialog({
    super.key,
    required this.motivo,
    required this.gate,
    this.hostContext,
  });

  @override
  State<AdminPasswordDialog> createState() => _AdminPasswordDialogState();
}

class _AdminPasswordDialogState extends State<AdminPasswordDialog> {
  final TextEditingController _passController = TextEditingController();
  bool _obscureText = true;
  String? _errorMessage;

  @override
  void dispose() {
    _passController.dispose();
    super.dispose();
  }

  Future<void> _handleConfirm() async {
    final text = _passController.text.trim();
    if (text.isEmpty) {
      setState(() => _errorMessage = 'Digite a senha.');
      return;
    }

    if (widget.gate.isLocked) {
      Navigator.pop(context, false);
      _showGateMessage(
        context,
        "Muitas tentativas incorretas. Tente novamente em ${widget.gate.lockoutRemainingSeconds} segundos.",
        isError: true,
      );
      return;
    }

    final ok = await widget.gate.verifyEnteredPassword(text);
    if (!mounted) return;

    if (ok) {
      widget.gate.resetFailedAttempts();
      Navigator.pop(context, true);
    } else {
      widget.gate.recordFailedAttempt();
      if (widget.gate.isLocked) {
        Navigator.pop(context, false);
        _showGateMessage(
          context,
          "Muitas tentativas incorretas. Tente novamente em ${widget.gate.lockoutRemainingSeconds} segundos.",
          isError: true,
        );
      } else {
        setState(() {
          final remaining = 5 - widget.gate.failedAttempts;
          _errorMessage = 'Senha incorreta ($remaining tentativas restantes).';
        });
      }
    }
  }

  Future<void> _handleForgotPassword() async {
    final host = widget.hostContext ?? context;
    final gate = widget.gate;
    Navigator.pop(context, false);
    if (!host.mounted) return;
    await handleAdminForgotPassword(host, gate: gate);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.headerBlue,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Confirmar Ação',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Confirme para: ${widget.motivo}',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passController,
              obscureText: _obscureText,
              keyboardType: TextInputType.text,
              style: const TextStyle(color: Colors.white),
              autofocus: true,
              onSubmitted: (_) => _handleConfirm(),
              decoration: InputDecoration(
                hintText: 'Senha do administrador',
                hintStyle: const TextStyle(color: Colors.white38),
                errorText: _errorMessage,
                errorMaxLines: 2,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureText ? Icons.visibility_off : Icons.visibility,
                    color: Colors.white54,
                  ),
                  onPressed: () => setState(() => _obscureText = !_obscureText),
                ),
                enabledBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.accentBlue),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _handleForgotPassword,
                child: const Text(
                  'Esqueci a senha',
                  style: TextStyle(color: AppColors.accentBlue, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
        ),
        ElevatedButton(
          onPressed: _handleConfirm,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accentBlue,
            foregroundColor: Colors.white,
          ),
          child: const Text('Confirmar'),
        ),
      ],
    );
  }
}

/// Fluxo de "Esqueci a senha".
Future<void> handleAdminForgotPassword(
  BuildContext context, {
  AdminActionGate? gate,
}) async {
  final g = gate ?? AdminActionGate.instance;

  try {
    final isSupported = await g.authenticator.isDeviceSupported();

    if (!isSupported) {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.headerBlue,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Recuperação de Senha', style: TextStyle(color: Colors.white)),
            content: const Text(
              'O aparelho não possui bloqueio de tela configurado. Para redefinir a senha, limpe os dados do aplicativo nas configurações do celular.',
              style: TextStyle(color: Colors.white70),
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
      return;
    }

    final authenticated = await g.authenticator.authenticate(
      localizedReason: 'Confirme sua identidade no aparelho para redefinir a senha',
    );

    if (!authenticated || !context.mounted) return;

    final created = await showAdminSetPasswordDialog(context, gate: g, isReset: true);
    if (created && context.mounted) {
      _showGateMessage(context, 'Nova senha definida com sucesso!', isError: false);
    }
  } catch (e) {
    debugPrint('Erro em handleAdminForgotPassword: $e');
  }
}

/// Diálogo para criar ou trocar senha (mínimo 4 dígitos, digitar duas vezes).
Future<bool> showAdminSetPasswordDialog(
  BuildContext context, {
  AdminActionGate? gate,
  bool isReset = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _AdminSetPasswordDialog(
      gate: gate ?? AdminActionGate.instance,
      isReset: isReset,
    ),
  );
  return result ?? false;
}

class _AdminSetPasswordDialog extends StatefulWidget {
  final AdminActionGate gate;
  final bool isReset;

  const _AdminSetPasswordDialog({
    required this.gate,
    required this.isReset,
  });

  @override
  State<_AdminSetPasswordDialog> createState() => _AdminSetPasswordDialogState();
}

class _AdminSetPasswordDialogState extends State<_AdminSetPasswordDialog> {
  final TextEditingController _passController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  bool _obscure1 = true;
  bool _obscure2 = true;
  String? _errorMessage;

  @override
  void dispose() {
    _passController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final pass = _passController.text.trim();
    final confirm = _confirmController.text.trim();

    if (pass.length < 4) {
      setState(() => _errorMessage = 'A senha deve ter no mínimo 4 dígitos.');
      return;
    }

    if (pass != confirm) {
      setState(() => _errorMessage = 'As senhas não coincidem.');
      return;
    }

    await widget.gate.savePassword(pass);
    await widget.gate.setMode(AdminGatePrefs.modePassword);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.headerBlue,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        widget.isReset ? 'Redefinir Senha' : 'Criar Senha de Administrador',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Defina uma senha com no mínimo 4 dígitos para proteger as ações do administrador.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passController,
              obscureText: _obscure1,
              keyboardType: TextInputType.text,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Nova senha',
                labelStyle: const TextStyle(color: Colors.white70),
                hintText: 'Mínimo 4 dígitos',
                hintStyle: const TextStyle(color: Colors.white38),
                suffixIcon: IconButton(
                  icon: Icon(_obscure1 ? Icons.visibility_off : Icons.visibility, color: Colors.white54),
                  onPressed: () => setState(() => _obscure1 = !_obscure1),
                ),
                enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.accentBlue)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmController,
              obscureText: _obscure2,
              keyboardType: TextInputType.text,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Confirmar nova senha',
                labelStyle: const TextStyle(color: Colors.white70),
                hintText: 'Digite novamente',
                hintStyle: const TextStyle(color: Colors.white38),
                errorText: _errorMessage,
                errorMaxLines: 2,
                suffixIcon: IconButton(
                  icon: Icon(_obscure2 ? Icons.visibility_off : Icons.visibility, color: Colors.white54),
                  onPressed: () => setState(() => _obscure2 = !_obscure2),
                ),
                enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.accentBlue)),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
        ),
        ElevatedButton(
          onPressed: _handleSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accentBlue,
            foregroundColor: Colors.white,
          ),
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}
