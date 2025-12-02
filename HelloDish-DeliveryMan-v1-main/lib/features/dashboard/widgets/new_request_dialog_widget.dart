import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:sixam_mart_delivery/features/order/controllers/order_controller.dart';
import 'package:sixam_mart_delivery/util/dimensions.dart';
import 'package:sixam_mart_delivery/util/images.dart';
import 'package:sixam_mart_delivery/util/styles.dart';
import 'package:sixam_mart_delivery/common/widgets/custom_button_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sixam_mart_delivery/helper/ringing_service.dart';

class NewRequestDialogWidget extends StatefulWidget {
  final bool isRequest;
  final VoidCallback onTap; // narrowed Function type for clarity
  final int orderId;
  final bool isParcel;
  const NewRequestDialogWidget({super.key, required this.isRequest, required this.onTap, required this.orderId, required this.isParcel});

  @override
  State<NewRequestDialogWidget> createState() => _NewRequestDialogWidgetState();
}

class _NewRequestDialogWidgetState extends State<NewRequestDialogWidget> {
  Timer? _timer;
  AudioPlayer? _audio; // moved to state so we can stop it from other places
  RxBool? _isRinging; // observable from RingingService (nullable if service not registered)
  StreamSubscription<bool>? _ringingSub;

  @override
  void initState() {
    super.initState();

    // ensure RingingService is available
    try{
      final ringingService = Get.find<RingingService>();
      _isRinging = ringingService.isRinging;
      // listen to the RxBool stream and stop audio when it becomes false
      _ringingSub = _isRinging!.listen((val) {
        if (!val) {
          _stopAndDisposeAudio();
        }
      });
    }catch(e){
      _isRinging = null;
    }

    _startAlarm();
    Get.find<OrderController>().getOrderDetails(widget.orderId, widget.isParcel);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stopAndDisposeAudio();
    _ringingSub?.cancel();
    _ringingSub = null;
    super.dispose();
  }

  Future<void> _stopAndDisposeAudio() async {
    try {
      await _audio?.stop();
      await _audio?.dispose();
    } catch (_) {}
    _audio = null;
  }

  void _startAlarm() async {
    // Use AudioPlayer loop mode for reliable continuous playback
    _audio = AudioPlayer();
    try{
      // Set release mode to loop (works with audioplayers >=6.x)
      await _audio!.setReleaseMode(ReleaseMode.loop);
    }catch(_){ }
    try{
      await _audio!.play(AssetSource('notification.mp3'));
    }catch(e){
      // fallback: if play fails, try a timer re-trigger
      _timer = Timer.periodic(const Duration(seconds: 3), (timer) async {
        try{ await _audio?.play(AssetSource('notification.mp3')); }catch(_){ }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Dimensions.radiusSmall)),
      child: Padding(
        padding: const EdgeInsets.all(Dimensions.paddingSizeLarge),
        child: GetBuilder<OrderController>(builder: (orderController) {
          return Column(mainAxisSize: MainAxisSize.min, children: [

            Image.asset(Images.notificationIn, height: 60, color: Theme.of(context).primaryColor),

            Padding(
              padding: const EdgeInsets.all(Dimensions.paddingSizeLarge),
              child: Text(
                widget.isRequest ? 'new_order_request_from_a_customer'.tr : 'you_have_assigned_a_new_order'.tr, textAlign: TextAlign.center,
                style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeLarge),
              ),
            ),

            !widget.isParcel && orderController.orderDetailsModel != null ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('with'.tr , textAlign: TextAlign.center, style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeDefault)),
              Text(
                ' ${orderController.orderDetailsModel != null ? orderController.orderDetailsModel!.length.toString() : 0} ',
                textAlign: TextAlign.center, style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeLarge),
              ),
              Text('items'.tr, textAlign: TextAlign.center, style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeDefault)),
            ]) : const SizedBox(),

            orderController.orderDetailsModel != null ? ListView.builder(
              itemCount: orderController.orderDetailsModel!.length,
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: Dimensions.paddingSizeSmall),
              itemBuilder: (context,index){
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: Dimensions.paddingSizeExtraSmall),
                  child: Row(children: [
                    Text('${'item'.tr} ${index + 1}: ', style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeSmall)),
                    Flexible(child: Text(
                        '${orderController.orderDetailsModel![index].itemDetails!.name!} ( x ${orderController.orderDetailsModel![index].quantity})',
                        maxLines: 2, overflow: TextOverflow.ellipsis, style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall)),
                    ),
                  ]),
                );
              },
            ) : const SizedBox(),

            CustomButtonWidget(
              height: 40,
              buttonText: widget.isRequest ? (Get.find<OrderController>().currentOrderList != null
                  && Get.find<OrderController>().currentOrderList!.isNotEmpty) ? 'ok'.tr : 'go'.tr : 'ok'.tr,
              onPressed: () async {
                if(!widget.isRequest) {
                  _timer?.cancel();
                }
                await _stopAndDisposeAudio();
                Get.back();
                widget.onTap();
              },
            ),

          ]);
        }),
      ),
    );
  }
}
