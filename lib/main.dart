import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart' as xl;
import 'package:flutter_quill/flutter_quill.dart' hide Text;
import 'package:vsc_quill_delta_to_html/vsc_quill_delta_to_html.dart';
import 'package:path_provider/path_provider.dart';

import 'services/file_service.dart';
import 'services/python_bridge.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: OfficeSuperAppHome(),
  ));
}

class OfficeSuperAppHome extends StatefulWidget {
  const OfficeSuperAppHome({super.key});

  @override
  State<OfficeSuperAppHome> createState() => _OfficeSuperAppHomeState();
}

class _OfficeSuperAppHomeState extends State<OfficeSuperAppHome> {
  bool _ready = false;
  String _statusMessage = "Starting local Python engine...";

  @override
  void initState() {
    super.initState();
    _bootPython();
  }

  Future<void> _bootPython() async {
    await PythonBridge.initializeEngine();
    for (int i = 0; i < 30; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (await PythonBridge.isReady()) {
        setState(() {
          _ready = true;
          _statusMessage = "Offline Engine Ready (Android & Windows)";
        });
        return;
      }
    }
    setState(() => _statusMessage = "Engine startup timed out.");
  }

  Future<void> _runAction({
    required String title,
    required List<String> extensions,
    required String targetExt,
    required String endpoint,
    bool multiple = false,
  }) async {
    if (!_ready) return;

    List<File> files = [];
    if (multiple) {
      files = await FileService.pickMultipleFiles(extensions);
      if (files.length < 2) {
        setState(() => _statusMessage = "Select at least 2 files.");
        return;
      }
    } else {
      File? single = await FileService.pickSingleFile(extensions);
      if (single == null) return;
      files.add(single);
    }

    setState(() => _statusMessage = "Executing: $title...");
    final outPath = await FileService.generateOutputPath(targetExt);

    Map<String, dynamic> payload = multiple
        ? {"file_paths": files.map((f) => f.path).toList(), "output_path": outPath}
        : {"input_path": files.first.path, "output_path": outPath};

    final result = await PythonBridge.execute(endpoint, payload);

    if (result != null) {
      setState(() => _statusMessage = "Done!\nSaved to: $result");
    } else {
      setState(() => _statusMessage = "Task failed. Check document format.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Office SuperApp'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _ready ? Colors.green.shade50 : Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _ready ? Colors.green : Colors.amber),
            ),
            child: Text(
              _statusMessage,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 16),
          const Text("IN-APP EDITORS & VIEWERS",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),
          _buildActionCard(
            title: "PDF Viewer & Ink Annotator",
            subtitle: "View local PDFs, draw annotations, and save to storage",
            icon: Icons.edit_document,
            btnLabel: "Open PDF",
            color: Colors.deepPurple,
            onPressed: () async {
              final file = await FileService.pickSingleFile(['pdf']);
              if (file != null && mounted) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => InAppPdfViewer(file: file)));
              }
            },
          ),
          _buildActionCard(
            title: "Spreadsheet Editor",
            subtitle: "Edit rows and columns of .csv and .xlsx files directly",
            icon: Icons.table_chart_outlined,
            btnLabel: "Open Sheet",
            color: Colors.teal,
            onPressed: () async {
              final file = await FileService.pickSingleFile(['xlsx', 'xls', 'csv']);
              if (file != null && mounted) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => InAppSheetEditor(file: file)));
              }
            },
          ),
          _buildActionCard(
            title: "Document Editor (.docx / .txt)",
            subtitle: "Rich text editing with bold, headers, lists, and docx export",
            icon: Icons.edit_note,
            btnLabel: "Open Doc",
            color: Colors.blueGrey,
            onPressed: () async {
              final file = await FileService.pickSingleFile(['docx', 'txt']);
              if (mounted) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => InAppDocumentEditor(initialFile: file)));
              }
            },
          ),
          _buildActionCard(
            title: "Presentation Deck Editor",
            subtitle: "16:9 canvas with draggable text boxes and PPTX export",
            icon: Icons.slideshow,
            btnLabel: "Open Deck",
            color: Colors.deepOrange,
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const InAppSlideEditor()));
            },
          ),
          const SizedBox(height: 16),
          const Text("CONVERSION & PROCESSING TOOLS",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),
          _buildActionCard(
            title: "Sheet to Quiz HTML",
            subtitle: "Converts sheets to <div class='question'> / <div class='option'> markup",
            icon: Icons.quiz,
            btnLabel: "Convert",
            onPressed: () => _runAction(
              title: "Sheet to HTML",
              extensions: ['xlsx', 'xls', 'csv'],
              targetExt: 'html',
              endpoint: '/convert/sheet-to-html',
            ),
          ),
          _buildActionCard(
            title: "PDF Reorder & Merge Tool",
            subtitle: "Select multiple PDFs, drag to reorder, and merge into one",
            icon: Icons.merge_type,
            btnLabel: "Merge Tool",
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const InAppPdfMergeScreen()));
            },
          ),
          _buildActionCard(
            title: "Photos to PDF",
            subtitle: "Convert picked gallery/system photos to a compiled PDF",
            icon: Icons.image,
            btnLabel: "Compile",
            onPressed: () => _runAction(
              title: "Images to PDF",
              extensions: ['png', 'jpg', 'jpeg'],
              targetExt: 'pdf',
              endpoint: '/pdf/images-to-pdf',
              multiple: true,
            ),
          ),
          _buildActionCard(
            title: "PDF to DOCX Converter",
            subtitle: "Parses layout and extracts editable Word documents",
            icon: Icons.description,
            btnLabel: "Convert",
            onPressed: () => _runAction(
              title: "PDF to DOCX",
              extensions: ['pdf'],
              targetExt: 'docx',
              endpoint: '/convert/pdf-to-docx',
            ),
          ),
          _buildActionCard(
            title: "PDF Tables to CSV",
            subtitle: "Extracts table data from PDF into structured CSV files",
            icon: Icons.grid_on,
            btnLabel: "Extract",
            onPressed: () => _runAction(
              title: "PDF to CSV",
              extensions: ['pdf'],
              targetExt: 'csv',
              endpoint: '/convert/pdf-to-csv',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback? onPressed,
    String btnLabel = "Select",
    Color color = Colors.indigo,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white),
          onPressed: onPressed,
          child: Text(btnLabel),
        ),
      ),
    );
  }
}

