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
        final statusCode = e.response?.statusCode;
        final data = e.response?.data;
        
        if (data is Map && data['message'] != null) {
          // Use backend message if available, but sanitize it if it looks technical?
          // For now, let's assume backend sends readable messages for 400s
          message = data['message'];
        } else if (statusCode == 400) {
          message = 'Something wasn\'t right with that request.';
        } else if (statusCode == 401) {
          message = 'Session expired. Please sign in again.';
        } else if (statusCode == 403) {
          message = 'You don\'t have permission to do that.';
        } else if (statusCode == 404) {
          message = 'We couldn\'t find what you were looking for.';
        } else if (statusCode != null && statusCode >= 500) {
          message = 'Our servers are having a moment. Please try again later.';
        } else {
             message = 'Something went wrong ($statusCode).';
        }
        break;
      case DioExceptionType.cancel:
        message = 'Request cancelled.';
        break;
      case DioExceptionType.connectionError:
          message = 'No internet connection. Please check your settings.';
          break;
      default:
        message = 'Something went wrong. Please try again.';
    }

    showError(message);
  }
}
