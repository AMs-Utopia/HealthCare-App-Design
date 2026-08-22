import 'package:flutter/material.dart';

import '../models/appointment.dart';
import '../models/lab_test.dart';
import '../models/order.dart';
import '../models/patient_notification.dart';
import '../models/signed_in_user.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/screen_header.dart';

/// What sits behind the patient's bell.
///
/// Three different things light that bell - something happening to an
/// appointment, a medicine order being placed, and a lab test being booked -
/// and before this screen existed the bell went straight to the appointments
/// list, which could only ever show one of them. So they are read here
/// instead, merged into one list in time order by the API.
///
/// Opening this screen is what marks everything read, which is what clears the
/// dot. That is why the whole list is fetched with mark_seen set: there is no
/// half-read state to keep, because everything that lit the bell is on the
/// screen the moment it opens. The rows that were new when it opened still say
/// so - the server reads before it marks - so the patient can see what they
/// have not seen before it stops being new.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, required this.patient});

  final SignedInUser patient;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<PatientNotification> _items = [];
  bool _isLoading = true;
  String _message = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _load(markSeen: true);
  }

  /// [markSeen] is true only for the first load - the one that means the
  /// patient opened the screen. Pulling to refresh afterwards must not mark
  /// anything, because by then there is nothing left unmarked to mark, and
  /// sending it again would be claiming a second reading that never happened.
  Future<void> _load({bool markSeen = false}) async {
    if (mounted && !markSeen) setState(() => _isLoading = true);

    final result = await NotificationService.fetchFeed(
      widget.patient.id,
      markSeen: markSeen,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result.isSuccess) {
        _items = result.items;
        _message = result.message;
        _error = null;
      } else {
        _error = result.error;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: AppBottomNav(
        current: null,
        patient: widget.patient,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ScreenHeader(title: 'Notifications'),
              const SizedBox(height: 14),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.logoGreen),
      );
    }

    if (_error != null) {
      return _Note(
        icon: Icons.wifi_off_outlined,
        title: 'Could not load your notifications',
        detail: _error!,
      );
    }

    if (_items.isEmpty) {
      return _Note(
        icon: Icons.notifications_none,
        title: 'Nothing here yet',
        detail: _message.isEmpty
            ? 'Book an appointment or order medicine, and it will show up here.'
            : _message,
      );
    }

    return RefreshIndicator(
      color: AppColors.logoGreen,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: 8),
        itemCount: _items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, index) => _NotificationRow(item: _items[index]),
      ),
    );
  }
}

/// One row of the list, whichever kind it turns out to be.
///
/// The two kinds share a shape - a coloured stripe, a heading with an icon and
/// a timestamp, then what happened - so the list reads as one list rather than
/// two that were stapled together. What fills that shape is where they differ.
class _NotificationRow extends StatelessWidget {
  const _NotificationRow({required this.item});

  final PatientNotification item;

  /// The one place a colour is attached to a kind of notification. Appointment
  /// rows keep the three colours the appointments screen already uses, so a
  /// cancellation is the same red in both places.
  Color get _colour {
    if (item.kind == NotificationKind.order) return AppColors.logoBlue;
    if (item.kind == NotificationKind.labTest) return AppColors.logoGreen;

    switch (item.appointment?.action) {
      case AppointmentAction.booked:
        return AppColors.historyBooked;
      case AppointmentAction.rescheduled:
        return AppColors.historyRescheduled;
      case AppointmentAction.cancelled:
        return AppColors.historyCancelled;
      case AppointmentAction.unknown:
      case null:
        return AppColors.textMuted;
    }
  }

  IconData get _icon {
    if (item.kind == NotificationKind.order) {
      return Icons.shopping_bag_outlined;
    }

    if (item.kind == NotificationKind.labTest) {
      return Icons.biotech_outlined;
    }

    switch (item.appointment?.action) {
      case AppointmentAction.booked:
        return Icons.event_available_outlined;
      case AppointmentAction.rescheduled:
        return Icons.event_repeat_outlined;
      case AppointmentAction.cancelled:
        return Icons.event_busy_outlined;
      case AppointmentAction.unknown:
      case null:
        return Icons.notifications_none;
    }
  }

