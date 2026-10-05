import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text.dart';
import 'app_icons.dart';

/// Figma StepBar: Details / Meetup / Invite / Prefs / Review.
/// 22dp circles, 2dp connectors, 9sp labels, 20dp bottom margin.
class StepBar extends StatelessWidget {
  const StepBar({super.key, required this.current});

  /// 1-based current step.
  final int current;

  static const _labels = ['Details', 'Meetup', 'Invite', 'Prefs', 'Review'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          for (var i = 0; i < _labels.length; i++)
            Expanded(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: i > 0
                            ? Container(
                                height: 2,
                                color: i < current
                                    ? AppColors.orange
                                    : AppColors.border,
                              )
                            : const SizedBox(height: 2),
                      ),
                      _Dot(index: i + 1, current: current),
                      Expanded(
                        child: i < _labels.length - 1
                            ? Container(
                                height: 2,
                                color: i + 1 < current
                                    ? AppColors.orange
                                    : AppColors.border,
                              )
                            : const SizedBox(height: 2),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _labels[i],
                    style: AppText.ui(
                      9,
                      FontWeight.w600,
                      color: i + 1 == current
                          ? AppColors.orange
                          : AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.index, required this.current});
  final int index;
  final int current;

  @override
  Widget build(BuildContext context) {
    final reached = index <= current;
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: reached ? AppColors.orange : AppColors.bg,
        border: Border.all(
          color: reached ? AppColors.orange : AppColors.border,
          width: 2,
        ),
      ),
      alignment: Alignment.center,
      child: index < current
          ? AppIcons.check(size: 12)
          : Text(
              '$index',
              // Figma paints the current number orange-on-orange (invisible);
              // white keeps it readable.
              style: AppText.ui(
                10,
                FontWeight.w700,
                color: index == current ? Colors.white : AppColors.muted,
              ),
            ),
    );
  }
}
