/// Efeito de nome/moldura atribuído pelo admin (`players.name_effect`).
/// Valores no banco: diamond, gold, fire, silver, bronze (ou null = padrão).
enum CosmeticEffect {
  none,
  diamond,
  gold,
  fire,
  silver,
  bronze;

  /// Valor gravado em `name_effect` (null para [none]).
  String? get dbValue => this == CosmeticEffect.none ? null : name;

  static CosmeticEffect fromDb(String? value) {
    for (final e in CosmeticEffect.values) {
      if (e != CosmeticEffect.none && e.name == value) return e;
    }
    return CosmeticEffect.none;
  }
}
