import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The actual WhatsApp logo glyph, so anywhere the app refers to WhatsApp it
/// reads unmistakably as WhatsApp (not a generic chat icon). Tinted to [color]
/// so it sits naturally inside the app's coloured badges and buttons.
class WhatsappGlyph extends StatelessWidget {
  final double size;
  final Color color;

  const WhatsappGlyph({super.key, required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/whatsapp.svg',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}
