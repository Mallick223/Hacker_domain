import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'auth_gate.dart';

class VideoSplashScreen extends StatefulWidget {
  const VideoSplashScreen({super.key});

  @override
  State<VideoSplashScreen> createState() => _VideoSplashScreenState();
}

class _VideoSplashScreenState extends State<VideoSplashScreen> {
  static const bool _enableSplashVideo = false;

  VideoPlayerController? _controller;
  Timer? _splashTimer;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    if (kIsWeb || !_enableSplashVideo) {
      _splashTimer = Timer(const Duration(seconds: 2), _goNext);
    } else {
      // On Android/iOS: play the mp4 splash video.
      _controller = VideoPlayerController.asset('assets/videos/logo.mp4')
        ..initialize().then((_) {
          setState(() {});
          _controller!.play();
        });

      _controller!.addListener(() {
        final value = _controller!.value;
        if (!_navigated &&
            value.isInitialized &&
            value.position >= value.duration &&
            !value.isPlaying) {
          _navigated = true;
          _goNext();
        }
      });
    }
  }

  void _goNext() {
    if (_navigated && !kIsWeb) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AuthGate()),
    );
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: kIsWeb || !_enableSplashVideo
            ? Image.asset('assets/splash_logo.png', width: 180)
            : (_controller != null && _controller!.value.isInitialized
                ? AspectRatio(
                    aspectRatio: _controller!.value.aspectRatio,
                    child: VideoPlayer(_controller!),
                  )
                : const CircularProgressIndicator()),
      ),
    );
  }
}