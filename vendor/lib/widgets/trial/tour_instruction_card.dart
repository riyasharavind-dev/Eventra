import 'package:flutter/material.dart';

import '../../services/app_settings_controller.dart';
import '../../services/vendor_tour_controller.dart';

class TourMiniTipCard extends StatelessWidget {
  const TourMiniTipCard({
    super.key,
    required this.controller,
    required this.waiting,
  });
  final VendorTourController controller;
  final bool waiting;
  @override
  Widget build(BuildContext context) {
    final calendar = controller.step == 4 && controller.calendarOpened;
    final language =
        controller.step == 5 &&
        controller.target(TourTargets.languages) != null;
    final title = switch (controller.step) {
      0 => AppSettingsScope.translate(
        context,
        "vendor.your_real_dashboard.cd75e3fd",
      ),
      1 => AppSettingsScope.translate(context, "vendor.add_from_here.6c2a4975"),
      2 => AppSettingsScope.translate(
        context,
        "vendor.create_a_business.becba6ab",
      ),
      3 => AppSettingsScope.translate(
        context,
        "vendor.this_is_your_business_form.f1d542a4",
      ),
      4 =>
        calendar
            ? AppSettingsScope.translate(
                context,
                "vendor.dates_booking_history.78b116ed",
              )
            : AppSettingsScope.translate(
                context,
                "vendor.your_booking_calendar.81335eeb",
              ),
      _ =>
        language
            ? AppSettingsScope.translate(
                context,
                "vendor.choose_only_if_you_want.c88064a7",
              )
            : AppSettingsScope.translate(
                context,
                "vendor.profile_app_settings.600f6ee8",
              ),
    };
    final message = switch (controller.step) {
      0 => AppSettingsScope.translate(
        context,
        "vendor.booking_updates_appear_here_tap_the_highlight.8fa9d95e",
      ),
      1 => AppSettingsScope.translate(
        context,
        "vendor.your_services_live_on_this_screen_tap_the_act.de0a778f",
      ),
      2 =>
        controller.targetId == TourTargets.add
            ? AppSettingsScope.translate(
                context,
                "vendor.tap_to_reopen_the_add_menu.532f3352",
              )
            : AppSettingsScope.translate(
                context,
                "vendor.tap_add_a_business_add_a_service_is_where_pho.1586d638",
              ),
      3 => AppSettingsScope.translate(
        context,
        "vendor.use_one_category_per_business_then_add_contac.a380ac82",
      ),
      4 =>
        calendar
            ? AppSettingsScope.translate(
                context,
                "vendor.tap_a_real_date_to_see_its_bookings_and_histo.34e5f5ce",
              )
            : AppSettingsScope.translate(
                context,
                "vendor.accept_or_reject_requests_here_after_checking.e11d94b6",
              ),
      _ =>
        language
            ? AppSettingsScope.translate(
                context,
                "vendor.this_is_the_real_language_screen_selecting_a_.9a51ba9a",
              )
            : AppSettingsScope.translate(
                context,
                "vendor.me_has_profile_businesses_and_help_tap_langua.617f9a96",
              ),
    };
    return Material(
      color: Colors.white,
      elevation: 12,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF80152C),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: AppSettingsScope.translate(
                    context,
                    "vendor.skip_tour.5ac614de",
                  ),
                  onPressed: () => controller.cancel(),
                  visualDensity: VisualDensity.compact,
                  iconSize: 18,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  controller.busy
                      ? AppSettingsScope.translate(
                          context,
                          "vendor.opening_the_real_screen.de36567a",
                        )
                      : message,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.45,
                    color: Color(0xFF4E4E59),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  '${controller.step + 1}/6',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF73737D),
                  ),
                ),
                const SizedBox(width: 4),
                if (controller.step > 0)
                  IconButton(
                    tooltip: AppSettingsScope.translate(
                      context,
                      "vendor.previous_tip.114e5302",
                    ),
                    onPressed: controller.busy ? null : controller.back,
                    visualDensity: VisualDensity.compact,
                    iconSize: 19,
                    icon: const Icon(Icons.arrow_back),
                  ),
                const Spacer(),
                if (controller.canContinue)
                  Flexible(
                    child: FilledButton(
                      onPressed: controller.busy ? null : controller.next,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        minimumSize: const Size(0, 36),
                      ),
                      child: Text(
                        controller.step == 5
                            ? AppSettingsScope.translate(
                                context,
                                "vendor.finish.a6c7a84b",
                              )
                            : controller.step == 3
                            ? AppSettingsScope.translate(
                                context,
                                "vendor.bookings.4e5f81ad",
                              )
                            : AppSettingsScope.translate(
                                context,
                                "vendor.me.d30af076",
                              ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: Text(
                      waiting
                          ? AppSettingsScope.translate(
                              context,
                              "vendor.loading_target.b77c2865",
                            )
                          : AppSettingsScope.translate(
                              context,
                              "vendor.tap_highlighted_button.faf51da6",
                            ),
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF73737D),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
