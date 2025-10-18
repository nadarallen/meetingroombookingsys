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
    final timeRange = '${_formatDate(booking.startTime)} -> ${_formatDate(booking.endTime)}';
    return ListTile(
      leading: const Icon(Icons.event_note),
      title: Text(booking.title ?? 'Booking'),
      subtitle: Text('$timeRange\nStatus: ${status.toUpperCase()}'),
      isThreeLine: true,
    );
  }

  String _formatDate(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} '
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}
