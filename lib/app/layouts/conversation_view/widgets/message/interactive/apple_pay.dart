import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ApplePay extends StatefulWidget {
  final iMessageAppData data;
  final Message message;

  ApplePay({
    super.key,
    required this.data,
    required this.message,
  });

  @override
  OptimizedState createState() => _ApplePayState();
}

class _ApplePayState extends OptimizedState<ApplePay> with AutomaticKeepAliveClientMixin {
  iMessageAppData get data => widget.data;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    const icon = Icons.apple;
    final str = data.userInfo?.subcaption;
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned(
          top: 5,
          left: widget.message.isFromMe! ? 5 : 10,
          child: Row(
            children: [
              Text(
                String.fromCharCode(icon.codePoint),
                style: TextStyle(
                  fontFamily: icon.fontFamily,
                  package: icon.fontPackage,
                  fontSize: context.theme.textTheme.labelLarge!.fontSize,
                  color: context.theme.textTheme.labelLarge!.color,
                ),
              ),
              const SizedBox(width: 1),
              Text("Pay", style: context.theme.textTheme.labelLarge),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(40.0),
          child: Text(
            str?.contains("Request") ?? false ? str! : data.userInfo?.subcaption?.split(" ").first ?? "\$ ??",
            style: str?.contains("Request") ?? false ? context.theme.textTheme.bodyLarge : context.theme.textTheme.displayLarge!.copyWith(
              color: context.theme.textTheme.bodyLarge!.color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
