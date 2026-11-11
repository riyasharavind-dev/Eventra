# Customer bookings

The customer Bookings screen follows the vendor app layout: heading, shared search input, calendar action, booking count, status chips and compact photo cards. Customer operations remain separate: no vendor acceptance/rejection/completion controls or vendor-only RPCs are used.

- screens/main/bookings_screen.dart: searchable/status-filtered list, realtime refresh and pull-to-refresh.
- screens/extended/booking_details_screen.dart: full booking identity, schedule, vendor, location, guest count, requirements, status reason and created date. Completed bookings link to the existing customer My Reviews workflow.
- screens/extended/eventor_calendar.dart: month calendar, selection and day-by-day history including past/completed/rejected/cancelled bookings.
- widgets/bookings/customer_booking_card.dart: vendor-style card with customer navigation.
- widgets/bookings/booking_history_card.dart: shared-style timeline card.
- widgets/bookings/booking_ui.dart: schedule formatting, photo fallback and status chip.
- widgets/dashboard/minimal_booking_calendar.dart and booking_month_calendar.dart: vendor-style circular date selection, status dots and year limits.
- models/booking_model.dart, booking_list_filter.dart and calendar_bookings.dart: typed customer schedule and deterministic filtering/day matching.
- repositories/booking_repository.dart: existing booking creation plus customer-owned list/detail reads, with optional client injection.

Existing RLS is retained. No database migration is needed. Multi-day bookings include all occupied days; a midnight end excludes the final day. Calendar years unlock with the current year. Search and realtime refresh retain the current selection and loaded data on refresh errors.
