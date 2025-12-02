import 'package:sixam_mart_delivery/common/widgets/custom_card.dart';
import 'package:sixam_mart_delivery/features/order/domain/models/order_model.dart';
import 'package:sixam_mart_delivery/helper/route_helper.dart';
import 'package:sixam_mart_delivery/util/color_resources.dart';
import 'package:sixam_mart_delivery/util/dimensions.dart';
import 'package:sixam_mart_delivery/util/images.dart';
import 'package:sixam_mart_delivery/util/styles.dart';
import 'package:sixam_mart_delivery/common/widgets/custom_snackbar_widget.dart';
import 'package:sixam_mart_delivery/features/order/screens/order_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher_string.dart';

class OrderWidget extends StatelessWidget {
  final OrderModel orderModel;
  final bool isRunningOrder;
  final int orderIndex;
  const OrderWidget({super.key, required this.orderModel, required this.isRunningOrder, required this.orderIndex});

  @override
  Widget build(BuildContext context) {
    bool parcel = orderModel.orderType == 'parcel';

    return InkWell(
      onTap: () {
        Get.toNamed(
          RouteHelper.getOrderDetailsRoute(orderModel.id),
          arguments: OrderDetailsScreen(orderId: orderModel.id, isRunningOrder: isRunningOrder, orderIndex: orderIndex),
        );
      },
      child: CustomCard(
        child: Column(children: [

          Container(
            padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
            decoration: BoxDecoration(
              color: Theme.of(context).disabledColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(Dimensions.radiusDefault), topRight: Radius.circular(Dimensions.radiusDefault),
              ),
            ),
            child: Row(children: [

              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${parcel ? 'delivery'.tr : 'order'.tr}:', style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).hintColor)),

                Row(children: [
                  Text('# ${orderModel.id} ', style: robotoBold.copyWith(fontSize: Dimensions.fontSizeDefault)),

                  parcel ? const SizedBox() : Text('(${orderModel.detailsCount} ${'item'.tr})', style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).hintColor)),
                ]),
              ]),

              const Expanded(child: SizedBox()),

              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeSmall, vertical: 2),
                  decoration: BoxDecoration(
                    color: orderModel.paymentStatus == 'paid' ? ColorResources.green.withValues(alpha: 0.1) : ColorResources.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
                  ),
                  child: Text(
                    orderModel.paymentStatus == 'paid' ? 'paid'.tr : 'unpaid'.tr,
                    style: robotoBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: orderModel.paymentStatus == 'paid' ? ColorResources.green : ColorResources.red),
                  ),
                ),
                const SizedBox(height: 2),

                Text(
                  orderModel.paymentMethod == 'cash_on_delivery' ? 'cod'.tr : orderModel.paymentMethod == 'partial_payment' ? 'partially_pay'.tr : 'digitally_paid'.tr,
                  style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).hintColor),
                ),

              ]),
            ]),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeSmall, vertical: Dimensions.paddingSizeSmall),
            child: Column(children: [
              Row(crossAxisAlignment: CrossAxisAlignment.center, mainAxisAlignment: MainAxisAlignment.start, children: [
                Image.asset((parcel || orderModel.orderStatus == 'picked_up') ? Images.personIcon : Images.house, width: 20, height: 20),
                const SizedBox(width: Dimensions.paddingSizeExtraSmall),

                Expanded(
                  child: Text(
                    parcel ? 'customer_location'.tr : (parcel && orderModel.orderStatus == 'picked_up') ? 'receiver_location'.tr : 'store_location'.tr,
                    style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                ),

                parcel ? Container(
                  padding: const EdgeInsets.all(Dimensions.paddingSizeExtraSmall),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  ),
                  child: Text('parcel'.tr, style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).primaryColor)),
                ) : const SizedBox(),

              ]),
              const SizedBox(height: Dimensions.paddingSizeSmall),

              Row(crossAxisAlignment: CrossAxisAlignment.center, mainAxisAlignment: MainAxisAlignment.start, children: [
                Icon(Icons.location_on, size: 20, color: Theme.of(context).hintColor),
                const SizedBox(width: Dimensions.paddingSizeExtraSmall),

                Expanded(child: Text(
                  (parcel && orderModel.orderStatus != 'picked_up') ? orderModel.deliveryAddress!.address.toString() : (parcel && orderModel.orderStatus == 'picked_up') ? orderModel.receiverDetails!.address.toString() : orderModel.storeAddress ?? 'address_not_found'.tr,
                  style: robotoRegular.copyWith(color: Theme.of(context).hintColor, fontSize: Dimensions.fontSizeSmall),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                )),
                const SizedBox(width: Dimensions.paddingSizeExtraSmall),

                InkWell(
                  onTap: () async {
                    String url;
                    if(parcel && (orderModel.orderStatus == 'picked_up')) {
                      url = 'https://www.google.com/maps/dir/?api=1&destination=${orderModel.receiverDetails!.latitude}'
                          ',${orderModel.receiverDetails!.longitude}&mode=d';
                    }else if(parcel) {
                      url = 'https://www.google.com/maps/dir/?api=1&destination=${orderModel.deliveryAddress!.latitude}'
                          ',${orderModel.deliveryAddress!.longitude}&mode=d';
                    }else if(orderModel.orderStatus == 'picked_up') {
                      url = 'https://www.google.com/maps/dir/?api=1&destination=${orderModel.deliveryAddress!.latitude}'
                          ',${orderModel.deliveryAddress!.longitude}&mode=d';
                    }else {
                      url = 'https://www.google.com/maps/dir/?api=1&destination=${orderModel.storeLat ?? '0'}'
                          ',${orderModel.storeLng ?? '0'}&mode=d';
                    }
                    if (await canLaunchUrlString(url)) {
                      await launchUrlString(url, mode: LaunchMode.externalApplication);
                    } else {
                      showCustomSnackBar('${'could_not_launch'.tr} $url');
                    }
                  },
                  child: Row(children: [
                    Icon(Icons.directions, size: 20, color: Theme.of(context).primaryColor),
                    const SizedBox(width: Dimensions.paddingSizeExtraSmall),

                    Text(
                      'direction'.tr,
                      style: robotoMedium.copyWith(color: Theme.of(context).primaryColor),
                    ),
                  ]),
                ),
              ]),
              const SizedBox(height: Dimensions.paddingSizeSmall),

              Text('details'.tr, style: robotoRegular.copyWith(color: Theme.of(context).primaryColor, decoration: TextDecoration.underline, decorationColor: Theme.of(context).primaryColor)),
            ]),
          ),

        ]),
      ),
    );
  }
}
