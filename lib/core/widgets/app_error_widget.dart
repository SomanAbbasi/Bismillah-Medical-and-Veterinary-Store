import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'primary_button.dart';

/// Formats raw technical exceptions into clean, user-friendly English messages.
/// Hides raw SQL statements, database internals, and stack traces from end-users.
class AppErrorFormatter {
  static String toUserFriendlyMessage(dynamic error) {
    if (error == null) {
      return 'An unexpected issue occurred. Tap Retry to reload.';
    }

    final raw = error.toString();

    // SQLite / Database schema or query errors
    if (raw.contains('SqliteException') ||
        raw.contains('no such column') ||
        raw.contains('no such table') ||
        raw.contains('syntax error') ||
        raw.contains('prepare statement') ||
        raw.contains('Drift') ||
        raw.contains('UNIQUE constraint') ||
        raw.contains('database is locked')) {
      return 'A local database sync issue occurred. Tap Retry to auto-repair and reload your data.';
    }

    // Storage / File system errors
    if (raw.contains('FileSystemException') ||
        raw.contains('No such file') ||
        raw.contains('Permission denied') ||
        raw.contains('read-only')) {
      return 'Unable to access device storage. Please check permissions and try again.';
    }

    // Network / Socket errors
    if (raw.contains('SocketException') ||
        raw.contains('TimeoutException') ||
        raw.contains('HandshakeException') ||
        raw.contains('Failed host lookup')) {
      return 'Unable to connect to the network. Please check your internet connection.';
    }

    // Platform / Plugin errors
    if (raw.contains('PlatformException')) {
      return 'A system service was temporarily unavailable. Please tap Retry to reload.';
    }

    // Format exception
    if (raw.contains('FormatException')) {
      return 'Data could not be processed. Please tap Retry to reload.';
    }

    // Default friendly message
    return 'Something went wrong while loading information. Tap Retry to reload.';
  }
}

/// A clean, professional error widget that displays a friendly message
/// and a retry button, hiding technical errors and SQL commands from end users.
class AppErrorWidget extends StatefulWidget {
  final String title;
  final dynamic error;
  final StackTrace? stackTrace;
  final String? customMessage;
  final VoidCallback? onRetry;
  final String retryLabel;
  final bool isCompact;
  final IconData icon;

  const AppErrorWidget({
    super.key,
    this.title = 'Unable to load data',
    this.error,
    this.stackTrace,
    this.customMessage,
    this.onRetry,
    this.retryLabel = 'Retry',
    this.isCompact = false,
    this.icon = Icons.error_outline_rounded,
  });

  @override
  State<AppErrorWidget> createState() => _AppErrorWidgetState();
}

class _AppErrorWidgetState extends State<AppErrorWidget> {
  bool _showTechnicalDetails = false;

  @override
  void initState() {
    super.initState();
    if (widget.error != null) {
      debugPrint('[AppErrorWidget] Technical error: ${widget.error}');
      if (widget.stackTrace != null) {
        debugPrint('[AppErrorWidget] StackTrace: ${widget.stackTrace}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.customMessage ?? AppErrorFormatter.toUserFriendlyMessage(widget.error);

    if (widget.isCompact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.danger.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(widget.icon, size: 20, color: AppColors.danger),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: AppTypography.bodySmall.copyWith(color: AppColors.danger),
              ),
            ),
            if (widget.onRetry != null) ...[
              const SizedBox(width: AppSpacing.sm),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 18, color: AppColors.danger),
                tooltip: widget.retryLabel,
                onPressed: widget.onRetry,
              ),
            ],
          ],
        ),
      );
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                widget.icon,
                size: 38,
                color: AppColors.danger,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              widget.title,
              style: AppTypography.heading3,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: Text(
                message,
                style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ),
            if (widget.onRetry != null) ...[
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: 160,
                child: PrimaryButton(
                  label: widget.retryLabel,
                  icon: Icons.refresh_rounded,
                  onPressed: widget.onRetry!,
                ),
              ),
            ],
            // Subtle, optional technical toggle for debugging if needed
            if (kDebugMode && widget.error != null) ...[
              const SizedBox(height: AppSpacing.md),
              TextButton(
                onPressed: () => setState(() => _showTechnicalDetails = !_showTechnicalDetails),
                child: Text(
                  _showTechnicalDetails ? 'Hide technical details' : 'Show technical details (debug)',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
                ),
              ),
              if (_showTechnicalDetails)
                Container(
                  margin: const EdgeInsets.only(top: AppSpacing.xs),
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: SelectableText(
                    widget.error.toString(),
                    style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Colors.black87),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
