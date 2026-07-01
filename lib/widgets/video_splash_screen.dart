import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:video_player/video_player.dart';

/// Écran d'intro vidéo affiché juste après le splash natif (Tranoo Pro).
class VideoSplashScreen extends StatefulWidget {
  const VideoSplashScreen({
    super.key,
    required this.onFinished,
    this.assetPath = 'assets/videos/logo_animation.mp4',
  });

  final VoidCallback onFinished;
  final String assetPath;

  @override
  State<VideoSplashScreen> createState() => _VideoSplashScreenState();
}

class _VideoSplashScreenState extends State<VideoSplashScreen> {
  VideoPlayerController? _controller;
  bool _hasFinished = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    final controller = VideoPlayerController.asset(widget.assetPath);
    _controller = controller;

    try {
      await controller.initialize();
      if (!mounted) return;

      await controller.setLooping(false);
      await controller.setVolume(1.0);

      controller.addListener(_onVideoTick);

      setState(() {});
      FlutterNativeSplash.remove();
      await controller.play();
    } catch (_) {
      _finish();
    }
  }

  void _onVideoTick() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _hasFinished) {
      return;
    }

    final position = controller.value.position;
    final duration = controller.value.duration;
    if (duration > Duration.zero &&
        position >= duration - const Duration(milliseconds: 200)) {
      _finish();
    }
  }

  void _finish() {
    if (_hasFinished || !mounted) return;
    _hasFinished = true;
    _controller?.removeListener(_onVideoTick);
    widget.onFinished();
  }

  @override
  void dispose() {
    _controller?.removeListener(_onVideoTick);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return Scaffold(
      backgroundColor: Colors.white,
      body: controller != null && controller.value.isInitialized
          ? SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: controller.value.size.width,
                  height: controller.value.size.height,
                  child: VideoPlayer(controller),
                ),
              ),
            )
          : const ColoredBox(color: Colors.white),
    );
  }
}
