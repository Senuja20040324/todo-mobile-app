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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'To-Do App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const TodoHomePage(),
    );
  }
}

class Task {
  String title;
  String priority;
  bool isDone;
  String createdAt;

  Task({
    required this.title,
    required this.priority,
    this.isDone = false,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'priority': priority,
    'isDone': isDone,
    'createdAt': createdAt,
  };

  factory Task.fromJson(Map<String, dynamic> json) => Task(
    title: json['title'],
    priority: json['priority'],
    isDone: json['isDone'],
    createdAt: json['createdAt'],
  );
}

class TodoHomePage extends StatefulWidget {
  const TodoHomePage({super.key});

  @override
  State<TodoHomePage> createState() => _TodoHomePageState();
}

class _TodoHomePageState extends State<TodoHomePage> {
  final List<Task> _tasks = [];
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  String _selectedPriority = 'Medium';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadTasks();
    // Listen to search input
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

  // Filter tasks based on search query
  List<Task> get _filteredTasks {
    if (_searchQuery.isEmpty) return _tasks;
    return _tasks
        .where((task) => task.title.toLowerCase().contains(_searchQuery))
        .toList();
  }

  void _addTask() {
    if (_controller.text.isEmpty) return;
    setState(() {
      _tasks.add(
        Task(
          title: _controller.text,
          priority: _selectedPriority,
          createdAt: DateTime.now().toString().substring(0, 16),
        ),
      );
      _controller.clear();
      _selectedPriority = 'Medium';
    });
    _saveTasks();
    Navigator.pop(context);
  }

  void _toggleTask(int index) {
    // Find actual task from filtered list
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
      ),
      body: Column(
        children: [
          // Statistics bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _statCard('Total', _tasks.length.toString(), Colors.blue),
                _statCard('Done', done.toString(), Colors.green),
                _statCard('Pending', pending.toString(), Colors.orange),
              ],
            ),
          ),

          // 🔍 Search Bar
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
                        onPressed: () {
                          _searchController.clear();
                        },
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

          // Search results count
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
                              color: task.isDone ? Colors.grey : Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            '${_getPriorityEmoji(task.priority)} ${task.priority} · ${task.createdAt}',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteTask(index),
                          ),
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
