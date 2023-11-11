import 'dart:io';

import 'package:background_fetch/background_fetch.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart';

const MethodChannel platform = MethodChannel('step_counter');
var logger = Logger();

int countFinal = 0;

@pragma('vm:entry-point')
void backgroundFetchHeadlessTask(HeadlessTask task) async {
  var taskId = task.taskId;
  var timeout = task.timeout;
  if (timeout) {
    logger.d("[BackgroundFetch] Headless task timed-out: $taskId");
    BackgroundFetch.finish(taskId);
    return;
  }
  logger.d("[BackgroundFetch] Headless event received: $taskId");
  if (await checkActivityPermission()) {
    // fetch first value from stream, this will automatically close the stream after that
    logger.d("called before stream");
    try {
      int count = await fetchStepCount();
      logger.d("total count is $count");
      BackgroundFetch.finish(taskId);
    } catch (e) {
      BackgroundFetch.finish(taskId);
    }
  } else {
    BackgroundFetch.finish(taskId);
  }
}

void listenPedometer() async {}

Future<bool> checkActivityPermission() async {
  if (Platform.isAndroid) {
    final status = await Permission.activityRecognition.status;
    return status.isGranted;
  } else if (Platform.isIOS) {
    return Permission.sensors.isGranted;
  }
  return false;
}

void main() {
  runApp(MyApp());
  BackgroundFetch.registerHeadlessTask(backgroundFetchHeadlessTask);
}

Future<int> fetchStepCount() async {
  try {
    final int stepCount = await platform.invokeMethod('getStepCount');
    return stepCount;
  } catch (e) {
    print('Error fetching step count: $e');
    return 0; // Handle errors appropriately
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int stepCount = 0;

  @override
  void initState() {
    super.initState();
    initPlatformState();
    // fetchStepCount();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Step Count Monitor'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FutureBuilder<int>(
            future: fetchStepCount(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const CircularProgressIndicator();
              } else if (snapshot.hasError) {
                return Text('Error: ${snapshot.error}');
              } else {
                return Text('Step Count: ${snapshot.data}');
              }
            },
          ),
            Text(
              '$stepCount',
              style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> initPlatformState() async {
    // Configure BackgroundFetch.
    // acitivityPermssion should be provided to
    final PermissionStatus requestStatus =
        await Permission.activityRecognition.request();

    // if permission granted get step count
    try {
      var status = await BackgroundFetch.configure(
          BackgroundFetchConfig(
              minimumFetchInterval: 15,
              forceAlarmManager: false,
              stopOnTerminate: false,
              startOnBoot: true,
              enableHeadless: true,
              requiresBatteryNotLow: false,
              requiresCharging: false,
              requiresStorageNotLow: false,
              requiresDeviceIdle: false,
              requiredNetworkType: NetworkType.NONE),
          _onBackgroundFetch,
          _onBackgroundFetchTimeout);
      print(
          '[BackgroundFetch] configure success: $status with ${DateTime.now()}');
    } on Exception catch (e) {
      print("[BackgroundFetch] configure ERROR: $e");
    }
  }

  void _onBackgroundFetch(String taskId) async {
    print("called background fetch method");
    int count = await fetchStepCount();
    logger.d("total count is $count");
    // IMPORTANT:  You must signal completion of your fetch task or the OS can punish your app
    // for taking too long in the background.
    BackgroundFetch.finish(taskId);
  }

  /// This event fires shortly before your task is about to timeout.  You must finish any outstanding work and call BackgroundFetch.finish(taskId).
  void _onBackgroundFetchTimeout(String taskId) {
    print("[BackgroundFetch] TIMEOUT: $taskId");
    BackgroundFetch.finish(taskId);
  }
}
