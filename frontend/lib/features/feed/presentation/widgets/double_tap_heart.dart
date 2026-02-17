import 'package:flutter/material.dart';

class DoubleTapHeart extends StatefulWidget {
  final Widget child;
  final VoidCallback onDoubleTap;

  const DoubleTapHeart({
    super.key,
    required this.child,
    required this.onDoubleTap,
  });

  @override
  State<DoubleTapHeart> createState() => _DoubleTapHeartState();
}

class _DoubleTapHeartState extends State<DoubleTapHeart> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  
  // Store the position of the tap
  Offset? _tapPosition;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    
    // Scale up quickly
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    
    // Fade out at the end
    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.5, 1.0)),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) {
          setState(() {
            _isAnimating = false;
            _tapPosition = null;
          });
          _controller.reset();
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDoubleTapDown(TapDownDetails details) {
    if (mounted) {
      setState(() {
        _tapPosition = details.localPosition;
        _isAnimating = true;
      });
      _controller.forward();
      widget.onDoubleTap();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // We use onDoubleTapDown to get the exact coordinates
      onDoubleTapDown: _handleDoubleTapDown,
      // We also need onDoubleTap callback for the gesture to be recognized as a double tap
      onDoubleTap: () {}, 
      child: Stack(
        alignment: Alignment.center,
        children: [
          widget.child,
          if (_isAnimating && _tapPosition != null)
            Positioned(
              left: _tapPosition!.dx - 40, // Center the 80px icon
              top: _tapPosition!.dy - 40,
              child: FadeTransition(
                opacity: _opacityAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: const Icon(
                    Icons.favorite,
                    color: Colors.white,
                    size: 80,
                    shadows: [
                      Shadow(
                        color: Colors.black26,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      )
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
