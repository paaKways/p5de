import 'package:uuid/uuid.dart';

abstract class IdGenerator {
  String newId();
}

class UuidV4Generator implements IdGenerator {
  UuidV4Generator() : _uuid = const Uuid();

  final Uuid _uuid;

  @override
  String newId() => _uuid.v4();
}
