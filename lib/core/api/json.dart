typedef Json = Map<String, dynamic>;

/// Rows of a JSON array; a missing or non-list value yields an empty list.
List<Json> jsonRows(dynamic value) =>
    value is List ? value.map((e) => Json.from(e as Map)).toList() : <Json>[];

Json jsonMap(dynamic value) => Json.from(value as Map);