// ==================== IN-APP SUB-SCREENS ====================

// 1. PDF Viewer & Annotator
class InAppPdfViewer extends StatefulWidget {
  final File file;
  const InAppPdfViewer({super.key, required this.file});

  @override
  State<InAppPdfViewer> createState() => _InAppPdfViewerState();
}

class _InAppPdfViewerState extends State<InAppPdfViewer> {
  late PdfViewerController _controller;
  bool _isDrawing = false;

  @override
  void initState() {
    super.initState();
    _controller = PdfViewerController();
  }

  Future<void> _save() async {
    final bytes = await _controller.saveDocument();
    final out = await FileService.generateOutputPath("pdf");
    await File(out).writeAsBytes(bytes, flush: true);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved: $out')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.file.path.split(Platform.pathSeparator).last),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.draw, color: _isDrawing ? Colors.amberAccent : Colors.white),
            onPressed: () {
              setState(() {
                _isDrawing = !_isDrawing;
                _controller.annotationMode = _isDrawing ? PdfAnnotationMode.highlight : PdfAnnotationMode.none;
              });
            },
          ),
          IconButton(icon: const Icon(Icons.save), onPressed: _save),
        ],
      ),
      body: SfPdfViewer.file(widget.file, controller: _controller, enableTextSelection: true),
    );
  }
}

// 2. Spreadsheet Editor
class InAppSheetEditor extends StatefulWidget {
  final File file;
  const InAppSheetEditor({super.key, required this.file});

  @override
  State<InAppSheetEditor> createState() => _InAppSheetEditorState();
}

