import '../services/auth_service.dart';

/// User-facing copy for an auth failure.
///
/// Delegates to the single table in `auth_service.dart` so the two cannot
/// drift apart. This indirection exists only so screens can import a `utils/`
/// helper rather than reaching into the service layer for copy.
String authErrorMessage(AuthErrorCode code) => authErrorText(code);
