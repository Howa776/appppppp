import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SimpleMemoApp());
}

class SimpleMemoApp extends StatelessWidget {
  const SimpleMemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'シンプルメモ',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const MemoListPage(),
    );
  }
}

class Memo {
  final String id;
  final String content;
  final DateTime updatedAt;

  Memo({
    required this.id,
    required this.content,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'content': content,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Memo.fromJson(Map<String, dynamic> json) => Memo(
        id: json['id'] as String,
        content: json['content'] as String,
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
}

class MemoListPage extends StatefulWidget {
  const MemoListPage({super.key});

  @override
  State<MemoListPage> createState() => _MemoListPageState();
}

class _MemoListPageState extends State<MemoListPage> {
  List<Memo> _memos = [];

  @override
  void initState() {
    super.initState();
    _loadMemos();
  }

  Future<void> _loadMemos() async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList('memos') ?? [];
    setState(() {
      _memos = rawList
          .map((e) => Memo.fromJson(jsonDecode(e) as Map<String, dynamic>))
          .toList();
    });
  }

  Future<void> _saveMemos() async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = _memos.map((m) => jsonEncode(m.toJson())).toList();
    await prefs.setStringList('memos', rawList);
  }

  Future<void> _openEditor({Memo? existing}) async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => MemoEditPage(initialText: existing?.content ?? ''),
      ),
    );
    if (result == null) return;

    final trimmed = result.trim();
    setState(() {
      if (existing != null) {
        if (trimmed.isEmpty) {
          _memos.removeWhere((m) => m.id == existing.id);
        } else {
          final index = _memos.indexWhere((m) => m.id == existing.id);
          if (index != -1) {
            _memos[index] = Memo(
              id: existing.id,
              content: result,
              updatedAt: DateTime.now(),
            );
          }
        }
      } else if (trimmed.isNotEmpty) {
        _memos.insert(
          0,
          Memo(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            content: result,
            updatedAt: DateTime.now(),
          ),
        );
      }
      _memos.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    });
    await _saveMemos();
  }

  Future<void> _deleteMemo(Memo memo) async {
    setState(() {
      _memos.removeWhere((m) => m.id == memo.id);
    });
    await _saveMemos();
  }

  String _formatDate(DateTime dt) {
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '${dt.year}/$m/$d $h:$min';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('シンプルメモ'),
        centerTitle: true,
      ),
      body: _memos.isEmpty
          ? const Center(
              child: Text('右下の「＋」から最初のメモを追加してみましょう'),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _memos.length,
              itemBuilder: (context, index) {
                final memo = _memos[index];
                final firstLine = memo.content.trim().split('\n').first;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(
                      firstLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(_formatDate(memo.updatedAt)),
                    onTap: () => _openEditor(existing: memo),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _deleteMemo(memo),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class MemoEditPage extends StatefulWidget {
  final String initialText;
  const MemoEditPage({super.key, required this.initialText});

  @override
  State<MemoEditPage> createState() => _MemoEditPageState();
}

class _MemoEditPageState extends State<MemoEditPage> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initialText.isEmpty ? '新規メモ' : 'メモを編集'),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.of(context).pop(_controller.text),
            icon: const Icon(Icons.check),
            label: const Text('保存'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          controller: _controller,
          autofocus: widget.initialText.isEmpty,
          maxLines: null,
          expands: true,
          textAlignVertical: TextAlignVertical.top,
          decoration: const InputDecoration(
            hintText: 'ここにメモを入力...',
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }
}
