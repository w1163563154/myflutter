String dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

String recordValue(String value) => value.trim().isEmpty ? '未填写' : value.trim();

class LocalRecord {
  LocalRecord({
    required this.date,
    required this.name,
    this.phone = '',
    this.number = '',
    this.note = '',
    this.id,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final int? id;
  final DateTime date;
  final String name;
  final String phone;
  final String number;
  final String note;
  final DateTime createdAt;

  Map<String, Object?> toMap() => {
    'record_date': dateKey(date),
    'name': recordValue(name),
    'phone': recordValue(phone),
    'number': recordValue(number),
    'note': recordValue(note),
    'created_at': createdAt.millisecondsSinceEpoch,
  };

  factory LocalRecord.fromMap(Map<String, Object?> row) => LocalRecord(
    id: row['id'] as int,
    date: DateTime.parse(row['record_date'] as String),
    name: row['name'] as String,
    phone: row['phone'] as String,
    number: row['number'] as String,
    note: row['note'] as String,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
  );
}
