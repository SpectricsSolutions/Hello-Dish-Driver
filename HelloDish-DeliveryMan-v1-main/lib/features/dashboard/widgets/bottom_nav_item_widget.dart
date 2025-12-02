import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sixam_mart_delivery/features/order/controllers/order_controller.dart';
import 'package:sixam_mart_delivery/util/dimensions.dart';
import 'package:sixam_mart_delivery/util/styles.dart';

class BottomNavItemWidget extends StatelessWidget {
  final IconData iconData;
  final Function? onTap;
  final bool isSelected;
  final int? pageIndex;
  const BottomNavItemWidget({super.key, required this.iconData, this.onTap, this.isSelected = false, this.pageIndex});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: IconButton(
        onPressed: onTap as void Function()?,
        icon: Stack(clipBehavior: Clip.none, children: [
          Icon(iconData, color: isSelected ? Theme.of(context).primaryColor : Colors.grey, size: 25),

          pageIndex == 1 ? Positioned(
            top: -5, right: -5,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
              ),
              child: GetBuilder<OrderController>(builder: (orderController) {
                return Text(
                  orderController.latestOrderList?.length.toString() ?? '0',
                  style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: Colors.white),
                );
              }),
            ),
          ) : const SizedBox(),
        ]),
      ),
    );
  }
}
