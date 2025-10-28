import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final themeIsDark = prefs.getBool('darkMode') ?? false;
  final fontSize = prefs.getDouble('fontSize') ?? 16.0;
  runApp(MyApp(themeIsDark: themeIsDark, fontSize: fontSize));
}

class MyApp extends StatefulWidget {
  final bool themeIsDark;
  final double fontSize;
  MyApp({required this.themeIsDark, required this.fontSize});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool darkMode = false;
  double fontSize = 16.0;
  @override
  void initState() {
    super.initState();
    darkMode = widget.themeIsDark;
    fontSize = widget.fontSize;
  }

  Future<void> _setDarkMode(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', v);
    setState(() => darkMode = v);
  }

  Future<void> _setFontSize(double v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('fontSize', v);
    setState(() => fontSize = v);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Persisting Data Lab',
      theme: ThemeData(
        brightness: darkMode ? Brightness.dark : Brightness.light,
        textTheme: Theme.of(context).textTheme.apply(fontSizeFactor: fontSize / 16.0),
      ),
      home: HomeScreen(
        darkMode: darkMode,
        fontSize: fontSize,
        onThemeChanged: _setDarkMode,
        onFontSizeChanged: _setFontSize,
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final bool darkMode;
  final double fontSize;
  final ValueChanged<bool> onThemeChanged;
  final ValueChanged<double> onFontSizeChanged;
  HomeScreen({required this.darkMode, required this.fontSize, required this.onThemeChanged, required this.onFontSizeChanged});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tc;
  @override
  void initState() {
    super.initState();
    _tc = TabController(length: 5, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Persisting Data Lab'),
        bottom: TabBar(
          controller: _tc,
          tabs: [
            Tab(text: 'SharedPrefs'),
            Tab(text: 'Counter'),
            Tab(text: 'SQLite'),
            Tab(text: 'File'),
            Tab(text: 'Hybrid'),
          ],
          isScrollable: true,
        ),
      ),
      body: TabBarView(
        controller: _tc,
        children: [
          SharedPrefsScreen(),
          CounterScreen(),
          NotesScreen(),
          FileStorageScreen(),
          HybridScreen(
            darkMode: widget.darkMode,
            fontSize: widget.fontSize,
            onThemeChanged: widget.onThemeChanged,
            onFontSizeChanged: widget.onFontSizeChanged,
          ),
        ],
      ),
    );
  }
}

class SharedPrefsScreen extends StatefulWidget {
  @override
  State<SharedPrefsScreen> createState() => _SharedPrefsScreenState();
}

class _SharedPrefsScreenState extends State<SharedPrefsScreen> {
  final TextEditingController _ctrl = TextEditingController();
  String username = '';

  @override
  void initState() {
    super.initState();
    _loadUsername();
  }

  Future<void> _loadUsername() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      username = prefs.getString('username') ?? '';
      _ctrl.text = username;
    });
  }

  Future<void> _saveUsername() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', _ctrl.text);
    setState(() => username = _ctrl.text);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(12),
      child: Column(
        children: [
          TextField(controller: _ctrl, decoration: InputDecoration(labelText: 'Username')),
          SizedBox(height: 12),
          ElevatedButton(onPressed: _saveUsername, child: Text('Save')),
          SizedBox(height: 20),
          Text('Saved username: $username'),
        ],
      ),
    );
  }
}

class CounterScreen extends StatefulWidget {
  @override
  State<CounterScreen> createState() => _CounterScreenState();
}

class _CounterScreenState extends State<CounterScreen> {
  int count = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => count = prefs.getInt('counter') ?? 0);
  }

  Future<void> _inc() async {
    final prefs = await SharedPreferences.getInstance();
    count++;
    await prefs.setInt('counter', count);
    setState(() {});
  }

  Future<void> _dec() async {
    final prefs = await SharedPreferences.getInstance();
    count--;
    await prefs.setInt('counter', count);
    setState(() {});
  }

  Future<void> _reset() async {
    final prefs = await SharedPreferences.getInstance();
    count = 0;
    await prefs.setInt('counter', count);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Counter: $count', style: TextStyle(fontSize: 28)),
        SizedBox(height: 12),
        Row(mainAxisSize: MainAxisSize.min, children: [
          ElevatedButton(onPressed: _inc, child: Text('+')),
          SizedBox(width: 8),
          ElevatedButton(onPressed: _dec, child: Text('-')),
          SizedBox(width: 8),
          ElevatedButton(onPressed: _reset, child: Text('Reset')),
        ])
      ]),
    );
  }
}

class Note {
  int? id;
  String title;
  String content;
  Note({this.id, required this.title, required this.content});
  Map<String, dynamic> toMap() => {'id': id, 'title': title, 'content': content};
  static Note fromMap(Map<String, dynamic> m) => Note(id: m['id'] as int?, title: m['title'] as String, content: m['content'] as String);
}

class DBHelper {
  static final DBHelper _instance = DBHelper._internal();
  factory DBHelper() => _instance;
  DBHelper._internal();
  Database? _db;
  Future<Database> get db async {
    if (_db != null) return _db!;
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = p.join(documentsDirectory.path, 'notes.db');
    _db = await openDatabase(path, version: 1, onCreate: (db, v) async {
      await db.execute('CREATE TABLE notes (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, content TEXT)');
    });
    return _db!;
  }

  Future<int> insertNote(Note n) async {
    final database = await db;
    return await database.insert('notes', n.toMap());
  }

