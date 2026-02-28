/// Defines where the downloaded file should be saved.
enum SaveLocation {
  /// Save to the system's default downloads directory
  downloads,

  /// Save to the application's private directory
  appDirectory,

  /// Save to a custom path specified by the user
  custom,
}
