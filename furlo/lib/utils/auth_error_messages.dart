import '../services/auth_service.dart';

String authErrorMessage(AuthErrorCode code) => switch (code) {
  AuthErrorCode.invalidCredentials =>
    'Check your email and password, then try again.',
  AuthErrorCode.userNotFound => 'No account was found for those credentials.',
  AuthErrorCode.emailInUse => 'An account already exists for that email.',
  AuthErrorCode.weakPassword => 'Choose a stronger password and try again.',
  AuthErrorCode.networkError => 'Check your internet connection and try again.',
  AuthErrorCode.tooManyRequests =>
    'Too many attempts. Please wait and try again.',
  AuthErrorCode.cancelled => 'Sign-in was cancelled.',
  AuthErrorCode.unknown => 'Something went wrong. Please try again.',
};
