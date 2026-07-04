import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:schooldesk1/core/utils/extensions.dart';

/// WhatsApp-style chat wallpaper background.
class ChatWallpaperBackground extends StatelessWidget {
  final Widget child;

  const ChatWallpaperBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.appTheme.surfaceVariant.withAlpha(80),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            context.appTheme.surface,
            context.appTheme.surfaceVariant.withAlpha(120),
          ],
        ),
      ),
      child: Stack(
        children: [
          // Subtle doodle/dottiness pattern using CustomPaint
          Positioned.fill(
            child: Opacity(
              opacity: 0.04,
              child: CustomPaint(
                painter: _DoodlePatternPainter(
                  color: context.appTheme.onSurface,
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _DoodlePatternPainter extends CustomPainter {
  final Color color;
  _DoodlePatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final double step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      for (double y = 0; y < size.height; y += step) {
        // Draw small shapes to simulate chat background doodles
        if ((x + y) % 3 == 0) {
          canvas.drawCircle(Offset(x + 10, y + 10), 2, paint);
        } else if ((x + y) % 3 == 1) {
          canvas.drawRect(Rect.fromLTWH(x + 10, y + 10, 4, 4), paint);
        } else {
          canvas.drawLine(Offset(x + 8, y + 12), Offset(x + 14, y + 8), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// WhatsApp-style date separator pill.
class ChatDateSeparator extends StatelessWidget {
  final String dateText;

  const ChatDateSeparator({super.key, required this.dateText});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 16),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: context.appTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          dateText,
          style: GoogleFonts.ibmPlexSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: context.appTheme.onSurfaceVariant.withAlpha(200),
          ),
        ),
      ),
    );
  }
}

/// WhatsApp-style Chat Bubble with custom tails.
class ChatBubbleWidget extends StatelessWidget {
  final String messageText;
  final String time;
  final bool isMe;
  final bool isRead;
  final String type; // 'text', 'file', 'image'
  final Widget? attachmentWidget;
  final String senderLabel;
  final String senderRoleLabel;

  const ChatBubbleWidget({
    super.key,
    required this.messageText,
    required this.time,
    required this.isMe,
    required this.isRead,
    this.type = 'text',
    this.attachmentWidget,
    this.senderLabel = '',
    this.senderRoleLabel = '',
  });

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isMe
        ? context.appTheme.primary.withAlpha(225)
        : context.appTheme.surface;
    final textColor = isMe
        ? context.appTheme.onPrimary
        : context.appTheme.onSurface;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Stack(
          children: [
            // Bubble Content
            Container(
              padding: type == 'image'
                  ? const EdgeInsets.all(4)
                  : const EdgeInsets.only(
                      left: 14,
                      top: 8,
                      right: 14,
                      bottom: 22, // Space for time & ticks
                    ),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(14),
                  topRight: const Radius.circular(14),
                  bottomLeft: Radius.circular(isMe ? 14 : 2),
                  bottomRight: Radius.circular(isMe ? 2 : 14),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(15),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (senderLabel.trim().isNotEmpty ||
                      senderRoleLabel.trim().isNotEmpty) ...[
                    Wrap(
                      spacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (senderLabel.trim().isNotEmpty)
                          Text(
                            senderLabel,
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: textColor.withAlpha(210),
                            ),
                          ),
                        if (senderRoleLabel.trim().isNotEmpty)
                          Text(
                            senderRoleLabel,
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: textColor.withAlpha(170),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
                  if (type != 'text' && attachmentWidget != null) ...[
                    attachmentWidget!,
                    if (messageText.isNotEmpty) const SizedBox(height: 6),
                  ],
                  if (type == 'text' || messageText.isNotEmpty)
                    Text(
                      messageText,
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 14.5,
                        color: textColor,
                        height: 1.35,
                      ),
                    ),
                ],
              ),
            ),
            // Time & Ticks overlay at bottom right
            Positioned(
              bottom: 4,
              right: 8,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    time,
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 10,
                      color: isMe
                          ? context.appTheme.onPrimary.withAlpha(180)
                          : context.appTheme.muted,
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    Icon(
                      isRead ? Icons.done_all_rounded : Icons.done_rounded,
                      size: 14,
                      color: isRead
                          ? Colors.blueAccent
                          : context.appTheme.onPrimary.withAlpha(180),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// WhatsApp-style input bar.
class ChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback? onAttach;
  final bool isSending;
  final String placeholder;

  const ChatInputBar({
    super.key,
    required this.controller,
    required this.onSend,
    this.onAttach,
    this.isSending = false,
    this.placeholder = 'Type a message...',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      color: Colors.transparent,
      child: Row(
        children: [
          // Input pill
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: context.appTheme.surface,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(10),
                    blurRadius: 5,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      Icons.sentiment_satisfied_alt_rounded,
                      color: context.appTheme.muted,
                    ),
                    onPressed: () {}, // Optional Emoji Picker Trigger
                  ),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      decoration: InputDecoration(
                        hintText: placeholder,
                        hintStyle: GoogleFonts.ibmPlexSans(
                          color: context.appTheme.muted,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 4,
                        ),
                      ),
                      maxLines: 4,
                      minLines: 1,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                  ),
                  if (onAttach != null)
                    IconButton(
                      icon: Icon(
                        Icons.attach_file_rounded,
                        color: context.appTheme.muted,
                      ),
                      onPressed: onAttach,
                    ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            tooltip: 'Send message',
            onPressed: isSending ? null : onSend,
            icon: isSending
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            style: IconButton.styleFrom(
              fixedSize: const Size(48, 48),
              backgroundColor: context.appTheme.primary,
              disabledBackgroundColor: context.appTheme.primary.withAlpha(130),
            ),
          ),
        ],
      ),
    );
  }
}
