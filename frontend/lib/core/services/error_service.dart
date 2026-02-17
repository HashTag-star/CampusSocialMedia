import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

// Global key for showing SnackBars without context
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

final errorServiceProvider = Provider<ErrorService>((ref) {
  return ErrorService();
});

class ErrorService {
  void showError(String message) {
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            scaffoldMessengerKey.currentState?.hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  void handleDioError(DioException e) {
    String message = 'An unexpected error occurred.';
    
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        message = 'Connection timed out. Please check your internet.';
        break;
      case DioExceptionType.badResponse:
        final data = e.response?.data;
        if (data is Map && data['message'] != null) {
          message = data['message'];
        } else if (e.response?.statusCode == 401) {
             message = 'Session expired. Please expecting re-login.';
        } else if (e.response?.statusCode == 500) {
          message = 'Server error. Please try again later.';
        } else {
             message = 'Received invalid status code: ${e.response?.statusCode}';
        }
        break;
      case DioExceptionType.cancel:
        message = 'Request cancelled.';
        break;
      case DioExceptionType.connectionError:
          message = 'No internet connection.';
          break;
      default:
        message = 'Network error: ${e.message}';
    }

    showError(message);
  }
}
