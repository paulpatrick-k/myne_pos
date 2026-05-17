part of 'pending_sale_model.dart';

class PendingSaleModelAdapter extends TypeAdapter<PendingSaleModel> {
  @override
  final int typeId = 0;

  @override
  PendingSaleModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (var i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return PendingSaleModel(
      id: fields[0] as String,
      businessId: fields[1] as String,
      userId: fields[2] as String,
      userEmail: fields[3] as String,
      items: (fields[4] as List).cast<Map<String, dynamic>>(),
      totalAmount: fields[5] as double,
      paymentMethod: fields[6] as String,
      paymentReference: fields[7] as String?,
      receiptNo: fields[8] as String,
      createdAt: fields[9] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, PendingSaleModel obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.businessId)
      ..writeByte(2)
      ..write(obj.userId)
      ..writeByte(3)
      ..write(obj.userEmail)
      ..writeByte(4)
      ..write(obj.items)
      ..writeByte(5)
      ..write(obj.totalAmount)
      ..writeByte(6)
      ..write(obj.paymentMethod)
      ..writeByte(7)
      ..write(obj.paymentReference)
      ..writeByte(8)
      ..write(obj.receiptNo)
      ..writeByte(9)
      ..write(obj.createdAt);
  }
}
