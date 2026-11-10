import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart' as xl;
import 'package:flutter_quill/flutter_quill.dart';
import 'package:vsc_quill_delta_to_html/vsc_quill_delta_to_html.dart';

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
        if (!mounted) return;
        setState(() {
          _ready = true;
          _statusMessage = "Offline Engine Ready (Android & Windows)";
        });
        return;
      }
    }
    if (!mounted) return;
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
        if (!mounted) return;
        setState(() => _statusMessage = "Select at least 2 files.");
        return;
      }
    } else {
      File? single = await FileService.pickSingleFile(extensions);
      if (single == null) return;
      files.add(single);
    }

    if (!mounted) return;
    setState(() => _statusMessage = "Executing: $title...");
    final outPath = await FileService.generateOutputPath(targetExt);

    Map<String, dynamic> payload = multiple
        ? {"file_paths": files.map((f) => f.path).toList(), "output_path": outPath}
        : {"input_path": files.first.path, "output_path": outPath};

    final result = await PythonBridge.execute(endpoint, payload);

    if (!mounted) return;
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
        actions: [
          IconButton(
            tooltip: 'About & User Guide',
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const InAppAboutScreen()),
              );
            },
          ),
        ],
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
            title: "PDF Viewer & Highlighter",
            subtitle: "View local PDFs, highlight text, and save to storage",
            icon: Icons.edit_document,
            btnLabel: "Open PDF",
            color: Colors.deepPurple,
            onPressed: () async {
              final file = await FileService.pickSingleFile(['pdf']);
              if (file != null && context.mounted) {
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
              if (file != null && context.mounted) {
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
              if (context.mounted) {
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
          const SizedBox(height: 8),
          _buildActionCard(
            title: "About App & User Guide",
            subtitle: "App version, features, step-by-step guide, contact & copyright",
            icon: Icons.info_outline,
            btnLabel: "Open",
            color: Colors.blueGrey,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const InAppAboutScreen()),
              );
            },
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
          backgroundColor: color.withValues(alpha: 0.1),
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
  bool _isHighlight = false;

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
            icon: Icon(Icons.highlight, color: _isHighlight ? Colors.amberAccent : Colors.white),
            onPressed: () {
              setState(() {
                _isHighlight = !_isHighlight;
                _controller.annotationMode =
                    _isHighlight ? PdfAnnotationMode.highlight : PdfAnnotationMode.none;
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
      if (_headers.isEmpty) {
        _headers = ["Col A", "Col B"];
        _rows = [["", ""]];
      }
      _source = _SheetSource(_headers, _rows);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
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

  _SheetSource(this.headers, this.sheetRows) {
    buildRows();
  }

  void buildRows() {
    _gridRows = sheetRows.map((r) => DataGridRow(
      cells: List.generate(
        headers.length,
        (i) => DataGridCell(columnName: 'col_$i', value: i < r.length ? r[i].toString() : ''),
      ),
    )).toList();
    notifyListeners();
  }

  @override
  List<DataGridRow> get rows => _gridRows;

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    return DataGridRowAdapter(
      cells: row.getCells().map((c) => Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.all(8),
        child: Text(c.value.toString()),
      )).toList(),
    );
  }

  @override
  Future<void> onCellSubmit(DataGridRow row, RowColumnIndex rIndex, GridColumn col) async {
    final int rowIdx = _gridRows.indexOf(row);
    final int colIdx = int.parse(col.columnName.replaceFirst('col_', ''));
    if (newVal != null) {
      sheetRows[rowIdx][colIdx] = newVal;
      buildRows();
    }
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
    if (widget.initialFile == null) {
      setState(() => _loading = false);
      return;
    }
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
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _export(String ext) async {
    final out = await FileService.generateOutputPath(ext);
    if (ext == "txt") {
      await File(out).writeAsString(_controller.document.toPlainText());
    } else {
      final html = QuillDeltaToHtmlConverter(
        List<Map<String, dynamic>>.from(_controller.document.toDelta().toJson()),
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
                  ListTile(
                    title: const Text("Export as .docx"),
                    onTap: () {
                      Navigator.pop(ctx);
                      _export("docx");
                    },
                  ),
                  ListTile(
                    title: const Text("Export as .txt"),
                    onTap: () {
                      Navigator.pop(ctx);
                      _export("txt");
                    },
                  ),
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
                QuillSimpleToolbar(
                  controller: _controller,
                  
                ),
                const Divider(height: 1),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.white,
                    child: QuillEditor.basic(
                      controller: _controller,
                      
                      
                    ),
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
        {"text": "Double tap to edit â€¢ Drag to position", "x": 0.15, "y": 0.5, "width": 0.7, "height": 0.15, "fontSize": 18.0, "color": "#000000"},
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
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res != null ? "Saved: $out" : "Export failed")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final List elements = _slides[_idx]["elements"];
    return Scaffold(
      appBar: AppBar(
        title: const Text("Presentation Deck Editor"),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_box),
            onPressed: () => setState(() => elements.add({
              "text": "New Text Box",
              "x": 0.2,
              "y": 0.3,
              "width": 0.5,
              "height": 0.15,
              "fontSize": 22.0,
              "color": "#000000"
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
                                      TextButton(
                                        onPressed: () {
                                          setState(() => el["text"] = c.text);
                                          Navigator.pop(d);
                                        },
                                        child: const Text("Save"),
                                      )
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
    setState(() {
      _isProcessing = true;
      _status = "Merging documents...";
    });
    final out = await FileService.generateOutputPath('pdf');
    final res = await PythonBridge.execute('/pdf/merge', {
      "file_paths": _selectedFiles.map((f) => f.path).toList(),
      "output_path": out,
    });
    if (!mounted) return;
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
                ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _pickFiles,
                  icon: const Icon(Icons.add),
                  label: const Text('Add PDFs'),
                ),
              ],
            ),
          ),
          if (_status != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              color: Colors.indigo.shade50,
              child: Text(_status!, textAlign: TextAlign.center),
            ),
          Expanded(
            child: ReorderableListView.builder(
              itemCount: _selectedFiles.length,
              onReorderItem: (oldIdx, newIdx) {
                setState(() {
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
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => setState(() => _selectedFiles.removeAt(i)),
                    ),
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

// 6. About App & User Guide Screen
class InAppAboutScreen extends StatelessWidget {
  const InAppAboutScreen({super.key});

  void _copyEmail(BuildContext context) {
    Clipboard.setData(const ClipboardData(text: 'nandani871991@gmail.com'));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Email copied: nandani871991@gmail.com'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About & User Guide'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Card(
            elevation: 2,
            color: Colors.indigo.shade50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 34,
                    backgroundColor: Colors.indigo,
                    child: Icon(
                      Icons.workspaces_filled,
                      size: 36,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Offline Office SuperApp',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Version 1.0.0',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.indigo.shade900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'An all-in-one offline workspace to view, edit, and convert PDFs, Spreadsheets, Documents, and Presentations on Android and Windows.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13.5, color: Colors.black87),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'FEATURES OF THIS APP',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.indigo,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 1.5,
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                children: [
                  _buildFeatureRow(
                    Icons.picture_as_pdf,
                    Colors.deepPurple,
                    'PDF Viewer & Highlighter',
                    'Open any PDF from your device, highlight important text, and save a new copy.',
                  ),
                  const Divider(height: 18),
                  _buildFeatureRow(
                    Icons.merge_type,
                    Colors.indigo,
                    'PDF Merger',
                    'Select two or more PDFs, drag them into your preferred order, and combine them into one file.',
                  ),
                  const Divider(height: 18),
                  _buildFeatureRow(
                    Icons.image,
                    Colors.blue,
                    'Photos to PDF',
                    'Pick images (JPG or PNG) from your phone or computer and turn them into a single PDF.',
                  ),
                  const Divider(height: 18),
                  _buildFeatureRow(
                    Icons.transform,
                    Colors.indigo.shade700,
                    'PDF to Word & CSV Converter',
                    'Turn PDFs into editable Word (.docx) documents, or pull tables out of PDFs into CSV files.',
                  ),
                  const Divider(height: 18),
                  _buildFeatureRow(
                    Icons.table_chart,
                    Colors.teal,
                    'Spreadsheet Editor (.xlsx / .csv)',
                    'Open Excel or CSV sheets, edit values directly, add new rows, and save your updates.',
                  ),
                  const Divider(height: 18),
                  _buildFeatureRow(
                    Icons.quiz,
                    Colors.green.shade700,
                    'Sheet to Quiz HTML Converter',
                    'Automatically turn Excel or CSV question sheets into ready-to-use Quiz HTML code.',
                  ),
                  const Divider(height: 18),
                  _buildFeatureRow(
                    Icons.edit_note,
                    Colors.blueGrey,
                    'Document Editor (.docx / .txt)',
                    'Write or edit text and Word documents with bold styling, headings, lists, and easy export.',
                  ),
                  const Divider(height: 18),
                  _buildFeatureRow(
                    Icons.slideshow,
                    Colors.deepOrange,
                    'Presentation Deck Editor (.pptx)',
                    'Create slides, double-tap to edit text, drag text boxes anywhere, and save as a PowerPoint (.pptx) file.',
                  ),
                  const Divider(height: 18),
                  _buildFeatureRow(
                    Icons.wifi_off,
                    Colors.green,
                    'Works 100% Offline',
                    'All tools run directly on your deviceâ€”no internet connection is needed.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'HOW TO USE (SIMPLE GUIDE)',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.indigo,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 1.5,
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStepRow(
                    '1',
                    'Wait for the Green Status Box',
                    'After opening the app, wait a few seconds until the top box turns green and says "Offline Engine Ready".',
                  ),
                  const SizedBox(height: 12),
                  _buildStepRow(
                    '2',
                    'Pick a Tool',
                    'Scroll through the home screen and tap the button next to the task you want (such as Open PDF, Open Sheet, Merge Tool, or Convert).',
                  ),
                  const SizedBox(height: 12),
                  _buildStepRow(
                    '3',
                    'Select Your File(s)',
                    'Choose the file you want to work on from your phone or computer storage.',
                  ),
                  const SizedBox(height: 12),
                  _buildStepRow(
                    '4',
                    'Edit or Convert & Save',
                    'Inside any editor, make your changes and tap the Save icon at the top right. Converters process your file automatically.',
                  ),
                  const SizedBox(height: 12),
                  _buildStepRow(
                    '5',
                    'Find Your Saved File',
                    'When the job finishes, an on-screen message will show the exact folder path on your device where your new file is saved.',
                  ),
                  const Divider(height: 22),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.lightbulb_outline, color: Colors.amber, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Tip for Quiz HTML Converter: Keep columns in your Excel or CSV file for Question Number, Question, Option A, Option B, Option C, Option D, Correct Option (A/B/C/D), and Explanation.',
                            style: TextStyle(fontSize: 12.5, color: Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'OWNER & CONTACT DETAILS',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.indigo,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 1.5,
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.person, color: Colors.indigo),
                  title: Text('App Owner', style: TextStyle(fontSize: 13, color: Colors.grey)),
                  subtitle: Text(
                    'Nandani Kumari',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.email, color: Colors.indigo),
                  title: const Text('Email ID', style: TextStyle(fontSize: 13, color: Colors.grey)),
                  subtitle: const SelectableText(
                    'nandani871991@gmail.com',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.indigo,
                    ),
                  ),
                  trailing: IconButton(
                    tooltip: 'Copy Email',
                    icon: const Icon(Icons.copy, size: 20),
                    onPressed: () => _copyEmail(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: const Column(
              children: [
                Icon(Icons.copyright, color: Colors.black54, size: 22),
                SizedBox(height: 6),
                Text(
                  'Â© 2026 Nandani Kumari. All Rights Reserved.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Offline Office SuperApp is owned and copyrighted by Nandani Kumari. Unauthorized copying or commercial redistribution without permission is prohibited.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, Color color, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: Colors.grey.shade100,
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 2),
              Text(desc, style: const TextStyle(fontSize: 13, color: Colors.black87)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepRow(String stepNum, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 13,
          backgroundColor: Colors.indigo,
          child: Text(
            stepNum,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 2),
              Text(desc, style: const TextStyle(fontSize: 13, color: Colors.black87)),
            ],
          ),
        ),
      ],
    );
  }
}



