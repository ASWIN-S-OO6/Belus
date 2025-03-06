// import 'package:get/get.dart';
// import 'package:device_apps/device_apps.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'dart:convert';
//
// import 'main.dart';
//
// class AppController extends GetxController {
//   final RxList<MyApplication> apps = <MyApplication>[].obs;
//   final RxList<MyApplication> filteredApps = <MyApplication>[].obs;
//   final RxBool isLoading = true.obs;
//   static const Duration cacheValidity = Duration(minutes: 15);
//
//   @override
//   void onInit() {
//     super.onInit();
//     loadState(); // Load state when the controller is initialized
//     initializeApps();
//   }
//
//   Future<void> initializeApps() async {
//     final cachedApps = await loadAppsFromCache();
//     if (cachedApps != null && cachedApps.isNotEmpty) {
//       apps.value = cachedApps;
//       filteredApps.value = cachedApps;
//       isLoading.value = false;
//     }
//     await loadApps();
//   }
//
//   Future<void> loadApps() async {
//     try {
//       List<MyApplication> myApps = await loadAppsInBackground();
//       if (myApps.isNotEmpty) {
//         apps.value = myApps;
//         filteredApps.value = myApps;
//         await cacheApps(myApps);
//         saveState(); // Save state after loading apps
//       }
//     } catch (error) {
//       print('Error loading apps: $error');
//     } finally {
//       isLoading.value = false;
//     }
//   }
//
//   Future<List<MyApplication>?> loadAppsFromCache() async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       final String? jsonString = prefs.getString('cachedApps');
//       final String? cacheTimeString = prefs.getString('cacheTimestamp');
//
//       if (jsonString == null || cacheTimeString == null) return null;
//
//       final cacheTime = DateTime.parse(cacheTimeString);
//       if (DateTime.now().difference(cacheTime) > cacheValidity) return null;
//
//       final List<dynamic> jsonList = json.decode(jsonString);
//       return jsonList.map((json) => MyApplication.fromJson(json)).toList();
//     } catch (e) {
//       print('Error loading from cache: $e');
//       return null;
//     }
//   }
//
//   Future<void> cacheApps(List<MyApplication> apps) async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       final jsonList = apps.map((app) => app.toJson()).toList();
//       await prefs.setString('cachedApps', json.encode(jsonList));
//       await prefs.setString('cacheTimestamp', DateTime.now().toIso8601String());
//     } catch (e) {
//       print('Error caching apps: $e');
//     }
//   }
//
//   void filterApps(String query) {
//     filteredApps.value = apps
//         .where((app) => app.appName.toLowerCase().contains(query.toLowerCase()))
//         .toList();
//     saveState(); // Save state after filtering apps
//   }
//
//   void launchApp(MyApplication app) async {
//     await DeviceApps.openApp(app.packageName);
//   }
//
//   // Save the current state of filtered apps
//   Future<void> saveState() async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       final List<Map<String, dynamic>> jsonList =
//       filteredApps.map((app) => app.toJson()).toList();
//       final String jsonString = json.encode(jsonList);
//       await prefs.setString('filteredAppsState', jsonString);
//     } catch (e) {
//       print('Error saving filtered apps state: $e');
//     }
//   }
//
//   // Load the saved state of filtered apps
//   Future<void> loadState() async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       final String? jsonString = prefs.getString('filteredAppsState');
//       if (jsonString != null) {
//         final List<dynamic> jsonList = json.decode(jsonString);
//         filteredApps.value =
//             jsonList.map((json) => MyApplication.fromJson(json)).toList();
//       }
//     } catch (e) {
//       print('Error loading filtered apps state: $e');
//     }
//   }
//
//   Future<List<MyApplication>> loadAppsInBackground() async {
//     bool hasPermission = await Permission.requestInstallPackages.isGranted;
//     if (!hasPermission) {
//       hasPermission = await Permission.requestInstallPackages.request().isGranted;
//     }
//
//     if (!hasPermission) {
//       // Handle the case where the user denies the permission.
//       return <MyApplication>[]; // Return an empty list or handle the error as needed.
//     }
//
//     List<Application> apps = await DeviceApps.getInstalledApplications(
//       includeAppIcons: true,
//       includeSystemApps: true,
//       onlyAppsWithLaunchIntent: true,
//     );
//
//     return apps.map((app) => MyApplication(
//       appName: app.appName,
//       packageName: app.packageName,
//       apkFilePath: app.apkFilePath,
//       versionName: app.versionName,
//       versionCode: app.versionCode,
//       dataDir: app.dataDir,
//       systemApp: app.systemApp,
//       installTimeMillis: app.installTimeMillis,
//       updateTimeMillis: app.updateTimeMillis,
//       category: app.category,
//       icon: app is ApplicationWithIcon ? app.icon : null,
//     )).toList();
//   }
// }