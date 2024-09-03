import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';


class Task {
  final String text;
  final Color color;
  final DateTime time;
  final bool isCompleted; 

  Task({
    required this.text,
    required this.color,
    required this.time,
    this.isCompleted = false,
  });

  Task copyWith({
    String? text,
    Color? color,
    DateTime? time,
    bool? isCompleted,
  }) {
    return Task(
      text: text ?? this.text,
      color: color ?? this.color,
      time: time ?? this.time,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }


  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'color': color.value,
      'time': time.toIso8601String(),
      'isCompleted': isCompleted, 
    };
  }

  
  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      text: map['text'],
      color: Color(map['color']),
      time: DateTime.parse(map['time']),
      isCompleted: map['isCompleted'],
    );
  }

  
  String toJson() => json.encode(toMap());

  
  factory Task.fromJson(String source) => Task.fromMap(json.decode(source));
}

Color getRandomColor() {
  final random = Random();
  return Color.fromARGB(
    255,
    random.nextInt(256),
    random.nextInt(256),
    random.nextInt(256),
  );
}


class ThemeProvider extends ChangeNotifier {
  bool isDarkTheme = true;

  ThemeData get themeData => isDarkTheme ? ThemeData.dark() : ThemeData.light();

  void toggleTheme() {
    isDarkTheme = !isDarkTheme;
    notifyListeners();
  }
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
        ChangeNotifierProvider(create: (context) => ToDoProvider()),
        ChangeNotifierProvider(create: (context) => TaskHistoryProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'Flutter To-Do List with Calendar',
            theme: themeProvider.themeData,
            home: const MyHomePage(),
          );
        },
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _requestNotificationPermission();
    _loadTasks();
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('app_icon');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> _loadTasks() async {
    await Provider.of<ToDoProvider>(context, listen: false).loadTasks();
  }

  Future<void> _requestNotificationPermission() async {
    final status = await Permission.notification.request();
    if (status.isGranted) {
      print("Notification permission granted.");
    } else if (status.isDenied) {
      print("Notification permission denied.");
    } else if (status.isPermanentlyDenied) {
      print("Notification permission permanently denied. Please enable it from settings.");
      openAppSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TodoCalendar'),
        centerTitle: true,
        actions: [
          Switch(
            value: Provider.of<ThemeProvider>(context).isDarkTheme,
            onChanged: (value) {
              Provider.of<ThemeProvider>(context, listen: false).toggleTheme();
            },
            activeColor: Colors.white,
            inactiveThumbColor: Colors.black,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Provider.of<ThemeProvider>(context).isDarkTheme
                  ? Colors.black
                  : Colors.white,
              borderRadius: BorderRadius.circular(12.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.5),
                  spreadRadius: 2,
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: TableCalendar(
              firstDay: DateTime.utc(2000, 1, 1),
              lastDay: DateTime.utc(2100, 12, 31),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              selectedDayPredicate: (day) {
                return isSameDay(_selectedDay, day);
              },
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
                _showAddTaskDialog(context);
              },
              eventLoader: (day) {
                return Provider.of<ToDoProvider>(context).getTasksForDay(day);
              },
              calendarStyle: CalendarStyle(
                defaultTextStyle: TextStyle(
                  color: Provider.of<ThemeProvider>(context).isDarkTheme
                      ? Colors.white
                      : Colors.black,
                ),
                weekendTextStyle: TextStyle(
                  color: Provider.of<ThemeProvider>(context).isDarkTheme
                      ? Colors.white
                      : Colors.black,
                ),
                outsideTextStyle: TextStyle(
                  color: Provider.of<ThemeProvider>(context).isDarkTheme
                      ? Colors.grey
                      : Colors.black38,
                ),
                todayDecoration: BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: Colors.blueAccent,
                  shape: BoxShape.circle,
                ),
                markerDecoration: BoxDecoration(
                  color: Provider.of<ThemeProvider>(context).isDarkTheme
                      ? Colors.white
                      : Colors.black,
                  shape: BoxShape.circle,
                ),
                outsideDaysVisible: false,
              ),
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: TextStyle(
                  color: Provider.of<ThemeProvider>(context).isDarkTheme
                      ? Colors.white
                      : Colors.black,
                  fontSize: 16.0,
                  fontWeight: FontWeight.bold,
                ),
                leftChevronIcon: Icon(
                  Icons.chevron_left,
                  color: Provider.of<ThemeProvider>(context).isDarkTheme
                      ? Colors.white
                      : Colors.black,
                ),
                rightChevronIcon: Icon(
                  Icons.chevron_right,
                  color: Provider.of<ThemeProvider>(context).isDarkTheme
                      ? Colors.white
                      : Colors.black,
                ),
                decoration: BoxDecoration(
                  color: Provider.of<ThemeProvider>(context).isDarkTheme
                      ? Colors.black
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12.0),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8.0),
          Expanded(
            child: Consumer<ToDoProvider>(
              builder: (context, provider, child) {
                final tasks = provider.getTasksForDay(_selectedDay);
                return tasks.isEmpty
                    ? Center(
                        child: Text(
                          'No tasks for ${_selectedDay.toLocal()}'.split(' ')[0],
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.grey,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        itemCount: tasks.length,
                        itemBuilder: (context, index) {
                          final task = tasks[index];
                          final formattedTime =
                              DateFormat('hh:mm a').format(task.time);

                          return Card(
                            color: task.color.withOpacity(0.5),
                            elevation: 4,
                            margin: const EdgeInsets.symmetric(vertical: 8.0),
                            child: ListTile(
                              title: Text(
                                task.text,
                                style: const TextStyle(fontSize: 18),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8.0),
                                    child: Text(
                                      formattedTime,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit),
                                    onPressed: () =>
                                        _showEditTaskDialog(context, task),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete),
                                    onPressed: () =>
                                        _deleteTask(context, task),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.check),
                                    onPressed: () =>
                                        _completeTask(context, task),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
              },
            ),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue,
              ),
              child: Text(
                'Menu',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            ListTile(
              title: const Text('Task History'),
              onTap: () => _showTaskHistory(context),
            ),
          ],
        ),
      ),

    );
  }

  Future<void> _showAddTaskDialog(BuildContext context) async {
    final provider = Provider.of<ToDoProvider>(context, listen: false);
    TextEditingController taskController = TextEditingController();
    TimeOfDay? selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (selectedTime != null) {
      final time = DateTime(
        _selectedDay.year,
        _selectedDay.month,
        _selectedDay.day,
        selectedTime.hour,
        selectedTime.minute,
      );
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Add Task'),
            content: TextField(
              controller: taskController,
              decoration: const InputDecoration(hintText: 'Enter task name'),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  final taskText = taskController.text;
                  if (taskText.isNotEmpty) {
                    final task = Task(
                      text: taskText,
                      color: getRandomColor(),
                      time: time,
                    );
                    provider.addTask(_selectedDay, task);
                    flutterLocalNotificationsPlugin.schedule(
                      task.hashCode,
                      'Task Reminder',
                      taskText,
                      time,
                      const NotificationDetails(
                        android: AndroidNotificationDetails(
                          'channelId',
                          'channelName',
                          importance: Importance.high,
                          priority: Priority.high,
                        ),
                      ),
                    );
                    Navigator.of(context).pop();
                  }
                },
                child: const Text('Add'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      );
    }
  }

  Future<void> _showEditTaskDialog(BuildContext context, Task task) async {
    final provider = Provider.of<ToDoProvider>(context, listen: false);
    TextEditingController taskController =
        TextEditingController(text: task.text);
    TimeOfDay? selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(task.time),
    );

    if (selectedTime != null) {
      final time = DateTime(
        _selectedDay.year,
        _selectedDay.month,
        _selectedDay.day,
        selectedTime.hour,
        selectedTime.minute,
      );
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Edit Task'),
            content: TextField(
              controller: taskController,
              decoration: const InputDecoration(hintText: 'Enter task name'),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  final taskText = taskController.text;
                  if (taskText.isNotEmpty) {
                    final updatedTask = Task(
                      text: taskText,
                      color: task.color,
                      time: time,
                    );
                    provider.editTask(_selectedDay, task, updatedTask);
                    Navigator.of(context).pop();
                  }
                },
                child: const Text('Save'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      );
    }
  }

  void _deleteTask(BuildContext context, Task task) {
    Provider.of<ToDoProvider>(context, listen: false)
        .deleteTask(_selectedDay, task);
  }

  void _completeTask(BuildContext context, Task task) {
    final provider = Provider.of<ToDoProvider>(context, listen: false);
    final taskHistoryProvider =
        Provider.of<TaskHistoryProvider>(context, listen: false);

    
    provider.markTaskAsCompleted(_selectedDay, task);

    
    taskHistoryProvider.addCompletedTask(task);

    
    provider.deleteTask(_selectedDay, task);
  }

  void _showTaskHistory(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const TaskHistoryPage(),
      ),
    );
  }
}

