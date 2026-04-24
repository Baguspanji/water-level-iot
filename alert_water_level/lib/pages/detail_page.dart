import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/sensor_status_service.dart';

class DetailPage extends StatefulWidget {
  const DetailPage({super.key});

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  @override
  void initState() {
    super.initState();
    sensorStatusService.addListener(_onUpdate);
  }

  @override
  void dispose() {
    sensorStatusService.removeListener(_onUpdate);
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final readings = sensorStatusService.readings;
    final alertCount = sensorStatusService.alertCount;
    final totalCount = sensorStatusService.totalCount;
    final safeCount = totalCount - alertCount;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── AppBar ──
          SliverAppBar(
            expandedHeight: 140,
            pinned: true,
            elevation: 2,
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF1a3a5c),
            surfaceTintColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 24, bottom: 16),
              title: const Text(
                'Detail Sensor',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  letterSpacing: 0.5,
                  color: Color(0xFF1a3a5c),
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFE3F2FD), Colors.white],
                  ),
                ),
                child: const Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: EdgeInsets.only(right: 24),
                    child: Icon(
                      Icons.water_drop_rounded,
                      size: 64,
                      color: Color(0xFFBBDEFB),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Summary Cards ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
              child: Row(
                children: [
                  _SummaryCard(
                    icon: Icons.sensors_rounded,
                    label: 'Total',
                    value: '$totalCount',
                    gradient: const [Color(0xFF2c5364), Color(0xFF203a43)],
                  ),
                  const SizedBox(width: 10),
                  _SummaryCard(
                    icon: Icons.check_circle_rounded,
                    label: 'Aman',
                    value: '$safeCount',
                    gradient: const [Color(0xFF2E7D32), Color(0xFF1B5E20)],
                  ),
                  const SizedBox(width: 10),
                  _SummaryCard(
                    icon: Icons.warning_rounded,
                    label: 'Bahaya',
                    value: '$alertCount',
                    gradient: alertCount > 0
                        ? const [Color(0xFFc62828), Color(0xFFb71c1c)]
                        : const [Color(0xFF9E9E9E), Color(0xFF757575)],
                  ),
                ],
              ),
            ),
          ),

          // ── Sensor Cards ──
          if (readings.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.sensors_off_rounded,
                      size: 64,
                      color: Color(0xFFBDBDBD),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Belum ada data sensor',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF9E9E9E),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Data akan muncul saat server mengirim status.',
                      style: TextStyle(fontSize: 13, color: Color(0xFFBDBDBD)),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
              sliver: SliverList.builder(
                itemCount: readings.length,
                itemBuilder: (context, index) {
                  final reading = readings.values.elementAt(index);
                  return _SensorCard(reading: reading);
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ── Summary Card ─────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.gradient,
  });
  final IconData icon;
  final String label;
  final String value;
  final List<Color> gradient;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: gradient.first.withAlpha(50),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white.withAlpha(200), size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white.withAlpha(180),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sensor Card ──────────────────────────────────────────────────────────────

class _SensorCard extends StatelessWidget {
  const _SensorCard({required this.reading});
  final SensorReading reading;

  @override
  Widget build(BuildContext context) {
    final isAlert = reading.isAlert;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isAlert ? const Color(0xFFB71C1C) : const Color(0xFF90A4AE))
                .withAlpha(isAlert ? 30 : 15),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Header ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isAlert
                    ? [const Color(0xFFFFF5F5), const Color(0xFFFFEBEE)]
                    : [const Color(0xFFF1F8E9), const Color(0xFFE8F5E9)],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                // Device icon
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: isAlert
                        ? const Color(0xFFB71C1C).withAlpha(20)
                        : const Color(0xFF2E7D32).withAlpha(20),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    isAlert ? Icons.flood_rounded : Icons.water_drop_rounded,
                    color: isAlert
                        ? const Color(0xFFB71C1C)
                        : const Color(0xFF2E7D32),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                // Device info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reading.deviceId,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1a1a1a),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 12,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatTime(reading.receivedAt),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Status badge
                _StatusBadge(isAlert: isAlert),
              ],
            ),
          ),

          // ── Sensor Values ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
            child: Row(
              children: [
                Expanded(
                  child: _SensorGaugeCard(
                    label: 'Sensor Min',
                    value: reading.sensorMin,
                    status: reading.sensorMinStatus,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SensorGaugeCard(
                    label: 'Sensor Max',
                    value: reading.sensorMax,
                    status: reading.sensorMaxStatus,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

// ── Status Badge ─────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isAlert});
  final bool isAlert;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isAlert
              ? [const Color(0xFFEF5350), const Color(0xFFC62828)]
              : [const Color(0xFF66BB6A), const Color(0xFF2E7D32)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isAlert ? Colors.red : Colors.green).withAlpha(40),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isAlert ? Icons.warning_rounded : Icons.check_circle_rounded,
            size: 14,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            isAlert ? 'BAHAYA' : 'AMAN',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sensor Gauge Card ────────────────────────────────────────────────────────

class _SensorGaugeCard extends StatelessWidget {
  const _SensorGaugeCard({
    required this.label,
    required this.value,
    required this.status,
  });
  final String label;
  final double value;
  final String status;

  @override
  Widget build(BuildContext context) {
    final isHigh = status == 'HIGH';
    final color = isHigh ? const Color(0xFFB71C1C) : const Color(0xFF2E7D32);
    final bgColor = isHigh ? const Color(0xFFFFF5F5) : const Color(0xFFF1F8E9);
    final fraction = (value / 1023).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(30)),
      ),
      child: Column(
        children: [
          // Label
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 12),
          // Circular gauge
          SizedBox(
            width: 80,
            height: 80,
            child: CustomPaint(
              painter: _ArcGaugePainter(
                fraction: fraction,
                color: color,
                bgColor: color.withAlpha(25),
              ),
              child: Center(
                child: Text(
                  value.toStringAsFixed(0),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Status chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Arc Gauge Painter ────────────────────────────────────────────────────────

class _ArcGaugePainter extends CustomPainter {
  _ArcGaugePainter({
    required this.fraction,
    required this.color,
    required this.bgColor,
  });
  final double fraction;
  final Color color;
  final Color bgColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;
    const startAngle = math.pi * 0.75; // 135°
    const sweepTotal = math.pi * 1.5; // 270°

    // Background arc
    final bgPaint = Paint()
      ..color = bgColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepTotal,
      false,
      bgPaint,
    );

    // Value arc
    final valuePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepTotal * fraction,
      false,
      valuePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ArcGaugePainter old) =>
      old.fraction != fraction || old.color != color;
}