  String get _heading {
    if (item.kind == NotificationKind.order) {
      return 'Order #${item.order?.id ?? 0} placed';
    }

    if (item.kind == NotificationKind.labTest) {
      return 'Lab test booked';
    }

    return item.appointment?.action.label ?? 'Updated';
  }

  @override
  Widget build(BuildContext context) {
    final colour = _colour;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.fieldBorder, width: 1.5),
      ),
      // clipBehavior lets the coloured stripe follow the rounded corners
      // instead of poking out past them.
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 7, color: colour),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(_icon, size: 17, color: colour),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            _heading,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: colour,
                            ),
                          ),
                        ),

                        // Marks what the patient had not seen before opening
                        // this screen. It survives this one viewing and is
                        // gone by the next, which is the point of it.
                        if (item.isNew) ...[
                          const SizedBox(width: 6),
                          const _NewChip(),
                        ],

                        const Spacer(),
                        Flexible(
                          child: Text(
                            item.formattedTimestamp,
                            textAlign: TextAlign.right,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    if (item.kind == NotificationKind.order)
                      _OrderBody(order: item.order)
                    else if (item.kind == NotificationKind.labTest)
                      _LabTestBody(booking: item.labTest)
                    else
                      _AppointmentBody(entry: item.appointment),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What an order notification says: what it came to, and what was on it.
class _OrderBody extends StatelessWidget {
  const _OrderBody({required this.order});

  final OrderSummary? order;

  @override
  Widget build(BuildContext context) {
    final order = this.order;

    if (order == null) {
      return const Text(
        'An order was placed.',
        style: TextStyle(fontSize: 14, color: AppColors.textDark),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              order.totalLine,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                order.countLine,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ],
        ),

        // What was actually ordered. Without it the row would say a number was
        // spent and leave the patient to remember on what.
        if (order.medicines != null && order.medicines!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            order.medicines!,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textMuted,
              height: 1.35,
            ),
          ),
        ],

        const SizedBox(height: 6),
        Text(
          'Status: ${order.status}',
          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
      ],
    );
  }
}

/// What a lab booking notification says: what was booked, where to turn up,
/// and what it costs. The hospital is the point of it - a test the patient
/// cannot find their way to is not booked in any useful sense.
class _LabTestBody extends StatelessWidget {
  const _LabTestBody({required this.booking});

  final LabBookingSummary? booking;

  @override
  Widget build(BuildContext context) {
    final booking = this.booking;

    if (booking == null) {
      return const Text(
        'A lab test was booked.',
        style: TextStyle(fontSize: 14, color: AppColors.textDark),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (booking.tests != null && booking.tests!.isNotEmpty)
          Text(
            booking.tests!,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
              height: 1.3,
            ),
          ),

        if (booking.hospitalLine != null) ...[
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.local_hospital_outlined,
                size: 14,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  booking.hospitalLine!,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textMuted,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ],

        const SizedBox(height: 6),
        Row(
          children: [
            Text(
              booking.totalLine,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Status: ${booking.status}',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ),
      ],
    );
  }
}

/// What an appointment notification says. The same two lines the appointments
/// screen shows on its own history rows, so the two never read differently
/// about the same event.
class _AppointmentBody extends StatelessWidget {
  const _AppointmentBody({required this.entry});

  final AppointmentHistoryEntry? entry;

  @override
  Widget build(BuildContext context) {
    final entry = this.entry;

    if (entry == null) {
      return const Text(
        'Something changed on one of your appointments.',
        style: TextStyle(fontSize: 14, color: AppColors.textDark),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          entry.description,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textDark,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${entry.doctorDisplayName}  ·  ${entry.hospitalLine}',
          style: const TextStyle(
            fontSize: 12.5,
            color: AppColors.textMuted,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}

/// The little "New" marker on a row the patient had not seen.
class _NewChip extends StatelessWidget {
  const _NewChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.logoGreen,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        'New',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// The middle of the screen when there is nothing to list, or nothing loaded.
class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.title, required this.detail});

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
