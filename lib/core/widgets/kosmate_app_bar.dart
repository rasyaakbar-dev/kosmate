import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'kosmate_logo.dart';

class KosMateAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showLogo;
  final bool showBackButton;
  final bool showHelp;
  final IconData actionIcon;
  final String helpTitle;
  final String helpMessage;
  final VoidCallback? onHelpPressed;
  final VoidCallback? onActionPressed;

  const KosMateAppBar({
    super.key,
    this.title = 'KosMate',
    this.showLogo = true,
    this.showBackButton = false,
    this.showHelp = true,
    this.actionIcon = Icons.help_outline_rounded,
    this.helpTitle = 'KosMate Help',
    this.helpMessage = 'KosMate is your smart boarding house management solution. Need help or have questions? Contact support at support@kosmate.app.',
    this.onHelpPressed,
    this.onActionPressed,
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
              if (showHelp)
                IconButton(
                  icon: Icon(actionIcon, color: Colors.white, size: 26),
                  onPressed:
                      onActionPressed ??
                      onHelpPressed ??
                      () {
                        if (actionIcon == Icons.settings_outlined) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('App Settings & Preferences'),
                            ),
                          );
                        } else {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text(helpTitle),
                              content: Text(helpMessage),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('OK'),
                                ),
                              ],
                            ),
                          );
                        }
                      },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
