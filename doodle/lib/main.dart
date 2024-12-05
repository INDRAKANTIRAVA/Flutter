import 'package:flutter/material.dart' show AlertDialog, AppBar, BuildContext, Canvas, Color, Colors, Column, Container, CustomPaint, CustomPainter, Expanded, GestureDetector, Icon, IconButton, Icons, MainAxisAlignment, MaterialApp, Navigator, Offset, Paint, Path, Rect, Row, Scaffold, ScaffoldMessenger, Size, Slider, SnackBar, State, StatefulWidget, StatelessWidget, StrokeCap, Text, TextButton, ThemeData, Widget, runApp, showDialog;
import 'dart:ui'; // For Canvas and Size
import 'package:flutter/rendering.dart'; // For RenderRepaintBoundary
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

void main() {
  runApp(DoodleApp());
}

class DoodleApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Doodle Drawing App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: DrawingPage(),
    );
  }
}

class DrawingPage extends StatefulWidget {
  @override
  _DrawingPageState createState() => _DrawingPageState();
}

class _DrawingPageState extends State<DrawingPage> {
  // Tracks the paths and redo paths
  final List<List<Offset?>> _paths = [];
  final List<List<Offset?>> _redoPaths = [];

  // Drawing settings
  Color _currentColor = Colors.black;
  double _brushSize = 5.0;
  bool _isErasing = false; // Track whether the eraser is active

  // Canvas key for saving drawings
  final GlobalKey _canvasKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Drawing App'),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo),
            onPressed: _paths.isNotEmpty ? _undo : null,
          ),
          IconButton(
            icon: const Icon(Icons.redo),
            onPressed: _redoPaths.isNotEmpty ? _redo : null,
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _clearCanvas,
          ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveDrawing,
          ),
          IconButton(
            icon: Icon(_isErasing ? Icons.delete_forever : Icons.create),
            onPressed: _toggleEraser, // Toggle eraser on/off
          ),
        ],
      ),
      body: Column(
        children: [
          // Canvas area
          Expanded(
            child: GestureDetector(
              onPanStart: (details) => _startDrawing(details.localPosition),
              onPanUpdate: (details) => _updateDrawing(details.localPosition),
              onPanEnd: (_) => _endDrawing(),
              child: RepaintBoundary(
                key: _canvasKey,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return CustomPaint(
                      size: constraints.biggest,
                      painter: DrawingPainter(_paths, _currentColor, _brushSize, _isErasing),
                    );
                  },
                ),
              ),
            ),
          ),
          // Controls
          _buildControls(),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      color: Colors.grey[200],
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          IconButton(
            icon: const Icon(Icons.brush),
            onPressed: _selectBrushSize,
          ),
          IconButton(
            icon: const Icon(Icons.color_lens),
            onPressed: _selectColor,
          ),
        ],
      ),
    );
  }

  // Start a new path
  void _startDrawing(Offset position) {
    setState(() {
      if (_isErasing) {
        _paths.add([position]); // Start erasing path
      } else {
        _paths.add([position]); // Start drawing path
      }
    });
  }

  // Update the current path
  void _updateDrawing(Offset position) {
    setState(() {
      if (_isErasing) {
        // Erase by checking if the position is within the eraser radius
        _paths.last.add(position);
      } else {
        _paths.last.add(position); // Continue drawing
      }
    });
  }

  // End the current drawing gesture
  void _endDrawing() {
    _redoPaths.clear(); // Clear redo paths after new drawing
  }

  // Undo the last action
  void _undo() {
    setState(() {
      _redoPaths.add(_paths.removeLast());
    });
  }

  // Redo the last undone action
  void _redo() {
    setState(() {
      _paths.add(_redoPaths.removeLast());
    });
  }

  // Clear the canvas
  void _clearCanvas() {
    setState(() {
      _paths.clear();
      _redoPaths.clear();
    });
  }

  // Save the drawing to the gallery
  Future<void> _saveDrawing() async {
    try {
      final boundary = _canvasKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ImageByteFormat.png);
      final buffer = byteData!.buffer.asUint8List();

      final directory = (await getApplicationDocumentsDirectory()).path;
      final file = File('$directory/drawing_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(buffer);

      // Save to gallery
      final success = await GallerySaver.saveImage(file.path, albumName: 'DoodleApp');
      if (success == true) {
        _showSnackbar('Drawing saved to gallery!');
      } else {
        _showSnackbar('Failed to save drawing.');
      }
    } catch (e) {
      _showSnackbar('Error saving drawing: $e');
    }
  }

  // Display a snackbar message
  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // Select the brush color
  void _selectColor() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select Color'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: _currentColor,
              onColorChanged: (color) => setState(() {
                _currentColor = color;
              }),
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Done'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  // Select the brush size
  void _selectBrushSize() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select Brush Size'),
          content: Slider(
            value: _brushSize,
            min: 1.0,
            max: 20.0,
            divisions: 19,
            label: _brushSize.round().toString(),
            onChanged: (value) => setState(() {
              _brushSize = value;
            }),
          ),
          actions: [
            TextButton(
              child: const Text('Done'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  // Toggle eraser mode
  void _toggleEraser() {
    setState(() {
      _isErasing = !_isErasing;
      _currentColor = _isErasing ? Colors.white : Colors.black; // Erase by drawing white
    });
  }
}

class GallerySaver {
  static saveImage(String path, {required String albumName}) {}
}

class DrawingPainter extends CustomPainter {
  final List<List<Offset?>> paths;
  final Color color;
  final double brushSize;
  final bool isErasing;

  DrawingPainter(this.paths, this.color, this.brushSize, this.isErasing);

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = brushSize
      ..isAntiAlias = true;

    // Draw the paths
    for (var path in paths) {
      for (int i = 0; i < path.length - 1; i++) {
        if (path[i] != null && path[i + 1] != null) {
          canvas.drawLine(path[i]!, path[i + 1]!, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
