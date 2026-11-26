import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'kosmate_logo.dart';

class KosMateAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showLogo;
  final bool showBackButton;
  final List<Widget>? actions;

  const KosMateAppBar({
    super.key,
    this.title = 'KosMate',
    this.showLogo = true,
    this.showBackButton = false,
    this.actions,
  });

  @override
  Size get preferredSize => const Size.fromHeight(60.0);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.primaryColor,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: 60.0,
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              if (showBackButton) ...[
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.maybePop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
              ],
              if (showLogo) ...[
                const KosMateLogo(size: 28, color: Colors.white),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              ...?actions,
            ],
          ),
        ),
      ),
    );
  }
}
