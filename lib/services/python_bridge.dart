import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:serious_python/serious_python.dart';

class PythonBridge {
  static const String _host = "http://127.0.0.1:50050";

  static Future<void> initializeEngine() async {
    SeriousPython.run("app/app.zip", environmentVariables: {
      "PYTHONUNBUFFERED": "1",
    });
  }

  static Future<bool> isReady() async {
    try {
      final res = await http.get(Uri.parse('$_host/health')).timeout(
        const Duration(milliseconds: 700),
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> execute(String endpoint, Map<String, dynamic> payload) async {
    try {
      final response = await http.post(
        Uri.parse('$_host$endpoint'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data["output"] as String? ?? response.body;
      }
    } catch (_) {}
    return null;
  }
}
