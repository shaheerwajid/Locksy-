import 'dart:io';
import 'package:flutter/material.dart';
import 'package:CryptoChat/widgets/mostrar_alerta.dart';

enum ErrorType {
  network,
  authentication,
  server,
  validation,
  unknown,
}

class AppError {
  final ErrorType type;
  final String message;
  final int? statusCode;
  final dynamic originalError;

  AppError({
    required this.type,
    required this.message,
    this.statusCode,
    this.originalError,
  });

  factory AppError.fromException(dynamic exception) {
    if (exception is SocketException) {
      return AppError(
        type: ErrorType.network,
        message: 'No internet connection. Please check your network.',
        originalError: exception,
      );
    } else if (exception is HttpException) {
      return AppError(
        type: ErrorType.network,
        message: 'Network error: ${exception.message}',
        originalError: exception,
      );
    } else {
      return AppError(
        type: ErrorType.unknown,
        message: exception.toString(),
        originalError: exception,
      );
    }
  }

  factory AppError.fromStatusCode(int statusCode, String? message) {
    ErrorType type;
    String errorMessage = message ?? 'An error occurred';

    if (statusCode == 401 || statusCode == 403) {
      type = ErrorType.authentication;
      errorMessage = 'Authentication failed. Please login again.';
    } else if (statusCode >= 500) {
      type = ErrorType.server;
      errorMessage = 'Server error. Please try again later.';
    } else if (statusCode >= 400) {
      type = ErrorType.validation;
      errorMessage = message ?? 'Invalid request. Please check your input.';
    } else {
      type = ErrorType.unknown;
    }

    return AppError(
      type: type,
      message: errorMessage,
      statusCode: statusCode,
    );
  }
}

class ErrorHandler {
  /// Handle error and show user-friendly message
  static Future<void> handleError(
    BuildContext context,
    dynamic error, {
    VoidCallback? onRetry,
    bool showDialog = true,
  }) async {
    final appError = error is AppError ? error : AppError.fromException(error);

    if (showDialog && context.mounted) {
      await mostrarAlerta(
        context,
        _getErrorTitle(appError.type),
        appError.message,
      );
      // Note: onRetry callback can be handled by the caller if needed
    }

    // Log error for debugging
    print('ErrorHandler: ${appError.type} - ${appError.message}');
    if (appError.originalError != null) {
      print('ErrorHandler: Original error: ${appError.originalError}');
    }
  }

  static String _getErrorTitle(ErrorType type) {
    switch (type) {
      case ErrorType.network:
        return 'Connection Error';
      case ErrorType.authentication:
        return 'Authentication Error';
      case ErrorType.server:
        return 'Server Error';
      case ErrorType.validation:
        return 'Validation Error';
      case ErrorType.unknown:
        return 'Error';
    }
  }

  /// Retry logic for network operations
  static Future<T?> retryOperation<T>(
    Future<T> Function() operation, {
    int maxRetries = 3,
    Duration delay = const Duration(seconds: 2),
  }) async {
    int attempts = 0;
    while (attempts < maxRetries) {
      try {
        return await operation();
      } catch (e) {
        attempts++;
        if (attempts >= maxRetries) {
          rethrow;
        }
        await Future.delayed(delay);
      }
    }
    return null;
  }

  /// Check if error is recoverable
  static bool isRecoverable(AppError error) {
    return error.type == ErrorType.network ||
        (error.statusCode != null &&
            error.statusCode! >= 500 &&
            error.statusCode! < 600);
  }
}