class _InAppSheetEditorState extends State<InAppSheetEditor> {
  List<String> _headers = [];
  List<List<dynamic>> _rows = [];
  bool _loading = true;
  _SheetSource? _source;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      if (widget.file.path.endsWith('.csv')) {
        final content = await widget.file.readAsString();
        final list = const CsvToListConverter().convert(content);
        if (list.isNotEmpty) {
          _headers = List<String>.from(list.first.map((e) => e.toString()));
          _rows = list.skip(1).toList();
        }
      } else {
        final bytes = await widget.file.readAsBytes();
        final excel = xl.Excel.decodeBytes(bytes);
        final sheet = excel.tables[excel.tables.keys.first];
        if (sheet != null && sheet.rows.isNotEmpty) {
          _headers = sheet.rows.first.map((c) => c?.value?.toString() ?? "").toList();
          _rows = sheet.rows.skip(1).map((r) => r.map((c) => c?.value?.toString() ?? "").toList()).toList();
        }
      }
      if (_headers.isEmpty) { _headers = ["Col A", "Col B"]; _rows = [["", ""]]; }
      _source = _SheetSource(_headers, _rows);
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    final isCsv = widget.file.path.endsWith('.csv');
    final out = await FileService.generateOutputPath(isCsv ? 'csv' : 'xlsx');
    final all = [_headers, ..._rows];

    if (isCsv) {
      await File(out).writeAsString(const ListToCsvConverter().convert(all));
    } else {
      final excel = xl.Excel.createExcel();
      final sheet = excel[excel.getDefaultSheet() ?? 'Sheet1'];
      for (int r = 0; r < all.length; r++) {
        for (int c = 0; c < all[r].length; c++) {
          sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r)).value =
              xl.TextCellValue(all[r][c]?.toString() ?? "");
        }
      }
      final bytes = excel.encode();
      if (bytes != null) await File(out).writeAsBytes(bytes);
    }
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved: $out')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.file.path.split(Platform.pathSeparator).last),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () {
              setState(() {
                _rows.add(List.filled(_headers.length, ""));
                _source?.buildRows();
              });
            },
          ),
          IconButton(icon: const Icon(Icons.save), onPressed: _save),
        ],
      ),
      body: _loading || _source == null
          ? const Center(child: CircularProgressIndicator())
          : SfDataGrid(
              source: _source!,
              allowEditing: true,
              navigationMode: GridNavigationMode.cell,
              selectionMode: SelectionMode.single,
              columns: _headers.asMap().entries.map((e) => GridColumn(
                columnName: 'col_${e.key}',
                label: Container(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.all(8),
                  child: Text(e.value, style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              )).toList(),
            ),
    );
  }
}

class _SheetSource extends DataGridSource {
  final List<String> headers;
  final List<List<dynamic>> sheetRows;
  List<DataGridRow> _gridRows = [];
  dynamic newVal;

  _SheetSource(this.headers, this.sheetRows) { buildRows(); }

  void buildRows() {
    _gridRows = sheetRows.map((r) => DataGridRow(
      cells: List.generate(headers.length, (i) => DataGridCell(columnName: 'col_$i', value: i < r.length ? r[i].toString() : '')),
    )).toList();
    notifyListeners();
  }

  @override
  List<DataGridRow> get rows => _gridRows;

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    return DataGridRowAdapter(
      cells: row.getCells().map((c) => Container(alignment: Alignment.centerLeft, padding: const EdgeInsets.all(8), child: Text(c.value.toString()))).toList(),
    );
  }

  @override
  Future<void> onCellSubmit(DataGridRow row, RowColumnIndex rIndex, GridColumn col) async {
    final int rowIdx = _gridRows.indexOf(row);
    final int colIdx = int.parse(col.columnName.replaceFirst('col_', ''));
    if (newVal != null) { sheetRows[rowIdx][colIdx] = newVal; buildRows(); }
  }

  @override
  Widget? buildEditWidget(DataGridRow row, RowColumnIndex rIndex, GridColumn col, CellSubmit submit) {
    final val = row.getCells().firstWhere((c) => c.columnName == col.columnName).value.toString();
    newVal = val;
    return TextField(
      controller: TextEditingController(text: val),
      onChanged: (v) => newVal = v,
      onSubmitted: (_) => submit(),
    );
  }
}

// 3. Document Editor (.docx / .txt)
class InAppDocumentEditor extends StatefulWidget {
  final File? initialFile;
  const InAppDocumentEditor({super.key, this.initialFile});

