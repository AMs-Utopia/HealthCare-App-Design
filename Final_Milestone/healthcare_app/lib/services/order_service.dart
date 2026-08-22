import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../config/api_client.dart';

import '../config/api_config.dart';
import '../models/api_response.dart';
import '../models/emr.dart';
import '../models/order.dart';
import 'emr_service.dart';

/// A patient ordering medicine: finding a brand, what it costs, and placing
/// the order.
class OrderService {
  // Only static helpers, never instantiated.
  OrderService._();

  /// Brands matching what the patient has typed.
  ///
  /// This is deliberately the doctor's medicine search, unchanged and not
  /// copied: there is one catalogue of Bangladeshi medicine brands, read live
  /// off MedEx, and it would be strange for a patient to be able to order
  /// something their doctor could not prescribe or the other way round. The
  /// call lives on [EmrService] only because the write up screen was the first
  /// thing to need it.
  static Future<MedicineSearchResult> searchMedicines(String query) =>
      EmrService.searchMedicines(query);

  /// What one of a brand costs, and the medicine row an order line points at.
  ///
  /// Called when the patient taps a suggestion to add it, never while they are
  /// typing. MedEx's suggestion list carries no price at all, so a price means
  /// loading that brand's own page - one request for the medicine actually
  /// chosen, rather than twenty five on every keystroke.
  ///
  /// [option] is whatever the search handed back. A live suggestion carries a
  /// MedEx id and is priced from its page; one from the offline fallback
  /// carries our own medicine id instead and is answered with the price stored
  /// the last time it was looked up.
  static Future<PriceResult> priceFor(MedicineOption option) async {
    try {
      final uri = ApiConfig.endpoint('medicine_price.php').replace(
        queryParameters: {
          if (option.medexId != null) 'medex_id': '${option.medexId}',
          if (option.id > 0) 'medicine_id': '${option.id}',
          'medicine_name': option.name,
          if (option.dosage != null) 'dosage': option.dosage!,
        },
      );

      final response = await ApiClient.get(uri).timeout(ApiConfig.timeout);

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        return PriceResult.failure(
          'The server sent back something unexpected. Check the PHP error log.',
        );
      }

      final parsed = ApiResponse.fromJson(decoded);

      // A medicine MedEx publishes no price for is refused here rather than
      // added at nought, and the server's own wording says which brand and
      // why. That is a real answer, not a breakage.
      if (!parsed.success || parsed.data == null) {
        return PriceResult.failure(parsed.message);
      }

      return PriceResult.success(
        PricedMedicine.fromJson(parsed.data!),
        parsed.message,
      );
    } on SocketException {
      return PriceResult.failure(
        'Cannot reach the server at ${ApiConfig.baseUrl}.\n'
        'Check that Apache and MySQL are running in XAMPP.',
      );
    } on TimeoutException {
      return PriceResult.failure(
        'Looking that price up took too long. Please try again.',
      );
    } on FormatException {
      return PriceResult.failure(
        'The server did not send valid JSON for the price lookup.',
      );
    }
  }

  /// Placing the order - the Yes on "Are you sure?".
  ///
  /// Only what was picked and how many of it is sent. No price and no total
  /// leave the phone: the server totals the order from the prices it stored
  /// when each medicine was added, so the figure that is saved cannot be one
  /// the app decided.
  static Future<PlacedOrderResult> placeOrder({
    required int patientId,
    required List<OrderLine> lines,
  }) async {
    try {
      final response = await ApiClient
          .post(
            ApiConfig.endpoint('place_order.php'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'patient_id': patientId,
              'items': lines.map((line) => line.toJson()).toList(),
            }),
          )
          .timeout(ApiConfig.timeout);

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        return PlacedOrderResult.failure(
          'The server sent back something unexpected. Check the PHP error log.',
        );
      }

      final parsed = ApiResponse.fromJson(decoded);

      if (!parsed.success || parsed.data == null) {
        return PlacedOrderResult.failure(parsed.message);
      }

      return PlacedOrderResult.success(
        PlacedOrder.fromJson(parsed.data!),
        parsed.message,
      );
    } on SocketException {
      return PlacedOrderResult.failure(
        'Cannot reach the server at ${ApiConfig.baseUrl}.\n'
        'Check that Apache and MySQL are running in XAMPP.',
      );
    } on TimeoutException {
      // Deliberately worded as "may not have been placed" rather than "was
      // not": the request could have reached the server and been written
      // before the app gave up waiting. Telling the patient it failed would
      // invite them to order the same medicines twice.
      return PlacedOrderResult.failure(
        'The server took too long to answer, so the order may not have been '
        'placed. Check your notifications before ordering again.',
      );
    } on FormatException {
      return PlacedOrderResult.failure(
        'The server did not send valid JSON. Open the endpoint in a browser '
        'to see the PHP error.',
      );
    }
  }

  /// Everything this patient has ever ordered, newest first.
  ///
  /// Each order comes back whole - the total and the medicines that were on
  /// it - because that is one card on the Order History screen, and fetching
  /// the lines separately would make it fill itself in twice.
  static Future<OrderHistoryResult> fetchHistory(int patientId) async {
    try {
      final uri = ApiConfig.endpoint(
        'order_history.php',
      ).replace(queryParameters: {'patient_id': '$patientId'});

      final response = await ApiClient.get(uri).timeout(ApiConfig.timeout);

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        return OrderHistoryResult.failure(
          'The server sent back something unexpected. Check the PHP error log.',
        );
      }

      final parsed = ApiResponse.fromJson(decoded);

      if (!parsed.success) {
        return OrderHistoryResult.failure(parsed.message);
      }

      final rows = parsed.data?['orders'];

      // An empty list is a normal answer - a patient who has never ordered
      // anything - so it is a success carrying the server's own wording rather
      // than an error.
      return OrderHistoryResult.success(
        rows is List
            ? rows
                  .whereType<Map<String, dynamic>>()
                  .map(OrderHistoryEntry.fromJson)
                  .toList()
            : const [],
        parsed.message,
      );
    } on SocketException {
      return OrderHistoryResult.failure(
        'Cannot reach the server at ${ApiConfig.baseUrl}.\n'
        'Check that Apache and MySQL are running in XAMPP.',
      );
    } on TimeoutException {
      return OrderHistoryResult.failure(
        'The server took too long to answer. Please try again.',
      );
    } on FormatException {
      return OrderHistoryResult.failure(
        'The server did not send valid JSON. Open the endpoint in a browser '
        'to see the PHP error.',
      );
    }
  }
}

