/// 持久化接口，用于统一对象的序列化和反序列化操作
abstract class Persistable<T> {
  /// 将对象序列化为 Map
  Map<String, dynamic> toJson();

  /// 从 Map 反序列化为对象
  static T fromJson<T>(Map<String, dynamic> json) {
    throw UnimplementedError('子类必须实现 fromJson 静态方法');
  }

  /// 保存对象到持久化存储
  Future<bool> save();

  /// 从持久化存储加载对象
  static Future<T?> read<T>(String id) {
    throw UnimplementedError('子类必须实现 read 静态方法');
  }
}
