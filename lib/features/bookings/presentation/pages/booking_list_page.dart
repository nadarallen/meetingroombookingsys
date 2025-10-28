import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/database/database_sync_manager.dart';
import '../../../../core/database/local_database.dart';
import '../../../../core/database/models/booking.dart' as db;
import '../../../../shared/widgets/app_error.dart';
import '../../../../shared/widgets/app_loading.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../viewmodels/booking_view_model.dart';
import 'edit_booking_page.dart';

class BookingListPage extends StatelessWidget {
  const BookingListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<BookingViewModel>(
      create: (context) => BookingViewModel(
        syncManager: context.read<DatabaseSyncManager>(),
        localDatabase: context.read<LocalDatabase>(),
        currentUserId: () => context.read<AuthViewModel>().user?.uid,
      )..load(),
      child: const _BookingListView(),
    );
  }
}

class _BookingListView extends StatefulWidget {
  const _BookingListView();

  @override
  State<_BookingListView> createState() => _BookingListViewState();
}

class _BookingListViewState extends State<_BookingListView> {
  @override
  Widget build(BuildContext context) {
    final vm = context.watch<BookingViewModel>();
    final error = vm.error;

    if (error != null && vm.bookings.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text(error)));
        vm.clearError();
      });
    }

    if (vm.loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Bookings')),
        body: const AppLoading(message: 'Loading bookings...'),
      );
    }

    if (vm.error != null && vm.bookings.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Bookings')),
        body: AppError(message: vm.error!, onRetry: vm.refresh),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _goNew(context, vm),
          icon: const Icon(Icons.add),
          label: const Text('New Booking'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Bookings')),
      body: vm.bookings.isEmpty
          ? const Center(child: Text('No bookings yet.'))
          : ListView.separated(
              itemCount: vm.bookings.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final booking = vm.bookings[index];
                return _BookingTile(booking: booking);
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _goNew(context, vm),
        icon: const Icon(Icons.add),
        label: const Text('New Booking'),
      ),
    );
  }

  Future<void> _goNew(BuildContext context, BookingViewModel vm) async {
    await context.push('/bookings/new', extra: vm);
    if (context.mounted) {
      await vm.refresh();
    }
  }
}

class _BookingTile extends StatelessWidget {
  const _BookingTile({required this.booking});

  final db.Booking booking;

  @override
  Widget build(BuildContext context) {
    final status = booking.syncStatus == db.SyncStatus.synced
        ? booking.status.name
        : booking.syncStatus.replaceAll('_', ' ');
    final timeRange =
        '${_formatDate(booking.startTime)} - ${_formatTime(booking.endTime)}';
    final duration = _formatDuration(booking.startTime, booking.endTime);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getStatusColor(booking.status),
          child: Icon(
            _getStatusIcon(booking.status),
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          booking.title ?? 'Untitled Booking',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              timeRange,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color:
                        _getStatusColor(booking.status).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: _getStatusColor(booking.status),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  duration,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            if (booking.notes != null && booking.notes!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                booking.notes!,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleMenuAction(context, value),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, size: 20),
                  SizedBox(width: 8),
                  Text('Edit'),
                ],
              ),
            ),
            if (booking.status != db.BookingStatus.cancelled)
              const PopupMenuItem(
                value: 'cancel',
                child: Row(
                  children: [
                    Icon(Icons.cancel, size: 20, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Cancel', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
          ],
        ),
        onTap: () => _handleMenuAction(context, 'edit'),
      ),
    );
  }

  void _handleMenuAction(BuildContext context, String action) {
    switch (action) {
      case 'edit':
        Navigator.of(context)
            .push(
          MaterialPageRoute(
            builder: (context) =>
                ChangeNotifierProvider<BookingViewModel>.value(
              value: context.read<BookingViewModel>(),
              child: EditBookingPage(booking: booking),
            ),
          ),
        )
            .then((_) {
          // Refresh the booking list after editing
          if (context.mounted) {
            context.read<BookingViewModel>().refresh();
          }
        });
        break;
      case 'cancel':
        _showCancelDialog(context);
        break;
    }
  }

  Future<void> _showCancelDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Booking'),
        content: const Text('Are you sure you want to cancel this booking?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final vm = context.read<BookingViewModel>();
      final success = await vm.cancelBooking(booking.id);

      if (context.mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Booking cancelled successfully.')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(vm.error ?? 'Unable to cancel booking.')),
          );
          vm.clearError();
        }
      }
    }
  }

  Color _getStatusColor(db.BookingStatus status) {
    switch (status) {
      case db.BookingStatus.pending:
        return Colors.orange;
      case db.BookingStatus.confirmed:
        return Colors.green;
      case db.BookingStatus.cancelled:
        return Colors.red;
    }
  }

  IconData _getStatusIcon(db.BookingStatus status) {
    switch (status) {
      case db.BookingStatus.pending:
        return Icons.schedule;
      case db.BookingStatus.confirmed:
        return Icons.check_circle;
      case db.BookingStatus.cancelled:
        return Icons.cancel;
    }
  }

  String _formatDate(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  String _formatTime(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  String _formatDuration(DateTime start, DateTime end) {
    final duration = end.difference(start);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }
}
