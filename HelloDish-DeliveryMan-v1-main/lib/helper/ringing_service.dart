import 'package:get/get.dart';

class RingingService extends GetxController {
  final RxBool isRinging = false.obs;

  void startRinging() {
    isRinging.value = true;
    update();
  }

  void stopRinging() {
    isRinging.value = false;
    update();
  }
}
