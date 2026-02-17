import 'dart:io';

class ApiConstants {
  static String get baseUrl {
    if (Platform.isAndroid) {
      return 'http://192.168.100.231:5000'; 
    }
    return 'http://localhost:5000';
  }

  static String get apiBaseUrl => '$baseUrl/api';
}