class ToDoProvider extends ChangeNotifier {
  Map<DateTime, List<Task>> _tasks = {};
  final List<Task> _completedTasks = []; 

  Future<void> loadTasks() async {
    final prefs = await SharedPreferences.getInstance();

    
    final tasksJson = prefs.getString('tasks');
    if (tasksJson != null) {
      final loadedTasks = (json.decode(tasksJson) as Map<String, dynamic>)
          .map((key, value) => MapEntry(
                DateTime.parse(key),
                List<Task>.from(value.map((item) => Task.fromMap(item))),
              ));
      _tasks = loadedTasks;
    }

    
    final completedTasksJson = prefs.getString('completedTasks');
    if (completedTasksJson != null) {
      _completedTasks.addAll(
        List<Task>.from(json.decode(completedTasksJson).map((item) => Task.fromMap(item))),
      );
    }

    notifyListeners();
  }

  void addTask(DateTime date, Task task) {
  final now = DateTime.now();
  if (task.time.isBefore(now)) {
    
    _moveToTaskHistory(task.copyWith(
      color: Colors.red,
      text: "failed task: ${task.text}",
    ));
  } else {
    
    if (_tasks[date] == null) {
      _tasks[date] = [];
    }
    _tasks[date]!.add(task);
    _saveTasks();  
    notifyListeners();  
  }
}


