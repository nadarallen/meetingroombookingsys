import '../entities/booking.dart';

abstract class BookingRepository {
  Future<List<Booking>> fetchBookings();
  Future<void> createBooking(Booking booking);
}

