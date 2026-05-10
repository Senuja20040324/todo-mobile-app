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
    final saved = webLoad('dark_mode');
    if (saved == 'true') setState(() => _isDarkMode = true);
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
      setState(() => _searchQuery = _searchController.text.toLowerCase());
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
    setState(() => _tasks[actualIndex].isDone = !_tasks[actualIndex].isDone);
    _saveTasks();
  }

  void _deleteTask(int index) {
    final task = _filteredTasks[index];
    final actualIndex = _tasks.indexOf(task);
    setState(() => _tasks.removeAt(actualIndex));
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

  // Navigate to Statistics page
  void _openStatistics() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => StatisticsPage(tasks: _tasks)),
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
          // Statistics button
          IconButton(
            icon: const Icon(Icons.bar_chart, color: Colors.white),
            onPressed: _openStatistics,
            tooltip: 'Statistics',
          ),
          // Dark mode toggle
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

// ─────────────────────────────────────────
// 📊 STATISTICS PAGE
// ─────────────────────────────────────────
class StatisticsPage extends StatelessWidget {
  final List<Task> tasks;
  const StatisticsPage({super.key, required this.tasks});

  @override
  Widget build(BuildContext context) {
    final total = tasks.length;
    final done = tasks.where((t) => t.isDone).length;
    final pending = total - done;
    final high = tasks.where((t) => t.priority == 'High').length;
    final medium = tasks.where((t) => t.priority == 'Medium').length;
    final low = tasks.where((t) => t.priority == 'Low').length;
    final percent = total > 0 ? (done / total * 100).toInt() : 0;

    final today = DateTime.now();
    final overdue = tasks
        .where(
          (t) =>
              t.dueDate != null &&
              !t.isDone &&
              DateTime.parse(
                t.dueDate!,
              ).isBefore(DateTime(today.year, today.month, today.day)),
        )
        .length;
    final dueToday = tasks
        .where(
          (t) =>
              t.dueDate != null &&
              !t.isDone &&
              DateTime.parse(
                t.dueDate!,
              ).isAtSameMomentAs(DateTime(today.year, today.month, today.day)),
        )
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '📊 Statistics',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Progress Card
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🎯 Overall Progress',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: total > 0 ? done / total : 0,
                        minHeight: 20,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.green,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$percent% Complete ($done of $total tasks done)',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Task Count Cards
            const Text(
              '📋 Task Overview',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _countCard('Total', total, Colors.blue, Icons.list),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _countCard(
                    'Done',
                    done,
                    Colors.green,
                    Icons.check_circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _countCard(
                    'Pending',
                    pending,
                    Colors.orange,
                    Icons.pending,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Priority Cards
            const Text(
              '🎯 By Priority',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _countCard(
                    '🔴 High',
                    high,
                    Colors.red,
                    Icons.priority_high,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _countCard(
                    '🟡 Medium',
                    medium,
                    Colors.orange,
                    Icons.remove,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _countCard(
                    '🟢 Low',
                    low,
                    Colors.green,
                    Icons.low_priority,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Due Date Cards
            const Text(
              '📅 Due Dates',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _countCard(
                    '⚠️ Overdue',
                    overdue,
                    Colors.red,
                    Icons.warning,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _countCard(
                    '⏰ Today',
                    dueToday,
                    Colors.orange,
                    Icons.today,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Priority Progress bars
            const Text(
              '📊 Priority Breakdown',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _priorityBar('🔴 High', high, total, Colors.red),
                    const SizedBox(height: 12),
                    _priorityBar('🟡 Medium', medium, total, Colors.orange),
                    const SizedBox(height: 12),
                    _priorityBar('🟢 Low', low, total, Colors.green),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _countCard(String label, int value, Color color, IconData icon) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 8),
            Text(
              value.toString(),
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _priorityBar(String label, int count, int total, Color color) {
    final percent = total > 0 ? count / total : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('$count tasks', style: const TextStyle(color: Colors.grey)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: percent.toDouble(),
            minHeight: 12,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
