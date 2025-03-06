import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';

class ContentMonitor {
  static const String SERVER_URL = 'https://cd6c3789642dc0.lhr.life'; // Your working tunnel URL
  static const String YOUTUBE_API_KEY = 'AIzaSyD3NxnjvcTGkUGk9Clt-5f08MFRmzX_v5Y';
  static const String YOUTUBE_API_URL = 'https://www.googleapis.com/youtube/v3';
  static const Duration CHECK_INTERVAL = Duration(milliseconds: 500);
  static const Duration HTTP_TIMEOUT = Duration(seconds: 10); // Timeout duration

  Timer? _monitorTimer;
  bool _isMonitoring = false;
  final TextEditingController _textController;
  String? _lastAnalyzedText;
  String? _currentVideoId;
  final String _parentPhoneNumber;
  final void Function(String message)? _onAlert;
  final void Function(String error)? _onError;
  final void Function()? _onInappropriateContent;

  static const platform = MethodChannel('com.nth.beluslauncher/system');

  ContentMonitor({
    required TextEditingController textController,
    required String parentPhoneNumber,
    void Function(String message)? onAlert,
    void Function(String error)? onError,
    void Function()? onInappropriateContent,
  })  : _textController = textController,
        _parentPhoneNumber = parentPhoneNumber,
        _onAlert = onAlert,
        _onError = onError,
        _onInappropriateContent = onInappropriateContent;

  bool get isMonitoring => _isMonitoring;

  Future<void> sendSMSToParent(String videoTitle) async {
    try {
      print('Attempting to send SMS to parent: $_parentPhoneNumber');
      final response = await http
          .post(
        Uri.parse('$SERVER_URL/send-sms'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'phoneNumber': _parentPhoneNumber,
          'message': 'Alert: Your child attempted to watch inappropriate content: $videoTitle',
        }),
      )
          .timeout(HTTP_TIMEOUT, onTimeout: () {
        throw TimeoutException('SMS request timed out');
      });

      if (response.statusCode == 200) {
        print('SMS sent successfully');
      } else {
        print('Failed to send SMS: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error sending SMS: $e');
    }
  }

  String? extractVideoId(String text) {
    try {
      final patterns = [
        RegExp(r'(?:youtube\.com\/watch\?v=|youtu\.be\/|youtube\.com\/shorts\/)([^&\n?#]+)'),
        RegExp(r'youtube\.com\/watch.*[\?&]v=([^&\n?#]+)'),
        RegExp(r'youtube\.com\/embed\/([^&\n?#]+)'),
        RegExp(r'youtube:\/\/([^&\n?#]+)'),
        RegExp(r'vnd\.youtube:([^&\n?#]+)'),
      ];

      for (final pattern in patterns) {
        final match = pattern.firstMatch(text);
        if (match != null && match.groupCount >= 1) {
          return match.group(1);
        }
      }

      if (text.length == 11 && RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(text)) {
        return text;
      }

      return null;
    } catch (e) {
      print('Error extracting video ID: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchYouTubeVideoDetails(String videoId) async {
    try {
      print('Fetching details for video ID: $videoId');
      final response = await http
          .get(
        Uri.parse('$YOUTUBE_API_URL/videos?part=snippet,contentDetails&id=$videoId&key=$YOUTUBE_API_KEY'),
      )
          .timeout(HTTP_TIMEOUT, onTimeout: () {
        throw TimeoutException('YouTube API request timed out');
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['items'] != null && data['items'].isNotEmpty) {
          print('Successfully fetched video details');
          return data['items'][0];
        } else {
          print('No items returned from YouTube API');
        }
      } else {
        print('YouTube API Error: ${response.statusCode} - ${response.body}');
      }

      return null;
    } catch (e) {
      print('Error fetching YouTube details: $e');
      return null;
    }
  }

  Future<String?> searchYouTubeVideoId(String title) async {
    try {
      final response = await http
          .get(
        Uri.parse(
          '$YOUTUBE_API_URL/search?part=snippet&q=${Uri.encodeQueryComponent(title)}&type=video&maxResults=1&key=$YOUTUBE_API_KEY',
        ),
      )
          .timeout(HTTP_TIMEOUT, onTimeout: () {
        throw TimeoutException('YouTube Search API request timed out');
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['items'] != null && data['items'].isNotEmpty) {
          return data['items'][0]['id']['videoId'];
        }
      }
      print('Search API Error: ${response.statusCode} - ${response.body}');
      return null;
    } catch (e) {
      print('Error searching YouTube: $e');
      return null;
    }
  }

  Future<void> analyzeContent(String title, String description) async {
    try {
      print('Analyzing content - Title: $title');

      final testCase = "The Sadness (2021) : Killing in Train Scene | Extreme Violence | Taiwanese Horror Film | e-Talkies";
      if (title.toLowerCase().contains("killing") && title.toLowerCase().contains("extreme violence")) {
        print("Test case detected! This should be flagged.");
      }

      final response = await http
          .post(
        Uri.parse('$SERVER_URL/analyze-youtube-content'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'title': title,
          'description': description,
          'isYouTubeVideo': true,
        }),
      )
          .timeout(HTTP_TIMEOUT, onTimeout: () {
        throw TimeoutException('Content analysis request timed out');
      });

      print('Server response status: ${response.statusCode}');
      print('Server response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Is inappropriate: ${data['isInappropriate']}');

        if (data['isInappropriate'] == true) {
          print('Inappropriate content detected! Sending alert...');
          await sendSMSToParent(title);
          _onAlert?.call('Warning: Inappropriate content detected');
          _onInappropriateContent?.call();
          clearState();
        }
      } else {
        print('Server error: ${response.statusCode} - ${response.body}');
        _onError?.call('Server response error: ${response.statusCode}');
      }
    } catch (e) {
      print('Analysis error: $e');
      _onError?.call('Analysis error: $e');
    }
  }

