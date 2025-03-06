import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_apps/device_apps.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'package:intl/intl.dart';

import 'content_detector.dart';

void main() {
  runApp(const BelusLauncher());
}

class BelusLauncher extends StatelessWidget {
  const BelusLauncher({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Launcher',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.dark(
          primary: Colors.indigo,
          surface: Colors.grey[800]?.withOpacity(0.8) ?? Colors.grey,
          background: Colors.grey[900]?.withOpacity(0.9) ?? Colors.black,
        ),
        cardTheme: CardTheme(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      home: const LauncherHome(),
    );
  }
}

class LauncherHome extends GetView<LauncherController> {
  const LauncherHome({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Get.put(LauncherController());

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const DigitalClock(),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Obx(() => controller.isLoading.value
            ? const Center(child: CircularProgressIndicator())
            : AppsGrid(apps: controller.filteredApps)),
      ),
      bottomNavigationBar: SearchBar(
        controller: controller.searchController,
        onChanged: controller.filterApps,
      ),
    );
  }
}

class AppsGrid extends StatelessWidget {
  final List<AppInfo> apps;

  const AppsGrid({Key? key, required this.apps}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(8.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.7,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: apps.length,
      itemBuilder: (context, index) => AppTile(app: apps[index]),
    );
  }
}

class AppTile extends StatelessWidget {
  final AppInfo app;

