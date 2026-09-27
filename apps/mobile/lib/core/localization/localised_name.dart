/// The one rule for picking a bilingual data name.
///
/// The bundled exercises and foods each carry an English `name` and an optional
/// Arabic `name_ar`. Several places need to choose between them — the models'
/// `displayName`, and the rest timer, which is handed both names because the
/// controller that starts it has no locale to resolve with. They all call this
/// so the rule, including the empty-Arabic fallback, is stated once.
String localisedName(String languageCode, String name, String? nameAr) =>
    languageCode == 'ar' && (nameAr?.isNotEmpty ?? false) ? nameAr! : name;