  Future<String?> getForegroundApp() async {
    try {
      return await platform.invokeMethod('getForegroundApp');
    } catch (e) {
      print('Error getting foreground app: $e');
      return null;
    }
  }

  Future<String?> getCurrentVideoInfo() async {
    try {
      final videoInfo = await platform.invokeMethod('getCurrentVideoInfo') as String?;
      return videoInfo;
    } catch (e) {
      print('Error getting current video info: $e');
      return null;
    }
  }

  Future<void> startMonitoring() async {
    if (_isMonitoring) return;

    try {
      print('Starting content monitoring...');
      _monitorTimer?.cancel();

      _monitorTimer = Timer.periodic(CHECK_INTERVAL, (_) async {
        final foregroundApp = await getForegroundApp();
        if (foregroundApp == 'com.google.android.youtube') {
          print('YouTube detected in foreground');
          final videoInfo = await getCurrentVideoInfo();
          if (videoInfo != null && videoInfo != _lastAnalyzedText) {
            _lastAnalyzedText = videoInfo;
            print('Current video info: $videoInfo');
            final videoId = extractVideoId(videoInfo) ?? await searchYouTubeVideoId(videoInfo);
            if (videoId != null && videoId != _currentVideoId) {
              _currentVideoId = videoId;
              final videoDetails = await fetchYouTubeVideoDetails(videoId);
              if (videoDetails != null) {
                final title = videoDetails['snippet']['title'] ?? '';
                final description = videoDetails['snippet']['description'] ?? '';
                print('Analyzing video - Title: $title');
                await analyzeContent(title, description);
              } else {
                print('Could not fetch video details, using raw info');
                await analyzeContent(videoInfo, '');
              }
            }
          }
        }

        final text = _textController.text;
        if (text.isNotEmpty && text != _lastAnalyzedText) {
          _lastAnalyzedText = text;
          print('Monitoring text: $text');

          if (text.toLowerCase().contains("the sadness") &&
              text.toLowerCase().contains("killing") &&
              text.toLowerCase().contains("extreme violence")) {
            print("Test case detected directly in search!");
            await analyzeContent(text, "");
            return;
          }

          final videoId = extractVideoId(text);
          if (videoId != null && videoId != _currentVideoId) {
            _currentVideoId = videoId;
            print('Detected video ID: $videoId');

            final videoDetails = await fetchYouTubeVideoDetails(videoId);
            if (videoDetails != null) {
              final snippet = videoDetails['snippet'];
              final title = snippet['title'] ?? '';
              final description = snippet['description'] ?? '';
              print('Analyzing video - Title: $title');
              await analyzeContent(title, description);
            } else {
              print('Could not fetch video details. Analyzing text directly.');
              await analyzeContent(text, "");
            }
          } else if (videoId == null && text.length > 15) {
            print('No video ID found, but analyzing text as potential title');
            await analyzeContent(text, "");
          }
        }
      });

      _isMonitoring = true;
      print('Content monitoring started successfully');
    } catch (e) {
      print('Failed to start monitoring: $e');
      _onError?.call('Failed to start monitoring: $e');
      rethrow;
    }
  }

  void clearState() {
    _textController.clear();
    _lastAnalyzedText = '';
    _currentVideoId = null;
  }

  void stopMonitoring() {
    print('Stopping content monitoring');
    _monitorTimer?.cancel();
    _monitorTimer = null;
    _isMonitoring = false;
  }

  void dispose() {
    stopMonitoring();
  }
}