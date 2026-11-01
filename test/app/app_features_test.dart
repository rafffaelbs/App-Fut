import 'package:app_do_fut/app/app_features.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppFeatures.personal()', () {
    test('possui todos os valores esperados para o flavor personal', () {
      const features = AppFeatures.personal();

      expect(features.hasAuth, isTrue);
      expect(features.hasMembershipManagement, isTrue);
      expect(features.hasCosmetics, isTrue);
      expect(features.hasGoalSounds, isTrue);
      expect(features.hasAuditLog, isTrue);
      expect(features.hasSiteSync, isTrue);
      expect(features.hasCloudDraftSync, isTrue);
      expect(features.hasAdminDebug, isTrue);
      expect(features.hasDbExportImport, isFalse);
      expect(features.isReadOnly, isFalse);
    });
  });

  group('AppFeatures.canAdminister', () {
    test('isAdmin=true e isReadOnly=false retorna true', () {
      const features = AppFeatures(
        hasAuth: true,
        hasMembershipManagement: true,
        hasCosmetics: true,
        hasGoalSounds: true,
        hasAuditLog: true,
        hasSiteSync: true,
        hasCloudDraftSync: true,
        hasAdminDebug: true,
        hasDbExportImport: false,
        isReadOnly: false,
      );

      expect(features.canAdminister(true), isTrue);
    });

    test('isAdmin=false e isReadOnly=false retorna false', () {
      const features = AppFeatures(
        hasAuth: true,
        hasMembershipManagement: true,
        hasCosmetics: true,
        hasGoalSounds: true,
        hasAuditLog: true,
        hasSiteSync: true,
        hasCloudDraftSync: true,
        hasAdminDebug: true,
        hasDbExportImport: false,
        isReadOnly: false,
      );

      expect(features.canAdminister(false), isFalse);
    });

    test('isAdmin=true e isReadOnly=true retorna false', () {
      const features = AppFeatures(
        hasAuth: false,
        hasMembershipManagement: false,
        hasCosmetics: true,
        hasGoalSounds: false,
        hasAuditLog: false,
        hasSiteSync: false,
        hasCloudDraftSync: false,
        hasAdminDebug: false,
        hasDbExportImport: false,
        isReadOnly: true,
      );

      expect(features.canAdminister(true), isFalse);
    });

    test('isAdmin=false e isReadOnly=true retorna false', () {
      const features = AppFeatures(
        hasAuth: false,
        hasMembershipManagement: false,
        hasCosmetics: true,
        hasGoalSounds: false,
        hasAuditLog: false,
        hasSiteSync: false,
        hasCloudDraftSync: false,
        hasAdminDebug: false,
        hasDbExportImport: false,
        isReadOnly: true,
      );

      expect(features.canAdminister(false), isFalse);
    });
  });
}
