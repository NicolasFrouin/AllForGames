/// A version of the app, like 1.2.3 (tag v1.2.3). A suffix (1.2.3-beta.1)
/// marks a prerelease, older than its release.
class AppVersion implements Comparable<AppVersion> {
  const AppVersion(this.major, this.minor, this.patch, {this.suffix});

  final int major;
  final int minor;
  final int patch;

  /// What follows the dash, like beta.1; null for a release.
  final String? suffix;

  static final _pattern = RegExp(
    r'^v?(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.-]+))?$',
  );

  /// Null when [text] is not like 1.2.3, v1.2.3 or 1.2.3-beta.1.
  static AppVersion? tryParse(String text) {
    final match = _pattern.firstMatch(text.trim());
    if (match == null) return null;
    final [major, minor, patch] = [
      for (var group = 1; group <= 3; group++) int.tryParse(match[group]!),
    ];
    if (major == null || minor == null || patch == null) return null;
    return AppVersion(major, minor, patch, suffix: match[4]);
  }

  @override
  int compareTo(AppVersion other) {
    for (final (a, b) in [
      (major, other.major),
      (minor, other.minor),
      (patch, other.patch),
    ]) {
      if (a != b) return a.compareTo(b);
    }
    // Prereleases of the same version are not ordered: none is offered.
    return switch ((suffix, other.suffix)) {
      (null, null) => 0,
      (null, _) => 1,
      (_, null) => -1,
      _ => 0,
    };
  }

  bool operator >(AppVersion other) => compareTo(other) > 0;

  @override
  String toString() =>
      '$major.$minor.$patch${suffix == null ? '' : '-$suffix'}';
}

/// A release of the app with an APK to install.
class AppRelease {
  const AppRelease({required this.version, required this.apkUrl, this.apkSize});

  final AppVersion version;
  final Uri apkUrl;

  /// In bytes, as GitHub lists it.
  final int? apkSize;
}

/// The newest release of [releases] (the JSON of GitHub's list releases
/// endpoint) above [installed], or null: a published release (not a draft)
/// of a tag vX.Y.Z without suffix, with an APK.
///
/// GitHub's prerelease flag does not count: the releases below 1.0 have it.
/// Throws a [FormatException] when [releases] is not a list.
AppRelease? pickUpdate(Object? releases, AppVersion installed) {
  if (releases is! List) {
    throw FormatException('Not a list of releases', releases);
  }
  AppRelease? newest;
  for (final release in releases) {
    if (release case {
      'tag_name': final String tag,
      'draft': false,
      'assets': final List<Object?> assets,
    }) {
      final version = AppVersion.tryParse(tag);
      if (version == null || version.suffix != null) continue;
      if (!(version > (newest?.version ?? installed))) continue;
      newest = _apkRelease(version, assets) ?? newest;
    }
  }
  return newest;
}

AppRelease? _apkRelease(AppVersion version, List<Object?> assets) {
  for (final asset in assets) {
    if (asset
        case {
          'name': final String name,
          'browser_download_url': final String url,
        }
        when name.toLowerCase().endsWith('.apk')) {
      final apkUrl = Uri.tryParse(url);
      if (apkUrl == null || apkUrl.scheme != 'https') continue;
      return AppRelease(
        version: version,
        apkUrl: apkUrl,
        apkSize: switch (asset['size']) {
          final int size when size > 0 => size,
          _ => null,
        },
      );
    }
  }
  return null;
}
