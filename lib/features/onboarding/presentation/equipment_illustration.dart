import 'package:flutter/material.dart';
import '../../../shared/widgets/kora_ui.dart';

/// Small vector drawings: local, offline and consistent with the Kora palette.
class EquipmentIllustration extends StatelessWidget {
  const EquipmentIllustration({super.key, required this.code});
  final String code;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(child: Container(
    width: 64, height: 64, decoration: BoxDecoration(color: const Color(0xFFF0F6D4), borderRadius: BorderRadius.circular(16)),
    child: CustomPaint(painter: _EquipmentPainter(code)),
  ));
}
class _EquipmentPainter extends CustomPainter {
  const _EquipmentPainter(this.code);
  final String code;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save(); canvas.scale(size.width / 64, size.height / 64);
    final stroke = Paint()..color = Kora.forest..strokeWidth = 3..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round..style = PaintingStyle.stroke;
    final fill = Paint()..color = Kora.sage;
    void line(double x, double y, double x2, double y2) => canvas.drawLine(Offset(x,y), Offset(x2,y2), stroke);
    void box(double x, double y, double w, double h) { final r = RRect.fromRectAndRadius(Rect.fromLTWH(x,y,w,h), const Radius.circular(3)); canvas.drawRRect(r, fill); canvas.drawRRect(r, stroke); }
    void circle(double x, double y, double r) { canvas.drawCircle(Offset(x,y),r,fill); canvas.drawCircle(Offset(x,y),r,stroke); }
    switch (code) {
      case 'dumbbell':
        line(10,32,54,32); box(13,22,9,20); box(42,22,9,20);
      case 'barbell': case 'olympic barbell': case 'ez barbell':
        if(code == 'ez barbell') { final p=Path()..moveTo(8,32)..lineTo(24,32)..lineTo(29,27)..lineTo(35,37)..lineTo(40,32)..lineTo(56,32); canvas.drawPath(p,stroke); } else { line(6,32,58,32); }
        box(12,17,7,30); box(45,17,7,30);
      case 'kettlebell':
        canvas.drawOval(const Rect.fromLTWH(23,10,18,20),stroke); circle(32,38,15); line(21,51,43,51);
      case 'band':
        canvas.drawOval(const Rect.fromLTWH(13,20,38,24),stroke); canvas.drawOval(const Rect.fromLTWH(18,25,28,14),stroke);
      case 'stability ball': case 'medicine ball': case 'bosu ball':
        if(code == 'bosu ball') { canvas.drawArc(const Rect.fromLTWH(12,23,40,40),3.14159,3.14159,true,fill); line(10,43,54,43); }
        else { circle(32,32,code == 'stability ball' ? 21 : 15); canvas.drawArc(const Rect.fromLTWH(23,12,18,40),-1.5,3,false,stroke); }
      case 'ab wheel':
        line(8,35,56,35); circle(32,35,15); canvas.drawOval(const Rect.fromLTWH(25,20,14,30),stroke);
      case 'rope':
        box(12,12,6,16); box(45,12,6,16); canvas.drawPath(Path()..moveTo(15,28)..cubicTo(3,60,60,60,48,28),stroke);
      case 'bench': case 'step platform': case 'plyo box':
        if(code=='plyo box') { box(15,20,34,32); line(15,20,24,12); line(24,12,54,12); line(54,12,49,20); line(54,12,54,44); line(49,52,54,44); }
        else { box(9,25,46,10); line(17,35,14,50); line(47,35,50,50); if(code=='step platform') { line(10,49,54,49); } }
      case 'pull-up bar':
        line(10,14,54,14); line(13,14,13,31); line(51,14,51,31); line(8,31,20,31); line(44,31,56,31);
      case 'suspension straps': case 'gymnastic rings':
        line(18,8,23,36); line(46,8,41,36); if(code=='gymnastic rings') { canvas.drawCircle(const Offset(23,44),8,stroke); canvas.drawCircle(const Offset(41,44),8,stroke); } else { line(23,36,14,49); line(14,49,30,49); line(30,49,23,36); line(41,36,34,49); line(34,49,50,49); line(50,49,41,36); }
      case 'parallel bars':
        line(10,24,40,18); line(23,35,54,28); line(10,24,10,50); line(40,18,40,44); line(23,35,23,55); line(54,28,54,48);
      case 'treadmill':
        box(9,43,43,9); line(46,43,39,17); line(39,17,53,17); box(33,10,17,9);
      case 'stationary bike':
        circle(22,42,12); line(22,42,40,34); line(40,34,44,18); line(38,18,50,18); line(30,37,25,23); line(18,23,31,23); line(12,55,48,55); line(40,34,45,55);
      case 'balance board':
        canvas.drawOval(const Rect.fromLTWH(9,24,46,15),fill); canvas.drawOval(const Rect.fromLTWH(9,24,46,15),stroke); canvas.drawArc(const Rect.fromLTWH(24,31,16,22),0,3.14159,false,stroke);
      case 'weighted':
        canvas.drawPath(Path()..moveTo(20,12)..lineTo(12,25)..lineTo(18,29)..lineTo(18,52)..lineTo(46,52)..lineTo(46,29)..lineTo(52,25)..lineTo(44,12)..lineTo(38,19)..lineTo(26,19)..close(),stroke); box(22,29,7,15);box(35,29,7,15);
      case 'landmine':
        box(9,47,18,6); line(18,47,47,16); circle(44,20,8);
      case 'sled machine':
        line(10,49,54,49); line(16,49,16,22); line(45,49,45,22); box(19,39,24,7); line(31,39,31,27);
      case 'cable': case 'smith machine': case 'leverage machine': case 'assisted': case 'captains chair':
        line(13,54,13,10);line(13,10,51,10);line(51,10,51,54);line(8,54,56,54);
        if(code=='cable') { line(24,10,24,36);circle(24,39,4);box(39,29,8,18); }
        else if(code=='smith machine') { line(10,29,54,29);box(15,23,6,12);box(43,23,6,12); }
        else { box(25,24,14,19);line(19,34,45,34);line(32,43,32,54); }
      case 'body weight':
        circle(32,15,6);line(32,21,32,38);line(18,26,46,26);line(32,38,20,53);line(32,38,44,53);
      default:
        box(13,25,38,26);canvas.drawArc(const Rect.fromLTWH(23,14,18,20),3.14159,3.14159,false,stroke);line(13,35,51,35);
    }
    canvas.restore();
  }
  @override
  bool shouldRepaint(_EquipmentPainter old) => old.code != code;
}
