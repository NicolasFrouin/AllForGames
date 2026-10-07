import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import 'settings_store.dart';

/// The settings page: the language, and how long a finger holds a
/// Minesweeper cell to flag it.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.settings});

  final SettingsStore settings;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _system = 'system';

  /// Each language name is in its own language.
  static const _names = {'en': 'English', 'fr': 'Français'};

  static const _flagHoldStep = 50;

  /// Moves with the slider; the store tells its listeners only after the
  /// write.
  late int _flagHoldMs = widget.settings.minesweeperFlagHoldMs;

  void _setFlagHold(double value) {
    setState(() => _flagHoldMs = value.round());
    unawaited(widget.settings.setMinesweeperFlagHold(_flagHoldMs));
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.settings,
    builder: (context, _) => _page(context),
  );

  Widget _page(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = widget.settings;
    final current = settings.locale?.languageCode ?? _system;
    Widget language(String code, String name) => ChoiceChip(
      key: ValueKey('language-$code'),
      label: Text(name),
      selected: code == current,
      onSelected: (_) =>
          settings.setLocale(code == _system ? null : Locale(code)),
    );
    final flagHold = l10n.settingsFlagHoldValue(_flagHoldMs / 1000);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _Section(
                  title: l10n.language,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        language(_system, l10n.languageSystem),
                        for (final Locale(:languageCode)
                            in AppLocalizations.supportedLocales)
                          language(
                            languageCode,
                            _names[languageCode] ?? languageCode,
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _Section(
                  title: l10n.minesweeperTitle,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(l10n.settingsFlagHold)),
                        Text(flagHold, key: const ValueKey('flag-hold-value')),
                      ],
                    ),
                    Slider(
                      key: const ValueKey('flag-hold'),
                      value: _flagHoldMs.toDouble(),
                      min: SettingsStore.minFlagHoldMs.toDouble(),
                      max: SettingsStore.maxFlagHoldMs.toDouble(),
                      divisions:
                          (SettingsStore.maxFlagHoldMs -
                              SettingsStore.minFlagHoldMs) ~/
                          _flagHoldStep,
                      label: flagHold,
                      onChanged: _setFlagHold,
                    ),
                    Text(
                      l10n.settingsFlagHoldHint,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}
