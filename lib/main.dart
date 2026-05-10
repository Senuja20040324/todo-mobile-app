import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:js' as js;

void main() {
  runApp(const MyApp());
}

void webSave(String key, String value) {
  js.context['localStorage'].callMethod('setItem', [key, value]);
}

String? webLoad(String key) {
  return js.context['localStorage'].callMethod('getItem', [key]);
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    // Load dark mode preference
    final saved = webLoad('dark_mode');
    if (saved == 'true') {
      setState(() => _isDarkMode = true);
    }
  }

  void _toggleDarkMode() {
    setState(() => _isDarkMode = !_isDarkMode);
    webSave('dark_mode', _isDarkMode.toString());
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'To-Do App',
      debugShowCheckedModeBanner: false,
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: TodoHomePage(
        isDarkMode: _isDarkMode,
        onToggleDarkMode: _toggleDarkMode,
      ),
    );
  }
}

class Task {
  String title;
  String priority;
  bool isDone;
  String createdAt;
  String? dueDate;

  Task({
    required this.title,
    required this.priority,
    this.isDone = false,
    required this.createdAt,
    this.dueDate,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'priority': priority,
    'isDone': isDone,
    'createdAt': createdAt,
    'dueDate': dueDate,
  };

  factory Task.fromJson(Map<String, dynamic> json) => Task(
    title: json['title'],
    priority: json['priority'],
    isDone: json['isDone'],
    createdAt: json['createdAt'],
    dueDate: json['dueDate'],
  );
}

class TodoHomePage extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onToggleDarkMode;

  const TodoHomePage({
    super.key,
    required this.isDarkMode,
    required this.onToggleDarkMode,
  });

  @override
  State<TodoHomePage> createState() => _TodoHomePageState();
}

class _TodoHomePageState extends State<TodoHomePage> {
  final List<Task> _tasks = [];
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  String _selectedPriority = 'Medium';
  String _searchQuery = '';
  DateTime? _selectedDueDate;

  @override
  void initState() {
    super.initState();
    _loadTasks();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  void _saveTasks() {
    final String encodedData = jsonEncode(
      _tasks.map((task) => task.toJson()).toList(),
    );
    webSave('flutter_tasks', encodedData);
  }

  void _loadTasks() {
    final String? encodedData = webLoad('flutter_tasks');
    if (encodedData != null && encodedData.isNotEmpty) {
      try {
        final List<dynamic> decodedData = jsonDecode(encodedData);
        setState(() {
          _tasks.addAll(decodedData.map((item) => Task.fromJson(item)));
        });
      } catch (e) {
        debugPrint('Error loading tasks: $e');
      }
    }
  }

  List<Task> get _filteredTasks {
    if (_searchQuery.isEmpty) return _tasks;
    return _tasks
        .where(
          (task) =>
              task.title.toLowerCase().contains(_searchQuery) ||
              task.priority.toLowerCase().contains(_searchQuery),
        )
        .toList();
  }

  Map<String, dynamic> _getDueStatus(String? dueDate) {
    if (dueDate == null) return {'text': 'No due date', 'color': Colors.grey};
    final due = DateTime.parse(dueDate);
    final today = DateTime.now();
    final diff = due
        .difference(DateTime(today.year, today.month, today.day))
        .inDays;
    if (diff < 0) return {'text': '⚠️ Overdue!', 'color': Colors.red};
    if (diff == 0) return {'text': '⏰ Due Today!', 'color': Colors.orange};
    if (diff <= 3)
      return {'text': '⚡ Due in $diff day(s)', 'color': Colors.amber};
    return {'text': '📅 ${dueDate.substring(0, 10)}', 'color': Colors.green};
  }

  void _addTask() {
    if (_controller.text.isEmpty) return;
    setState(() {
      _tasks.add(
        Task(
          title: _controller.text,
          priority: _selectedPriority,
          createdAt: DateTime.now().toString().substring(0, 16),
          dueDate: _selectedDueDate?.toString().substring(0, 10),
        ),
      );
      _controller.clear();
      _selectedPriority = 'Medium';
      _selectedDueDate = null;
    });
    _saveTasks();
    Navigator.pop(context);
  }

  void _toggleTask(int index) {
    final task = _filteredTasks[index];
    final actualIndex = _tasks.indexOf(task);
    setState(() {
      _tasks[actualIndex].isDone = !_tasks[actualIndex].isDone;
    });
    _saveTasks();
  }

  void _deleteTask(int index) {
    final task = _filteredTasks[index];
    final actualIndex = _tasks.indexOf(task);
    setState(() {
      _tasks.removeAt(actualIndex);
    });
    _saveTasks();
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'High':
        return Colors.red;
      case 'Medium':
        return Colors.orange;
      case 'Low':
        return Colors.green;
      default:
        return Colors.orange;
    }
  }