/// Either the patient's orders, or why they could not be loaded.
class OrderHistoryResult {
  const OrderHistoryResult._(this.orders, this.message, this.error);

  const OrderHistoryResult.success(
    List<OrderHistoryEntry> orders,
    String message,
  ) : this._(orders, message, null);

  const OrderHistoryResult.failure(String error)
    : this._(const [], '', error);

  final List<OrderHistoryEntry> orders;
  final String message;
  final String? error;

  bool get isSuccess => error == null;
}

/// Either a priced medicine, or why it has no price.
class PriceResult {
  const PriceResult._(this.medicine, this.message, this.error);

  const PriceResult.success(PricedMedicine medicine, String message)
    : this._(medicine, message, null);

  const PriceResult.failure(String error) : this._(null, '', error);

  final PricedMedicine? medicine;
  final String message;
  final String? error;

  bool get isSuccess => error == null && medicine != null;
}

/// Either the order that was placed, or why it was not.
class PlacedOrderResult {
  const PlacedOrderResult._(this.order, this.message, this.error);

  const PlacedOrderResult.success(PlacedOrder order, String message)
    : this._(order, message, null);

  const PlacedOrderResult.failure(String error) : this._(null, '', error);

  final PlacedOrder? order;
  final String message;
  final String? error;

  bool get isSuccess => error == null && order != null;
}
