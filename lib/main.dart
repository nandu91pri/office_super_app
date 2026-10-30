import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:serious_python/serious_python.dart';
import 'package:path_provider/path_provider.dart';
import 'file_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(home: SuperApp()));
}

class SuperApp extends StatefulWidget {
  const SuperApp({super.key});

  @override
  State<SuperApp> createState() => _SuperAppState();
}

class _SuperAppState extends State<SuperApp> {
  bool _isPythonReady = false;
  String _status = "Booting offline engine...";

  @override
  void initState() {
    super.initState();
    _startOfflinePythonServer();
  }

  Future<void> _startOfflinePythonServer() async {
    // SeriousPython starts your bundled Python scripts in an internal background thread
    SeriousPython.run("app/app.zip", environmentVariables: {
      "PYTHONUNBUFFERED": "1",
    });

    // Ping the loopback address until the engine is up
    for (int i = 0; i < 20; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
      try {
        final res = await http.get(Uri.parse('http://127.0.0.1:50050/health'));
        if (res.statusCode == 200) {
          setState(() {
            _isPythonReady = true;
            _status = "Offline Engine Ready (Android/Windows)";
          });
          break;
        }
      } catch (_) {}
    }
  }

  Future<void> _handleMergePdfs() async {
    List<File> files = await LocalFileService.pickMultiplePdfs();
    if (files.length < 2) {
      setState(() => _status = "Select at least 2 PDF files to merge.");
      return;
    }

    final docsDir = await getApplicationDocumentsDirectory();
    final outputPath = "${docsDir.path}/merged_${DateTime.now().millisecondsSinceEpoch}.pdf";

    setState(() => _status = "Merging PDFs locally...");

    final response = await http.post(
      Uri.parse('http://127.0.0.1:50050/merge_pdfs'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "file_paths": files.map((f) => f.path).toList(),
        "output_path": outputPath,
      }),
    );

    if (response.statusCode == 200) {
      setState(() => _status = "Merged file saved: $outputPath");
    } else {
      setState(() => _status = "Failed to merge.");
    }
  }

  Future<void> _handleSheetToHtml() async {
    File? sheet = await LocalFileService.pickDocument(['xlsx', 'xls', 'csv']);
    if (sheet == null) return;

    setState(() => _status = "Converting sheet to HTML...");

    final response = await http.post(
      Uri.parse('http://127.0.0.1:50050/sheet_to_html'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({"input_path": sheet.path}),
    );

    if (response.statusCode == 200) {
      final html = jsonDecode(response.body)["html"];
      final outputFile = await LocalFileService.saveOutputFile(
        "converted_${DateTime.now().millisecondsSinceEpoch}.html",
        utf8.encode(html),
      );
      setState(() => _status = "Exported HTML to: ${outputFile.path}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Offline Office SuperApp')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              color: _isPythonReady ? Colors.green.shade50 : Colors.orange.shade50,
              child: Text(_status, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _isPythonReady ? _handleMergePdfs : null,
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Pick & Merge Local PDFs'),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _isPythonReady ? _handleSheetToHtml : null,
              icon: const Icon(Icons.table_chart),
              label: const Text('Pick Sheet -> Convert to HTML'),
            ),
          ],
        ),
      ),
    );
  }
}