  String _getPriorityEmoji(String priority) {
    switch (priority) {
      case 'High':
        return '🔴';
      case 'Medium':
        return '🟡';
      case 'Low':
        return '🟢';
      default:
        return '🟡';
    }
  }

  void _showAddTaskDialog() {
    _selectedDueDate = null;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('➕ Add New Task'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  hintText: 'Enter task title...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Select Priority:'),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: ['High', 'Medium', 'Low'].map((p) {
                  return GestureDetector(
                    onTap: () => setDialogState(() => _selectedPriority = p),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _selectedPriority == p
                            ? _getPriorityColor(p)
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_getPriorityEmoji(p)} $p',
                        style: TextStyle(
                          color: _selectedPriority == p
                              ? Colors.white
                              : Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.calendar_today, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text(
                    _selectedDueDate == null
                        ? 'No due date'
                        : '📅 ${_selectedDueDate!.toString().substring(0, 10)}',
                    style: TextStyle(
                      color: _selectedDueDate == null
                          ? Colors.grey
                          : Colors.blue,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setDialogState(() => _selectedDueDate = picked);
                      }
                    },
                    child: const Text('Pick Date'),
                  ),
                  if (_selectedDueDate != null)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () =>
                          setDialogState(() => _selectedDueDate = null),
                    ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(onPressed: _addTask, child: const Text('Add Task')),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    int done = _tasks.where((t) => t.isDone).length;
    int pending = _tasks.where((t) => !t.isDone).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '✅ My To-Do App',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          // 🌙 Dark mode toggle button
          IconButton(
            icon: Icon(
              widget.isDarkMode ? Icons.wb_sunny : Icons.nightlight_round,
              color: Colors.white,
            ),
            onPressed: widget.onToggleDarkMode,
            tooltip: widget.isDarkMode ? 'Light Mode' : 'Dark Mode',
          ),
        ],
      ),
      body: Column(
        children: [
          // Statistics bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50.withOpacity(
              widget.isDarkMode ? 0.1 : 1.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _statCard('Total', _tasks.length.toString(), Colors.blue),
                _statCard('Done', done.toString(), Colors.green),
                _statCard('Pending', pending.toString(), Colors.orange),
              ],
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '🔍 Search tasks...',
                prefixIcon: const Icon(Icons.search, color: Colors.blue),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: const BorderSide(color: Colors.blue, width: 2),
                ),
              ),
            ),
          ),

          if (_searchQuery.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${_filteredTasks.length} result(s) for "$_searchQuery"',
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
            ),

          // Task list
          Expanded(
            child: _filteredTasks.isEmpty
                ? Center(
                    child: Text(
                      _searchQuery.isNotEmpty
                          ? '🔍 No tasks found for "$_searchQuery"'
                          : 'No tasks yet!\nTap + to add one 😊',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredTasks.length,
                    itemBuilder: (context, index) {
                      final task = _filteredTasks[index];
                      final dueStatus = _getDueStatus(task.dueDate);
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: ListTile(
                          leading: Checkbox(
                            value: task.isDone,
                            onChanged: (_) => _toggleTask(index),
                            activeColor: Colors.green,
                          ),
                          title: Text(
                            task.title,
                            style: TextStyle(
                              decoration: task.isDone
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: task.isDone ? Colors.grey : null,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_getPriorityEmoji(task.priority)} ${task.priority} · ${task.createdAt}',
                              ),
                              Text(
                                dueStatus['text'],
                                style: TextStyle(
                                  color: dueStatus['color'],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteTask(index),
                          ),
                          isThreeLine: true,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTaskDialog,
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _statCard(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }
}
