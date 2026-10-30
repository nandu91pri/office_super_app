import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

class LocalFileService {
  /// Picks a document of specified extensions from device storage
  static Future<File?> pickDocument(List<String> allowedExtensions) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      return File(result.files.single.path!);
    }
    return null;
  }

  /// Picks multiple PDFs for merging
  static Future<List<File>> pickMultiplePdfs() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: true,
    );

    if (result != null) {
      return result.paths.where((p) => p != null).map((p) => File(p!)).toList();
    }
    return [];
  }

  /// Saves output file to user-accessible documents directory
  static Future<File> saveOutputFile(String filename, List<int> bytes) async {
    final Directory directory = await getApplicationDocumentsDirectory();
    final String outputPath = '${directory.path}/$filename';
    final File file = File(outputPath);
    return await file.writeAsBytes(bytes);
  }
}
