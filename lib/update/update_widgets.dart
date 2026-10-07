import 'package:material_ui/material_ui.dart';

import '../common/format.dart';
import '../l10n/app_localizations.dart';
import 'app_updater.dart';

/// Asks the player once whether to install a newer version, when the route
/// of [child] is on top (not under a game or a dialog).
class UpdatePrompt extends StatefulWidget {
  const UpdatePrompt({super.key, required this.updater, required this.child});

  final AppUpdater updater;
  final Widget child;

  @override
  State<UpdatePrompt> createState() => _UpdatePromptState();
}

class _UpdatePromptState extends State<UpdatePrompt> {
  ModalRoute<Object?>? _route;

  @override
  void initState() {
    super.initState();
    widget.updater.addListener(_maybeAsk);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Called again when the route comes back on top: the check may have
    // ended while a game was open.
    _route = ModalRoute.of(context);
    _maybeAsk();
  }

  @override
  void dispose() {
    widget.updater.removeListener(_maybeAsk);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;

  void _maybeAsk() {
    final updater = widget.updater;
    if (!updater.shouldAsk || _route?.isCurrent == false) return;
    updater.markAsked();
    // Never during a build: didChangeDependencies runs in one.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _ask();
    });
  }

  Future<void> _ask() async {
    final updater = widget.updater;
    final version = '${updater.available!.version}';
    final update = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return AlertDialog(
          key: const ValueKey('update-dialog'),
          title: Text(l10n.updateAvailableTitle),
          content: Text(l10n.updateAvailableMessage(version)),
          actions: [
            TextButton(
              key: const ValueKey('update-later'),
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.updateLater),
            ),
            FilledButton(
              key: const ValueKey('update-now'),
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.updateNow),
            ),
          ],
        );
      },
    );
    // Closed without an answer (null): asked again at the next start.
    if (update == false) {
      await updater.refuse();
    } else if (update == true && mounted) {
      await showUpdateProgress(context, updater);
    }
  }
}

/// Installs the newer version. It stays at the top of the hub while there is
/// one, even after the player answered Later.
class UpdateButton extends StatelessWidget {
  const UpdateButton({super.key, required this.updater});

  final AppUpdater updater;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: updater,
      builder: (context, _) {
        final release = updater.available;
        if (release == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: FilledButton.icon(
            key: const ValueKey('update-button'),
            onPressed: () => showUpdateProgress(context, updater),
            icon: const Icon(Icons.system_update),
            label: Text(
              AppLocalizations.of(context).updateTo('${release.version}'),
            ),
          ),
        );
      },
    );
  }
}

/// Downloads the newer version with a progress bar, then opens the system
/// installer and closes. A failed download can be tried again.
Future<void> showUpdateProgress(BuildContext context, AppUpdater updater) =>
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _UpdateProgressDialog(updater: updater),
    );

class _UpdateProgressDialog extends StatefulWidget {
  const _UpdateProgressDialog({required this.updater});

  final AppUpdater updater;

  @override
  State<_UpdateProgressDialog> createState() => _UpdateProgressDialogState();
}

class _UpdateProgressDialogState extends State<_UpdateProgressDialog> {
  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    if (await widget.updater.update() && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final updater = widget.updater;
    return ListenableBuilder(
      listenable: updater,
      builder: (context, _) {
        final failed = updater.status == UpdateStatus.failed;
        return PopScope(
          // Back cancels, like the Cancel button.
          onPopInvokedWithResult: (didPop, _) => updater.cancelDownload(),
          child: AlertDialog(
            key: const ValueKey('update-progress'),
            title: Text(l10n.updateTo('${updater.available!.version}')),
            content: failed
                ? Text(l10n.updateFailed, key: const ValueKey('update-error'))
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.updateDownloading(
                          formatPercent(updater.progress, l10n.localeName),
                        ),
                        key: const ValueKey('update-percent'),
                      ),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(value: updater.progress),
                      const SizedBox(height: 16),
                      Text(l10n.updateInstallNote),
                    ],
                  ),
            actions: [
              TextButton(
                key: const ValueKey('update-cancel'),
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.cancel),
              ),
              if (failed)
                FilledButton(
                  key: const ValueKey('update-retry'),
                  onPressed: () {
                    _run();
                    // update() set the status to downloading at once.
                    setState(() {});
                  },
                  child: Text(l10n.updateRetry),
                ),
            ],
          ),
        );
      },
    );
  }
}