  @override
  State<InAppDocumentEditor> createState() => _InAppDocumentEditorState();
}

class _InAppDocumentEditorState extends State<InAppDocumentEditor> {
  late QuillController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = QuillController.basic();
    _load();
  }

  Future<void> _load() async {
    if (widget.initialFile == null) { setState(() => _loading = false); return; }
    try {
      final path = widget.initialFile!.path;
      if (path.endsWith('.txt')) {
        _controller.document.insert(0, await widget.initialFile!.readAsString());
      } else if (path.endsWith('.docx')) {
        final res = await PythonBridge.execute('/doc/read-docx', {"input_path": path});
        if (res != null) {
          _controller.document.insert(0, jsonDecode(res)["text"] ?? "");
        }
      }
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _export(String ext) async {
    final out = await FileService.generateOutputPath(ext);
    if (ext == "txt") {
      await File(out).writeAsString(_controller.document.toPlainText());
    } else {
      final html = QuillDeltaToHtmlConverter(
        List<Map<String, dynamic>>.from(
          _controller.document.toDelta().toJson(),
        ),
      ).convert();
      await PythonBridge.execute('/doc/html-to-docx', {"html": html, "output_path": out});
    }
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved: $out')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Document Editor"),
        backgroundColor: Colors.blueGrey,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.save_as),
            onPressed: () => showModalBottomSheet(
              context: context,
              builder: (ctx) => Wrap(
                children: [
                  ListTile(title: const Text("Export as .docx"), onTap: () { Navigator.pop(ctx); _export("docx"); }),
                  ListTile(title: const Text("Export as .txt"), onTap: () { Navigator.pop(ctx); _export("txt"); }),
                ],
              ),
            ),
          )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                QuillSimpleToolbar(controller: _controller, configurations: const QuillSimpleToolbarConfigurations()),
                const Divider(height: 1),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.white,
                    child: QuillEditor.basic(controller: _controller, configurations: const QuillEditorConfigurations()),
                  ),
                ),
              ],
            ),
    );
  }
}

// 4. Slide Deck Editor
class InAppSlideEditor extends StatefulWidget {
  const InAppSlideEditor({super.key});

  @override
  State<InAppSlideEditor> createState() => _InAppSlideEditorState();
}

class _InAppSlideEditorState extends State<InAppSlideEditor> {
  final List<Map<String, dynamic>> _slides = [
    {
      "elements": [
        {"text": "Presentation Title", "x": 0.15, "y": 0.25, "width": 0.7, "height": 0.2, "fontSize": 34.0, "color": "#1A237E"},
        {"text": "Double tap to edit • Drag to position", "x": 0.15, "y": 0.5, "width": 0.7, "height": 0.15, "fontSize": 18.0, "color": "#000000"},
      ]
    }
  ];
  int _idx = 0;