  void editTask(DateTime date, Task oldTask, Task newTask) {
    _tasks[date]?.remove(oldTask);
    if (newTask.time.isBefore(DateTime.now())) {
      _moveToTaskHistory(newTask.copyWith(
        color: Colors.red,
        text: "failed task: ${newTask.text}",
      ));
    } else {
      _tasks[date]?.add(newTask);
    }
    _saveTasks();
    notifyListeners();
  }

  void deleteTask(DateTime date, Task task) {
    _tasks[date]?.remove(task);
    _saveTasks();
    notifyListeners();
  }

  void markTaskAsCompleted(DateTime date, Task task) {
    final updatedTask = Task(
      text: task.text,
      color: task.color,
      time: task.time,
      isCompleted: true,
    );
    
    _tasks[date]?.remove(task);
    
    _completedTasks.add(updatedTask);
    _saveTasks();
    notifyListeners();
  }

  List<Task> getTasksForDay(DateTime day) {
    return _tasks[day] ?? [];
  }

  List<Task> getCompletedTasks() {
    return _completedTasks;
  }

  void _moveToTaskHistory(Task task) {
    _completedTasks.add(task);
 
    _saveTasks();
  }

  void _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final tasksJson = _tasks.map((key, value) => MapEntry(
          key.toIso8601String(),
          value.map((task) => task.toMap()).toList(),
        ));
    prefs.setString('tasks', json.encode(tasksJson));

    
    prefs.setString(
      'completedTasks',
      json.encode(_completedTasks.map((task) => task.toMap()).toList()),
    );
  }
}



class TaskHistoryProvider extends ChangeNotifier {
  List<Task> _completedTasks = [];

  TaskHistoryProvider() {
    _loadCompletedTasks();
  }

  Future<void> _loadCompletedTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final tasksJson = prefs.getString('completedTasks');
    if (tasksJson != null) {
      _completedTasks = List<Task>.from(
        json.decode(tasksJson).map((item) => Task.fromMap(item))
      );
      notifyListeners();
    }
  }

  void addCompletedTask(Task task) {
    _completedTasks.add(task);
    _saveCompletedTasks();
    notifyListeners();
  }

  List<Task> get completedTasks => _completedTasks;

  void _saveCompletedTasks() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString(
      'completedTasks',
      json.encode(_completedTasks.map((task) => task.toMap()).toList()),
    );
  }
}


class TaskHistoryPage extends StatelessWidget {
  const TaskHistoryPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task History'),
        centerTitle: true,
      ),
      body: Consumer<TaskHistoryProvider>(
        builder: (context, provider, child) {
          final completedTasks = provider.completedTasks;

          return completedTasks.isEmpty
              ? Center(
                  child: Text(
                    'No completed tasks.',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: completedTasks.length,
                  itemBuilder: (context, index) {
                    final task = completedTasks[index];
                    final formattedTime =
                        DateFormat('MMM dd, yyyy hh:mm a').format(task.time);

                    return Card(
                      color: task.color.withOpacity(0.5),
                      elevation: 4,
                      margin: const EdgeInsets.symmetric(vertical: 8.0),
                      child: ListTile(
                        title: Text(
                          task.text,
                          style: const TextStyle(fontSize: 18),
                        ),
                        subtitle: Text(
                          formattedTime,
                          style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                        ),
                      ),
                    );
                  },
                );
        },
      ),
    );
  }
}