  const AppTile({Key? key, required this.app}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => DeviceApps.openApp(app.packageName),
      child: Card(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (app.icon != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Image.memory(
                  app.icon!,
                  width: 50,
                  height: 50,
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(4.0),
              child: Text(
                app.appName,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const SearchBar({
    Key? key,
    required this.controller,
    required this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Colors.grey[600]!, width: 0.5),
        ),
      ),
      padding: const EdgeInsets.all(8.0),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: 'Search apps...',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
          filled: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}

class LauncherController extends GetxController with WidgetsBindingObserver {
  static const Duration cacheValidity = Duration(minutes: 15);
  final _debouncer = Debouncer(delay: const Duration(milliseconds: 300));

  final apps = <AppInfo>[].obs;
  final filteredApps = <AppInfo>[].obs;
  final isLoading = true.obs;
  final TextEditingController searchController = TextEditingController();
  late final ContentMonitor contentMonitor;

  static const platform = MethodChannel('com.nth.beluslauncher/system');

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _requestAccessibilityPermission();

    // Initialize the content monitor with enhanced error handling
    contentMonitor = ContentMonitor(
      textController: searchController,
      parentPhoneNumber: '+916380088036',
      onAlert: (message) {
        print("⚠️ CONTENT ALERT: $message");
        _showWarningDialog(message);
      },
      onError: (error) {
        print("❌ MONITOR ERROR: $error");
        Get.snackbar(
          'Monitoring Error',
          'Please restart the app: $error',
          backgroundColor: Colors.amber,
          colorText: Colors.black,
          duration: const Duration(seconds: 3),
        );
      },
      onInappropriateContent: () {
        print("🛑 INAPPROPRIATE CONTENT DETECTED - Closing YouTube app");
        _closeYouTubeApp();
      },
    );

    // Start monitoring with retry mechanism
    _startMonitoringWithRetry();

    // Initialize apps
    initializeApps();
  }

  Future<void> _requestAccessibilityPermission() async {
    if (Platform.isAndroid) {
      try {
        await platform.invokeMethod('requestAccessibilityPermission');
      } catch (e) {
        print('Error requesting accessibility permission: $e');
        Get.snackbar(
          'Permission Required',
          'Please enable Accessibility Service in Settings for full functionality.',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    }
  }

  Future<void> _startMonitoringWithRetry() async {
    bool started = false;
    int attempts = 0;

    while (!started && attempts < 3) {
      try {
        await contentMonitor.startMonitoring();
        started = true;
        print("✅ Content monitoring started successfully");
      } catch (e) {
        attempts++;
        print("⚠️ Failed to start monitoring (attempt $attempts): $e");
        await Future.delayed(Duration(seconds: 1));
      }
    }

    if (!started) {
      print("❌ Failed to start content monitoring after $attempts attempts");
    }
  }

  void _showWarningDialog(String message) {
    Get.dialog(
      AlertDialog(
        title: Text(
          'Warning!',
          style: TextStyle(
            color: Colors.red[700],
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.red[700],
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This content is not appropriate. The app will be closed.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Get.back(); // Close dialog
              _closeYouTubeApp(); // This will now redirect to WarningScreen
            },
            child: const Text(
              'OK',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        backgroundColor: Colors.grey[900],
      ),
      barrierDismissible: false,
    );
  }

  void _closeYouTubeApp() async {
    try {
      Get.offAll(() => const WarningScreen());
      // Attempt to return to home screen for Android 14 compatibility
      if (Platform.isAndroid) {
        final methodChannel = MethodChannel('com.nth.beluslauncher/system');
        await methodChannel.invokeMethod('goHome');
        print("Returned to home screen");
      }
    } catch (e) {
      print("Error closing YouTube app: $e");
      Get.offAll(() => const WarningScreen());
      // Fallback: Try to relaunch launcher
      await DeviceApps.openApp('com.nth.beluslauncher.belus_launcher');
    }
  }

  void filterApps(String query) {
    _debouncer.call(() {
      filteredApps.value = apps
          .where((app) => app.appName.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  Future<void> initializeApps() async {
    final cachedApps = await loadAppsFromCache();
    if (cachedApps != null && cachedApps.isNotEmpty) {
      apps.value = cachedApps;
      filteredApps.value = cachedApps;
      isLoading.value = false;
      return;
    }
    await loadApps();
  }

  Future<void> loadApps() async {
    try {
      final status = await Permission.requestInstallPackages.request();
      if (status.isDenied) return;

      final installedApps = await DeviceApps.getInstalledApplications(
        includeAppIcons: true,
        includeSystemApps: true,
        onlyAppsWithLaunchIntent: true,
      );

      final filteredInstalledApps = installedApps.where((app) {
        final allowedPackages = [
          'com.google.android.youtube',
          'com.instagram.android',
          'com.google.android.apps.youtube.music',
        ];

        if (allowedPackages.contains(app.packageName)) return true;

        return !app.packageName.startsWith('com.android.') &&
            !app.packageName.startsWith('com.google.android.inputmethod') &&
            !app.packageName.startsWith('com.sec.android') &&
            app.packageName != 'android';
      }).toList();

      final myApps = filteredInstalledApps
          .map((app) => AppInfo.fromApplication(app))
          .toList()
        ..sort((a, b) => a.appName.compareTo(b.appName));

      apps.value = myApps;
      filteredApps.value = myApps;
      await cacheApps(myApps);
    } catch (e) {
      print('Error loading apps: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<List<AppInfo>?> loadAppsFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('cachedApps');
      final cacheTimeString = prefs.getString('cacheTimestamp');

      if (jsonString == null || cacheTimeString == null) return null;

      final cacheTime = DateTime.parse(cacheTimeString);
      if (DateTime.now().difference(cacheTime) > cacheValidity) return null;

      final jsonList = json.decode(jsonString) as List;
      return jsonList.map((json) => AppInfo.fromJson(json)).toList();
    } catch (e) {
      print('Error loading from cache: $e');
      return null;
    }
  }

  Future<void> cacheApps(List<AppInfo> apps) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = apps.map((app) => app.toJson()).toList();
      await prefs.setString('cachedApps', json.encode(jsonList));
      await prefs.setString('cacheTimestamp', DateTime.now().toIso8601String());
    } catch (e) {
      print('Error caching apps: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && apps.isEmpty) {
      loadApps();
    }
  }

  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    searchController.dispose();
    contentMonitor.dispose();
    super.onClose();
  }
}

class AppInfo {
  final String appName;
  final String packageName;
  final Uint8List? icon;

  AppInfo({
    required this.appName,
    required this.packageName,
    this.icon,
  });

  factory AppInfo.fromApplication(Application app) {
    return AppInfo(
      appName: app.appName,
      packageName: app.packageName,
      icon: app is ApplicationWithIcon ? app.icon : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'appName': appName,
      'packageName': packageName,
      'icon': icon != null ? base64Encode(icon!) : null,
    };
  }

  factory AppInfo.fromJson(Map<String, dynamic> json) {
    return AppInfo(
      appName: json['appName'] as String,
      packageName: json['packageName'] as String,
      icon: json['icon'] != null ? base64Decode(json['icon']) : null,
    );
  }
}

class Debouncer {
  final Duration delay;
  Timer? _timer;

  Debouncer({required this.delay});

  void call(void Function() callback) {
    _timer?.cancel();
    _timer = Timer(delay, callback);
  }
}

class DigitalClock extends StatefulWidget {
  const DigitalClock({Key? key}) : super(key: key);

  @override
  DigitalClockState createState() => DigitalClockState();
}

class DigitalClockState extends State<DigitalClock> {
  late Timer _timer;
  late String _currentTime;

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _updateTime() {
    if (mounted) {
      setState(() {
        _currentTime = DateFormat('hh:mm:ss a').format(DateTime.now());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _currentTime,
      style: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        fontFamily: 'RobotoMono',
        letterSpacing: 2.0,
        shadows: [
          Shadow(
            blurRadius: 5.0,
            color: Colors.black,
            offset: Offset(2.0, 2.0),
          ),
        ],
      ),
    );
  }
}

class WarningScreen extends StatelessWidget {
  const WarningScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.red[700],
                size: 80,
              ),
              const SizedBox(height: 24),
              Text(
                'Content Warning',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.red[700],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                ' ⚠️ Inappropriate content was detected. '
                    'This app has been closed for your safety.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  // Navigate back to the launcher home
                  Get.offAll(() => const LauncherHome());
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Return to Home',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}