  Future<void> _export() async {
    final out = await FileService.generateOutputPath("pptx");
    final res = await PythonBridge.execute('/presentation/export-pptx', {
      "slides": _slides,
      "output_path": out,
    });
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res != null ? "Saved: $out" : "Export failed")));
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> elements =
        List<Map<String, dynamic>>.from(_slides[_idx]["elements"]);
    return Scaffold(
      appBar: AppBar(
        title: const Text("Presentation Deck Editor"),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_box),
            onPressed: () => setState(() => elements.add({
              "text": "New Text Box", "x": 0.2, "y": 0.3, "width": 0.5, "height": 0.15, "fontSize": 22.0, "color": "#000000"
            })),
          ),
          IconButton(icon: const Icon(Icons.download), onPressed: _export),
        ],
      ),
      body: Row(
        children: [
          Container(
            width: 120,
            color: Colors.grey.shade100,
            child: ListView(
              children: [
                ElevatedButton(
                  onPressed: () => setState(() => _slides.add({"elements": []})),
                  child: const Text("+ Slide"),
                ),
                ...List.generate(_slides.length, (i) => ListTile(
                  title: Text("Slide ${i + 1}"),
                  selected: _idx == i,
                  onTap: () => setState(() => _idx = i),
                ))
              ],
            ),
          ),
          Expanded(
            child: Container(
              color: Colors.grey.shade300,
              padding: const EdgeInsets.all(20),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: LayoutBuilder(
                  builder: (ctx, constraints) {
                    final w = constraints.maxWidth;
                    final h = constraints.maxHeight;
                    return Container(
                      color: Colors.white,
                      child: Stack(
                        children: elements.map((el) {
                          return Positioned(
                            left: el["x"] * w,
                            top: el["y"] * h,
                            child: GestureDetector(
                              onDoubleTap: () {
                                final c = TextEditingController(text: el["text"]);
                                showDialog(
                                  context: context,
                                  builder: (d) => AlertDialog(
                                    content: TextField(controller: c),
                                    actions: [
                                      TextButton(onPressed: () { setState(() => el["text"] = c.text); Navigator.pop(d); }, child: const Text("Save"))
                                    ],
                                  ),
                                );
                              },
                              onPanUpdate: (d) => setState(() {
                                el["x"] = (el["x"] * w + d.delta.dx).clamp(0.0, w - el["width"] * w) / w;
                                el["y"] = (el["y"] * h + d.delta.dy).clamp(0.0, h - el["height"] * h) / h;
                              }),
                              child: Container(
                                width: el["width"] * w,
                                height: el["height"] * h,
                                decoration: BoxDecoration(border: Border.all(color: Colors.deepOrangeAccent)),
                                child: Text(el["text"], style: TextStyle(fontSize: el["fontSize"])),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 5. PDF Merge Screen
class InAppPdfMergeScreen extends StatefulWidget {
  const InAppPdfMergeScreen({super.key});

  @override
  State<InAppPdfMergeScreen> createState() => _InAppPdfMergeScreenState();
}

class _InAppPdfMergeScreenState extends State<InAppPdfMergeScreen> {
  final List<File> _selectedFiles = [];
  bool _isProcessing = false;
  String? _status;

  Future<void> _pickFiles() async {
    final picked = await FileService.pickMultipleFiles(['pdf']);
    if (picked.isNotEmpty) {
      setState(() {
        for (var f in picked) {
          if (!_selectedFiles.any((e) => e.path == f.path)) _selectedFiles.add(f);
        }
      });
    }
  }

  Future<void> _merge() async {
    if (_selectedFiles.length < 2) return;
    setState(() { _isProcessing = true; _status = "Merging documents..."; });
    final out = await FileService.generateOutputPath('pdf');
    final res = await PythonBridge.execute('/pdf/merge', {
      "file_paths": _selectedFiles.map((f) => f.path).toList(),
      "output_path": out,
    });
    setState(() {
      _isProcessing = false;
      _status = res != null ? "Saved to: $out" : "Merge failed";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Merge PDFs'), backgroundColor: Colors.indigo, foregroundColor: Colors.white),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(child: Text("${_selectedFiles.length} files selected (drag handle to reorder)")),
                ElevatedButton.icon(onPressed: _isProcessing ? null : _pickFiles, icon: const Icon(Icons.add), label: const Text('Add PDFs')),
              ],
            ),
          ),
          if (_status != null) Container(width: double.infinity, padding: const EdgeInsets.all(8), color: Colors.indigo.shade50, child: Text(_status!, textAlign: TextAlign.center)),
          Expanded(
            child: ReorderableListView.builder(
              itemCount: _selectedFiles.length,
              onReorder: (oldIdx, newIdx) {
                setState(() {
                  if (oldIdx < newIdx) newIdx -= 1;
                  final item = _selectedFiles.removeAt(oldIdx);
                  _selectedFiles.insert(newIdx, item);
                });
              },
              itemBuilder: (ctx, i) => ListTile(
                key: ValueKey(_selectedFiles[i].path),
                leading: CircleAvatar(child: Text('${i + 1}')),
                title: Text(_selectedFiles[i].path.split(Platform.pathSeparator).last),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => setState(() => _selectedFiles.removeAt(i))),
                    const Icon(Icons.drag_handle),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _selectedFiles.length >= 2 && !_isProcessing ? _merge : null,
                  icon: const Icon(Icons.call_merge),
                  label: Text(_isProcessing ? 'Merging...' : 'Merge All'),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}
