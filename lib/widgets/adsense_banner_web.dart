import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../theme/colors.dart';

@JS('btwAdsense.mountHomeBanner')
external JSPromise<JSBoolean> _mountHomeBanner(web.HTMLElement container);

class AdsenseBanner extends StatefulWidget {
  const AdsenseBanner({super.key});

  @override
  State<AdsenseBanner> createState() => _AdsenseBannerState();
}

class _AdsenseBannerState extends State<AdsenseBanner> {
  bool _hide = false;

  Future<void> _mount(web.HTMLElement element) async {
    final filled = (await _mountHomeBanner(element).toDart).toDart;
    if (!filled && mounted) setState(() => _hide = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_hide) return const SizedBox.shrink();
    final mobile = MediaQuery.sizeOf(context).width < 700;

    return Semantics(
      label: 'פרסומת',
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Text(
              'פרסומת',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 9,
                height: 1,
              ),
            ),
          ),
          SizedBox(
            height: mobile ? 100 : 90,
            child: HtmlElementView.fromTagName(
              tagName: 'div',
              onElementCreated: (element) {
                _mount(element as web.HTMLElement);
              },
            ),
          ),
        ],
      ),
    );
  }
}
