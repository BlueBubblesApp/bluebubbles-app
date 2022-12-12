@JS()
import 'package:js/js.dart';
import 'package:js/js_util.dart';

// Call invokes JavaScript `getPastedImage()`.
@JS('getPastedImage')
external dynamic getClipboardData();

Future<dynamic> getPastedImageWeb() {
  return promiseToFuture(getClipboardData());
}