  Future<List<Note>> getNotes() async {
    final database = await db;
    final res = await database.query('notes', orderBy: 'id DESC');
    return res.map((e) => Note.fromMap(e)).toList();
  }

  Future<int> updateNote(Note n) async {
    final database = await db;
    return await database.update('notes', n.toMap(), where: 'id = ?', whereArgs: [n.id]);
  }

  Future<int> deleteNote(int id) async {
    final database = await db;
    return await database.delete('notes', where: 'id = ?', whereArgs: [id]);
  }
}

class NotesScreen extends StatefulWidget {
  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final DBHelper helper = DBHelper();
  List<Note> notes = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    notes = await helper.getNotes();
    setState(() {});
  }

  Future<void> _addDummy() async {
    await helper.insertNote(Note(title: 'New note ${DateTime.now().millisecondsSinceEpoch}', content: 'Sample content'));
    await _load();
  }

  Future<void> _showEditor([Note? n]) async {
    final titleCtrl = TextEditingController(text: n?.title ?? '');
    final contentCtrl = TextEditingController(text: n?.content ?? '');
    final res = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(n == null ? 'Add Note' : 'Edit Note'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: titleCtrl, decoration: InputDecoration(labelText: 'Title')),
          TextField(controller: contentCtrl, decoration: InputDecoration(labelText: 'Content')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text('Save')),
        ],
      ),
    );
    if (res == true) {
      if (n == null) {
        await helper.insertNote(Note(title: titleCtrl.text, content: contentCtrl.text));
      } else {
        n.title = titleCtrl.text;
        n.content = contentCtrl.text;
        await helper.updateNote(n);
      }
      await _load();
    }
  }

  Future<void> _confirmDelete(Note n) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete?'),
        content: Text('Delete "${n.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('No')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text('Yes')),
        ],
      ),
    );
    if (res == true) {
      await helper.deleteNote(n.id!);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(padding: EdgeInsets.all(8), child: Row(children: [
        ElevatedButton(onPressed: _addDummy, child: Text('Add Note')),
        SizedBox(width: 8),
        ElevatedButton(onPressed: _load, child: Text('View Notes')),
      ])),
      Expanded(
        child: ListView.builder(
          itemCount: notes.length,
          itemBuilder: (_, i) {
            final n = notes[i];
            return ListTile(
              title: Text(n.title),
              subtitle: Text(n.content),
              onTap: () => _showEditor(n),
              trailing: IconButton(icon: Icon(Icons.delete), onPressed: () => _confirmDelete(n)),
            );
          },
        ),
      )
    ]);
  }
}

class FileStorageScreen extends StatefulWidget {
  @override
  State<FileStorageScreen> createState() => _FileStorageScreenState();
}

class _FileStorageScreenState extends State<FileStorageScreen> {
  String content = '';

  Future<File> _localFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, 'user_data.txt'));
  }

  Future<void> _write() async {
    final f = await _localFile();
    await f.writeAsString('Saved at ${DateTime.now()}');
    await _read();
  }

  Future<void> _read() async {
    try {
      final f = await _localFile();
      final s = await f.readAsString();
      setState(() => content = s);
    } catch (e) {
      setState(() => content = 'No file yet');
    }
  }

  @override
  void initState() {
    super.initState();
    _read();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(12),
      child: Column(children: [
        ElevatedButton(onPressed: _write, child: Text('Write file')),
        SizedBox(height: 8),
        ElevatedButton(onPressed: _read, child: Text('Read file')),
        SizedBox(height: 12),
        Text('File content:'),
        SizedBox(height: 8),
        SelectableText(content),
      ]),
    );
  }
}

class HybridScreen extends StatefulWidget {
  final bool darkMode;
  final double fontSize;
  final ValueChanged<bool> onThemeChanged;
  final ValueChanged<double> onFontSizeChanged;
  HybridScreen({required this.darkMode, required this.fontSize, required this.onThemeChanged, required this.onFontSizeChanged});
  @override
  State<HybridScreen> createState() => _HybridScreenState();
}

class _HybridScreenState extends State<HybridScreen> {
  bool darkMode = false;
  double fontSize = 16.0;
  List<Note> notes = [];
  final DBHelper helper = DBHelper();

  @override
  void initState() {
    super.initState();
    darkMode = widget.darkMode;
    fontSize = widget.fontSize;
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    notes = await helper.getNotes();
    setState(() {});
  }

  Future<void> _addNote() async {
    await helper.insertNote(Note(title: 'Hybrid ${DateTime.now().millisecondsSinceEpoch}', content: 'From Hybrid'));
    await _loadNotes();
  }

  Future<void> _toggleTheme(bool v) async {
    widget.onThemeChanged(v);
    setState(() => darkMode = v);
  }

  Future<void> _setFont(double v) async {
    widget.onFontSizeChanged(v);
    setState(() => fontSize = v);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(12),
      child: Column(children: [
        Row(children: [
          Text('Dark mode'),
          Switch(value: darkMode, onChanged: _toggleTheme),
          SizedBox(width: 12),
          Text('Font'),
          Slider(value: fontSize, min: 12, max: 24, divisions: 6, label: fontSize.toStringAsFixed(0), onChanged: _setFont),
        ]),
        SizedBox(height: 8),
        ElevatedButton(onPressed: _addNote, child: Text('Add note to SQLite')),
        SizedBox(height: 12),
        Expanded(
          child: ListView.builder(
            itemCount: notes.length,
            itemBuilder: (_, i) {
              final n = notes[i];
              return ListTile(title: Text(n.title), subtitle: Text(n.content));
            },
          ),
        )
      ]),
    );
  }
}
