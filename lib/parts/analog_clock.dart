import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

class AnalogClock extends StatefulWidget {
  const AnalogClock({super.key});

  @override
  AnalogClockState createState() => AnalogClockState();
}

class AnalogClockState extends State<AnalogClock> {
  DateTime _dateTime = DateTime.now();
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _dateTime = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            blurRadius: 8,
            offset: const Offset(0, 0),
            color: Colors.black.withOpacity(0.2),
          )
        ],
      ),
      child: CustomPaint(
        painter: ClockPainter(_dateTime),
      ),
    );
  }
}

class ClockPainter extends CustomPainter {
  final DateTime dateTime;

  ClockPainter(this.dateTime);

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final center = Offset(centerX, centerY);
    final radius = min(centerX, centerY);

    // Draw circle border
    final borderPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    canvas.drawCircle(center, radius - 4, borderPaint);

    // Draw clock face
    final facePaint = Paint()
      ..color = Colors.white;

    canvas.drawCircle(center, radius - 8, facePaint);

    // Draw hour markers
    final hourMarkerPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (int i = 0; i < 12; i++) {
      final angle = i * (pi * 2) / 12;
      final outerX = centerX + cos(angle) * (radius - 12);
      final outerY = centerY + sin(angle) * (radius - 12);
      final innerX = centerX + cos(angle) * (radius - 24);
      final innerY = centerY + sin(angle) * (radius - 24);

      canvas.drawLine(
        Offset(outerX, outerY),
        Offset(innerX, innerY),
        hourMarkerPaint,
      );
    }

    // Draw hour hand
    final hourHandPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final hourAngle = (dateTime.hour * 30 + dateTime.minute * 0.5) * pi / 180;
    final hourHandLength = radius * 0.5;
    final hourX = centerX + cos(hourAngle - pi / 2) * hourHandLength;
    final hourY = centerY + sin(hourAngle - pi / 2) * hourHandLength;

    canvas.drawLine(center, Offset(hourX, hourY), hourHandPaint);

    // Draw minute hand
    final minuteHandPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final minuteAngle = dateTime.minute * 6 * pi / 180;
    final minuteHandLength = radius * 0.7;
    final minuteX = centerX + cos(minuteAngle - pi / 2) * minuteHandLength;
    final minuteY = centerY + sin(minuteAngle - pi / 2) * minuteHandLength;

    canvas.drawLine(center, Offset(minuteX, minuteY), minuteHandPaint);

    // Draw second hand
    final secondHandPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final secondAngle = dateTime.second * 6 * pi / 180;
    final secondHandLength = radius * 0.8;
    final secondX = centerX + cos(secondAngle - pi / 2) * secondHandLength;
    final secondY = centerY + sin(secondAngle - pi / 2) * secondHandLength;

    canvas.drawLine(center, Offset(secondX, secondY), secondHandPaint);

    // Draw center point
    final centerPointPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, 4, centerPointPaint);
  }

  @override
  bool shouldRepaint(ClockPainter oldDelegate) {
    return oldDelegate.dateTime != dateTime;
  }
}