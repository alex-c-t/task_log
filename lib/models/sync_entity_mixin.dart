mixin SyncEntity {
  abstract String uuid;
  abstract DateTime createdAt;
  abstract DateTime updatedAt;
  int isDeleted = 0; // 0 = false, 1 = true
  int isDirty = 0;   // 0 = synchronized, 1 = needs sync
  String? userId;    // Owner of the record

  /// Helper to serialize sync fields to a Map.
  /// Timestamps are converted to UTC ISO8601 strings.
  Map<String, dynamic> toMapSync() {
    return {
      'uuid': uuid,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'isDeleted': isDeleted,
      'isDirty': isDirty,
      'userId': userId,
    };
  }
}
