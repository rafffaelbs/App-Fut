/// Feature flags do aplicativo por flavor/distribuição.
///
/// Define capacidades e telas disponíveis em cada variante (personal, public, web_readonly).
class AppFeatures {
  const AppFeatures({
    required this.hasAuth,
    required this.hasMembershipManagement,
    required this.hasCosmetics,
    required this.hasGoalSounds,
    required this.hasAuditLog,
    required this.hasSiteSync,
    required this.hasCloudDraftSync,
    required this.hasAdminDebug,
    required this.hasDbExportImport,
    required this.isReadOnly,
  });

  /// Configuração padrão do app personal (Blue Lock / Supabase).
  const factory AppFeatures.personal() = _PersonalAppFeatures;

  /// Autenticação com Supabase Auth (login / sign up).
  final bool hasAuth;

  /// Gestão de membros, convites, códigos de grupo e solicitações de entrada.
  final bool hasMembershipManagement;

  /// Efeitos visuais de nome, Bola de Ouro e Craque do Mês.
  final bool hasCosmetics;

  /// Escolha e atribuição de áudios customizados de comemoração de gol.
  final bool hasGoalSounds;

  /// Gravação de log de auditoria de ações administrativas.
  final bool hasAuditLog;

  /// Sincronização periódica do pacote completo de dados para o site (`sync_data`).
  final bool hasSiteSync;

  /// Sincronização em tempo real do rascunho da partida no Supabase.
  final bool hasCloudDraftSync;

  /// Painel administrativo de diagnóstico, teste de conexão e inspeção de cache.
  final bool hasAdminDebug;

  /// Ferramentas de exportação e importação de banco de dados SQLite (.db).
  final bool hasDbExportImport;

  /// Modo somente leitura (bloqueia qualquer ação de escrita).
  final bool isReadOnly;

  /// Indica se o usuário pode executar ações de administração no contexto do grupo.
  bool canAdminister(bool isAdmin) => !isReadOnly && isAdmin;
}

class _PersonalAppFeatures extends AppFeatures {
  const _PersonalAppFeatures()
      : super(
          hasAuth: true,
          hasMembershipManagement: true,
          hasCosmetics: true,
          hasGoalSounds: true,
          hasAuditLog: true,
          hasSiteSync: true,
          hasCloudDraftSync: true,
          hasAdminDebug: true,
          hasDbExportImport: false,
          isReadOnly: true,
        );
}
