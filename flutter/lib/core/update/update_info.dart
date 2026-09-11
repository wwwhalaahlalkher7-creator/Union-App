class UpdateInfo {
  const UpdateInfo({
    required this.currentVersion,
    required this.minimumVersion,
    this.updateUrl,
    this.releaseNotes,
  });

  final String currentVersion;
  final String? minimumVersion;
  final String? updateUrl;
  final String? releaseNotes;

  bool get hasUpdate => minimumVersion != null && VersionComparator.isNewer(currentVersion, minimumVersion!);
}

class VersionComparator {
  VersionComparator._();

  static bool isNewer(String candidate, String installed) {
    if (installed.trim().isEmpty) return false;
    return compare(candidate, installed) > 0;
  }

  static int compare(String a, String b) {
    final av = _parts(a);
    final bv = _parts(b);
    for (var i = 0; i < 3; i++) {
      if (av[i] != bv[i]) return av[i].compareTo(bv[i]);
    }
    return 0;
  }

  static List<int> _parts(String value) {
    final clean = value.trim().split('+').first.replaceFirst(RegExp(r'^v'), '');
    final parts = clean.split('.');
    return List<int>.generate(3, (i) => int.tryParse(parts.length > i ? parts[i] : '0') ?? 0);
  }
}
