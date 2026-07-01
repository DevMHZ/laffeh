import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The official four-colour Google "G" mark. Unlike [WhatsappGlyph] this is
/// deliberately NOT tinted — the colours themselves are what make it read as
/// "Google" at a glance, so a single-colour silhouette would lose that.
class GoogleGlyph extends StatelessWidget {
  final double size;

  const GoogleGlyph({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset('assets/google.svg', width: size, height: size);
  }
}
