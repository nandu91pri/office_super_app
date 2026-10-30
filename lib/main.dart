import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

void main() => runApp(const MaterialApp(home: OfficeSuperAppHome()));

class OfficeSuperAppHome extends StatefulWidget {
  const OfficeSuperAppHome({super.key});

  @override
  State<OfficeSuperAppHome> createState() => _OfficeSuperAppHomeState();
}

class _OfficeSuperAppHomeState extends State<OfficeSuperAppHome> {
  String _status = "Select an operation to begin";
  final String _serverBase = "http://10.0.2.2:8000"; // Android emulator localhost

  Future<void> _convertFile(String endpoint, String outputExt) async {
    FilePickerResult? picked = await FilePicker.platform.pickFiles();
    if (picked == null || picked.files.single.path == null) return;

    setState(() => _status = "Processing file...");
    File inputFile = File(picked.files.single.path!);

    var request = http.MultipartRequest('POST', Uri.parse('$_serverBase$endpoint'));
    request.files.add(await http.MultipartFile.fromPath('file', inputFile.path));

    var streamedResponse = await request.send();
    if (streamedResponse.statusCode == 200) {
      final bytes = await streamedResponse.stream.toBytes();
      final dir = await getApplicationDocumentsDirectory();
      final outputFile = File('${dir.path}/converted_output.$outputExt');
      await outputFile.writeAsBytes(bytes);
      setState(() => _status = "Completed! Saved to: ${outputFile.path}");
    } else {
      setState(() => _status = "Failed with error: ${streamedResponse.statusCode}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Office SuperApp Hub')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(_status, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _convertFile('/convert/sheet-to-html', 'html'),
              child: const Text('Convert Sheet to HTML'),
            ),
            ElevatedButton(
              onPressed: () => _convertFile('/convert/office-to-pdf', 'pdf'),
              child: const Text('Convert Office (Docx/Xlsx/Pptx) to PDF'),
            ),
            ElevatedButton(
              onPressed: () => _convertFile('/convert/pdf-to-docx', 'docx'),
              child: const Text('Convert PDF to DOCX'),
            ),
            ElevatedButton(
              onPressed: () => _convertFile('/convert/pdf-to-csv', 'csv'),
              child: const Text('Extract PDF Tables to CSV'),
            ),
          ],
        ),
      ),
    );
  }
}
