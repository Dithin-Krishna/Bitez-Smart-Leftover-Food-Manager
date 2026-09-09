import 'package:flutter/material.dart';
import '../services/api_service.dart';

/// A sleek connection status dot indicating Render server readiness.
/// - 🟡 Yellow: Connecting / Waking up Render from idle
/// - 🟢 Green: Server connected and ready for login
/// - 🔴 Red: Cannot connect to server
class ServerStatusIndicator extends StatefulWidget {
  final bool showLabel;
  final VoidCallback? onRetry;

  const ServerStatusIndicator({
    super.key,
    this.showLabel = true,
    this.onRetry,
  });

  @override
  State<ServerStatusIndicator> createState() => _ServerStatusIndicatorState();
}

class _ServerStatusIndicatorState extends State<ServerStatusIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ServerConnectionStatus>(
      valueListenable: ApiService.connectionStatus,
      builder: (context, status, _) {
        Color dotColor;
        String label;
        String tooltip;

        switch (status) {
          case ServerConnectionStatus.connecting:
            dotColor = const Color(0xFFF59E0B); // Amber / Yellow
            label = 'Connecting to server...';
            tooltip = 'Connecting / waking up server on Render...';
            break;
          case ServerConnectionStatus.connected:
            dotColor = const Color(0xFF10B981); // Emerald / Green
            label = 'Server connected';
            tooltip = 'Online & ready';
            break;
          case ServerConnectionStatus.disconnected:
            dotColor = const Color(0xFFEF4444); // Red
            label = 'Server offline (Tap to retry)';
            tooltip = 'Could not reach server. Tap to retry.';
            break;
        }

        final isConnecting = status == ServerConnectionStatus.connecting;

        Widget dot = AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            final scale = isConnecting ? _pulseAnimation.value : 1.0;
            final glowOpacity = isConnecting ? (0.2 + 0.4 * _pulseAnimation.value) : 0.4;
            return Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dotColor,
                boxShadow: [
                  BoxShadow(
                    color: dotColor.withValues(alpha: glowOpacity),
                    blurRadius: 6 * scale,
                    spreadRadius: 2 * scale,
                  ),
                ],
              ),
            );
          },
        );

        return Tooltip(
          message: tooltip,
          child: InkWell(
            onTap: () {
              ApiService.instance.checkHealth();
              if (widget.onRetry != null) widget.onRetry!();
            },
            borderRadius: BorderRadius.circular(20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: dotColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: dotColor.withValues(alpha: 0.35),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  dot,
                  if (widget.showLabel) ...[
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: dotColor,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
