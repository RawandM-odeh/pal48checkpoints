import 'login_save_suppression_stub.dart'
    if (dart.library.html) 'login_save_suppression_web.dart'
    as impl;

void patchWebLoginInputsAutocompleteOff() {
  impl.patchWebLoginInputsAutocompleteOff();
}
