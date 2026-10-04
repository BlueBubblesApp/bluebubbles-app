import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';

enum ThemePresetAction {
  clone,
  rename,
  delete;
}

class PresetThemeActions {
  static const String cloneLabel = "Clone";
  static const String renameLabel = "Rename";
  static const String deleteLabel = "Delete";

  static String? validateThemeName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return "Please enter a theme name";
    }
    if (ThemeStruct.findOne(trimmed) != null) {
      return "A theme with that name already exists";
    }
    return null;
  }

  static void showThemeNameError(String name) {
    final err = validateThemeName(name);
    if (err != null) {
      showSnackbar("Error", err, type: SnackbarType.error);
    }
  }
}
