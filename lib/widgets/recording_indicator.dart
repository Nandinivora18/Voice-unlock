// recording_indicator.dart
// An animated microphone button that pulses while recording.
// Idle state: cyan mic icon.  Recording state: pulsing red circles.

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class RecordingIndicator extends StatefulWidget {
  final bool isRecording;
  final VoidCallback onTap;
  final double size;

  const RecordingIndicator({
    super.key,
    required this.isRecording,
    required this.onTap,
    this.size = 80,
  });

  @override
  State<RecordingIndicator> createState() => _RecordingIndicatorState();
}

class _RecordingIndicatorState extends State<RecordingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _opacityAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _scaleAnim = Tween<double>(begin: 1.0, end: 1.35).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _opacityAnim = Tween<double>(begin: 0.6, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color =
        widget.isRecording ? AppTheme.error : AppTheme.primary;
    final icon  =
        widget.isRecording ? Icons.stop_rounded : Icons.mic_rounded;

    return GestureDetector(
      onTap: widget.onTap,
      child: SizedBox(
        width: widget.size * 2,
        height: widget.size * 2,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Pulsing ring (visible only while recording)
            if (widget.isRecording)
              AnimatedBuilder(
                animation: _controller,
                builder: (_, __) => Transform.scale(
                  scale: _scaleAnim.value,
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.error
                          .withValues(alpha: _opacityAnim.value),
                    ),
                  ),
                ),
              ),
            // Main button
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.15),
                border: Border.all(color: color, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Icon(icon, color: color, size: widget.size * 0.45),
            ),
          ],
        ),
      ),
    );
  }
}
