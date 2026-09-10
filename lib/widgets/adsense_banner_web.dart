import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../theme/colors.dart';

@JS('btwAdsense.mountHomeBanner')
external void _mountHomeBanner(web.HTMLElement container);

class AdsenseBanner extends StatelessWidget {
  const AdsenseBanner({super.key});

  @override
  Widget build(BuildContext context) {
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
                _mountHomeBanner(element as web.HTMLElement);
              },
            ),
          ),
        ],
      ),
    );
  }
}
