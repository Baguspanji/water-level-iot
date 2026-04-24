import 'package:flutter/material.dart';
import '../services/sensor_status_service.dart';
import 'detail_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    sensorStatusService.addListener(_onUpdate);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    sensorStatusService.removeListener(_onUpdate);
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  bool get _hasData => sensorStatusService.readings.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: _hasData ? _buildStatus(context) : _buildWaiting(context),
      ),
    );
  }

  // ── Waiting State ──────────────────────────────────────────────────────────

  Widget _buildWaiting(BuildContext context) {
    final status = sensorStatusService.connectionStatus;
    final isConnected = status == ConnectionStatus.connected;
    final statusLabel = switch (status) {
      ConnectionStatus.waiting => 'Menghubungkan…',
      ConnectionStatus.connected => 'Terhubung — menunggu data',
      ConnectionStatus.disconnected => 'Koneksi terputus',
    };
    final statusColor = switch (status) {
      ConnectionStatus.waiting => Colors.amber,
      ConnectionStatus.connected => Colors.greenAccent,
      ConnectionStatus.disconnected => Colors.redAccent,
    };

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0f2027), Color(0xFF203a43), Color(0xFF2c5364)],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 48),
            // App name
            const Text(
              'WarWar',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Water Level Monitoring',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withAlpha(120),
                letterSpacing: 1,
              ),
            ),
            const Spacer(),
            // Animated sensor icon
            ScaleTransition(
              scale: _pulseAnimation,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withAlpha(15),
                  border: Border.all(
                    color: Colors.white.withAlpha(30),
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.sensors,
                  size: 70,
                  color: Colors.white.withAlpha(150),
                ),
              ),
            ),
            const SizedBox(height: 40),
            const Text(
              'Menunggu data sensor…',
              style: TextStyle(
                fontSize: 20,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Data akan muncul otomatis saat\nserver mengirim status.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withAlpha(90),
                height: 1.5,
              ),
            ),
            const Spacer(),
            // Connection indicator
            _ConnectionChip(
              label: statusLabel,
              color: statusColor,
              isConnected: isConnected,
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ── Status State ───────────────────────────────────────────────────────────

  Widget _buildStatus(BuildContext context) {
    final isFlood = sensorStatusService.hasAlert;
    final alertCount = sensorStatusService.alertCount;
    final totalCount = sensorStatusService.totalCount;

    final bgColors = isFlood
        ? [const Color(0xFFB71C1C), const Color(0xFF7f0000)]
        : [const Color(0xFF1B5E20), const Color(0xFF003300)];
    final icon = isFlood ? Icons.flood : Icons.verified_rounded;
    final label = isFlood ? 'BANJIR' : 'AMAN';
    final subtitle = isFlood
        ? 'Terdeteksi level air tinggi!'
        : 'Semua sensor dalam kondisi normal.';

    final lastMsg = sensorStatusService.lastMessageAt;
    final timeStr = lastMsg != null
        ? '${lastMsg.hour.toString().padLeft(2, '0')}:${lastMsg.minute.toString().padLeft(2, '0')}:${lastMsg.second.toString().padLeft(2, '0')}'
        : '-';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: bgColors,
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            // Top bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Text(
                    'WarWar',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                  const Spacer(),
                  _LiveBadge(time: timeStr),
                ],
              ),
            ),
            const Spacer(flex: 2),
            // Main icon with pulse
            ScaleTransition(
              scale: _pulseAnimation,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withAlpha(20),
                  boxShadow: [
                    BoxShadow(
                      color: (isFlood ? Colors.red : Colors.green).withAlpha(
                        60,
                      ),
                      blurRadius: 60,
                      spreadRadius: 20,
                    ),
                  ],
                ),
                child: Container(
                  margin: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withAlpha(25),
                  ),
                  child: Icon(icon, size: 80, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 36),
            // Status label
            Text(
              label,
              style: const TextStyle(
                fontSize: 52,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 6,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withAlpha(200),
              ),
            ),
            const SizedBox(height: 20),
            // Sensor summary chips
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _InfoChip(icon: Icons.sensors, label: '$totalCount sensor'),
                const SizedBox(width: 12),
                _InfoChip(
                  icon: Icons.warning_amber_rounded,
                  label: '$alertCount alert',
                  isAlert: alertCount > 0,
                ),
              ],
            ),
            const Spacer(flex: 3),
            // Detail button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const DetailPage()),
                    );
                  },
                  icon: const Icon(Icons.bar_chart_rounded, size: 22),
                  label: const Text(
                    'Lihat Detail Sensor',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: isFlood
                        ? const Color(0xFFB71C1C)
                        : const Color(0xFF1B5E20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                    shadowColor: Colors.black38,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 36),
          ],
        ),
      ),
    );
  }
}

// ── Small Widgets ────────────────────────────────────────────────────────────

class _ConnectionChip extends StatelessWidget {
  const _ConnectionChip({
    required this.label,
    required this.color,
    required this.isConnected,
  });
  final String label;
  final Color color;
  final bool isConnected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(color: color.withAlpha(150), blurRadius: 6),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 13, color: color)),
        ],
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge({required this.time});
  final String time;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(20),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.greenAccent,
              boxShadow: [
                BoxShadow(
                  color: Colors.greenAccent.withAlpha(150),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'LIVE  $time',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white70,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    this.isAlert = false,
  });
  final IconData icon;
  final String label;
  final bool isAlert;

  @override
  Widget build(BuildContext context) {
    final color = isAlert ? Colors.redAccent.shade100 : Colors.white70;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 13, color: color)),
        ],
      ),
    );
  }
}
