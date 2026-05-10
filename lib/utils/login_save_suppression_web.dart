// Conditional web implementation only (see login_save_suppression.dart).
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

/// Best-effort: Chrome still may show its own UI, but this reduces save prompts.
void patchWebLoginInputsAutocompleteOff() {
  for (final html.Element e in html.document.querySelectorAll('input')) {
    if (e is html.InputElement) {
      e.autocomplete = 'off';
    }
  }
}
