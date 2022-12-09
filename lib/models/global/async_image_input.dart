import 'package:image_size_getter/image_size_getter.dart';

class AsyncInput extends AsyncImageInput {
  AsyncInput(this._input);

  /// The input data of [ImageInput].
  final ImageInput _input;

  @override
  Future<bool> supportRangeLoad() async {
    return true;
  }

  @override
  Future<bool> exists() async {
    return _input.exists();
  }

  @override
  Future<List<int>> getRange(int start, int end) async {
    return _input.getRange(start, end);
  }

  @override
  Future<int> get length async => _input.length;

  @override
  Future<HaveResourceImageInput> delegateInput() async {
    return HaveResourceImageInput(innerInput: _input);
  }
}
