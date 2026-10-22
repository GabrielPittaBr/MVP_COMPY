@JS()
library;

import 'dart:js_interop';

@JS('self.FIREBASE_APPCHECK_DEBUG_TOKEN')
external set _firebaseAppCheckDebugToken(JSAny? token);

/// Sets the official Firebase Web SDK debug-token override before activation.
///
/// The `generate` sentinel asks the SDK to issue and log a browser-local token;
/// all other values are passed as the registered token supplied externally.
void configureFirebaseAppCheckDebugToken(String token) {
  if (token == 'generate') {
    _firebaseAppCheckDebugToken = true.toJS;
  } else {
    _firebaseAppCheckDebugToken = token.toJS;
  }
}
