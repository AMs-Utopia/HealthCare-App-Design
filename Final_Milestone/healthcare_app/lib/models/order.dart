/// Ordering medicine, as the app understands it.
///
/// The idea these classes are built around:
///
///   A patient orders from the same catalogue a doctor prescribes from. They
///   type the brand they want and get every real Bangladeshi brand starting
///   that way, straight off MedEx - not a shortlist somebody typed into this
///   app's database.
///
/// What ordering adds on top of prescribing is a price, and a price is the one
/// thing MedEx's suggestion list does not carry. So a brand arrives from the
/// search unpriced ([MedicineOption], shared with the doctor's write up screen)
/// and becomes a [PricedMedicine] only once its price has been read off its own
/// MedEx page. That is why the two are separate types: an unpriced brand cannot
/// be put on an order, and the type system is where that should be said rather
/// than in a comment somebody has to remember.
library;

import 'appointment.dart';

/// Money, as it is written on this screen.
///
/// Prices come off MedEx in taka and go into decimal(10,2) columns, so two
/// decimal places is not a display choice - it is the precision the whole
/// chain works in. The thousands separator is done by hand because the app has
/// no formatting package; it only ever has to cope with a medicine order.
///
/// The symbol is the one place the currency is written. If it ever renders as
/// an empty box on a device whose fonts have no Bengali taka sign, this is the
/// single line to change.
String formatTaka(double amount) {
  final fixed = amount.toStringAsFixed(2);
  final dot = fixed.indexOf('.');
  final whole = fixed.substring(0, dot);
  final fraction = fixed.substring(dot);

  final grouped = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    // Counted from the right, a separator goes before every third digit.
    if (i > 0 && (whole.length - i) % 3 == 0) grouped.write(',');
    grouped.write(whole[i]);
  }

  return '৳ $grouped$fraction';
}

/// A brand the patient has picked, with its price settled.
///
/// [unitPrice] is what ONE of them costs, and [unitLabel] is what "one" means.
/// The two have to travel together: a tablet is sold by the piece and says
/// nothing extra, but there is no such thing as one millilitre of syrup to buy,
/// so a syrup is priced by its bottle and has to say so. Showing ৳28.00 "each"
/// against a bottle of Monamox would be a straightforwardly false statement
/// about what the patient is paying for.
class PricedMedicine {
  const PricedMedicine({
    required this.medicineId,
    required this.name,
    required this.unitPrice,
    this.dosage,
    this.unitLabel,
    this.packInfo,
    this.priceSource = 'medex',
  });

  /// Our own MEDICINE.medicine_id. Always set - the row is created by the
  /// price lookup if this is the first time anyone has ordered or prescribed
  /// the brand, so an order line always has something real to point at.
  final int medicineId;

  /// The brand on its own, e.g. "Rostil SR".
  final String name;

  /// Strength and dosage form together, e.g. "200 mg Capsule (Sustained
  /// Release)", which is what MEDICINE.dosage holds.
  final String? dosage;

  /// What one of them costs.
  final double unitPrice;

  /// What "one" is, when it is not simply one of the things: "15 ml bottle",
  /// "40 mg vial", "15 mg tube". Null for anything sold by the piece.
  final String? unitLabel;

  /// MedEx's own note about how they are boxed, e.g. "3 x 10: ৳ 300.00". Shown
  /// as a note and never used to work anything out - the order is counted in
  /// units, not boxes.
  final String? packInfo;

  /// 'medex' for a live lookup, 'stored' when MedEx could not be reached and
  /// the price kept from an earlier lookup was used instead.
  final String priceSource;

  /// True when this price was read live rather than remembered.
  bool get isLivePrice => priceSource == 'medex';

  /// How the brand reads on a line of the order.
  String get label =>
      dosage == null || dosage!.isEmpty ? name : '$name  $dosage';

  /// The price, with what it buys: "৳ 10.00 each", "৳ 28.00 per 15 ml bottle".
  String get unitPriceLine => unitLabel == null || unitLabel!.isEmpty
      ? '${formatTaka(unitPrice)} each'
      : '${formatTaka(unitPrice)} per $unitLabel';

  factory PricedMedicine.fromJson(Map<String, dynamic> json) {
    return PricedMedicine(
      medicineId: int.tryParse('${json['medicine_id']}') ?? 0,
      name: (json['medicine_name'] as String?) ?? '',
      dosage: json['dosage'] as String?,
      // Sent as a string so the decimal survives the trip exactly as MySQL
      // will hold it, rather than arriving as a float that has already been
      // rounded somewhere.
      unitPrice: double.tryParse('${json['unit_price']}') ?? 0,
      unitLabel: json['unit_label'] as String?,
      packInfo: json['pack_info'] as String?,
      priceSource: (json['price_source'] as String?) ?? 'medex',
    );
  }
}

/// One line of the order while the patient is still building it.
///
/// This is the whole of the basket. It lives in the screen's own memory and
/// reaches the database only when the order is confirmed, so a medicine added
/// and then taken off again never touches it. CART and CART_ITEM stay empty on
/// purpose: those are for a basket that survives closing the app, which is a
/// bigger promise than this screen makes.
class OrderLine {
  OrderLine({required this.medicine, this.quantity = 1});

  final PricedMedicine medicine;

  /// How many. Never below 1 - taking the last one off removes the line
  /// instead, because a line for nought of something is not an order for
  /// nothing, it is a line that should not be there.
  int quantity;

  double get lineTotal => medicine.unitPrice * quantity;

  /// What the server is told. The price is deliberately not in here: the app
  /// says what was picked and how many, and the total is worked out from the
  /// stored prices on the other side. A price that travelled with the request
  /// would be a price the request could choose.
  Map<String, dynamic> toJson() => {
    'medicine_id': medicine.medicineId,
    'quantity': quantity,
  };
}

/// An order once it has been placed.
class PlacedOrder {
  const PlacedOrder({
    required this.id,
    required this.totalCost,
    required this.medicineCount,
    this.orderDate,
    this.status = 'Placed',
  });

  final int id;

  /// As the server totalled it, which is the figure that was stored.
  final double totalCost;

  final int medicineCount;
  final String? orderDate;
  final String status;

  String get totalLine => formatTaka(totalCost);

  factory PlacedOrder.fromJson(Map<String, dynamic> json) {
    return PlacedOrder(
      id: int.tryParse('${json['order_id']}') ?? 0,
      totalCost: double.tryParse('${json['total_cost']}') ?? 0,
      medicineCount: int.tryParse('${json['medicine_count']}') ?? 0,
      orderDate: json['order_date'] as String?,
      status: (json['status'] as String?) ?? 'Placed',
    );
  }
}

/// What one unit of a medicine is called, worked out from its dosage form.
///
/// The order screen counts in units, and the units of one medicine are not the
/// units of another: ten of a capsule is ten capsules, ten of a cream is ten
/// tubes. MEDICINE.dosage holds the strength and the form together ("200 mg
/// Capsule (Sustained Release)"), so the form is read back out of it here.
///
/// A form nobody listed answers null rather than guessing. The row then shows
/// a plain multiplier instead, which says exactly as much as is actually
/// known - "x 10" is never wrong, whereas calling ten of something "tablets"
/// when it is an inhaler is.
String? unitNoun(String? dosage, int quantity) {
  if (dosage == null || dosage.isEmpty) return null;

  final form = dosage.toLowerCase();
  final many = quantity != 1;

  // Order matters. "Powder for Suspension" is a bottle you mix, not a sachet,
  // so suspension has to be looked for before powder.
  const forms = <List<String>, List<String>>{
    ['suppositor']: ['suppository', 'suppositories'],
    ['capsule']: ['capsule', 'capsules'],
    ['tablet']: ['tablet', 'tablets'],
    ['syrup', 'suspension', 'solution', 'elixir', 'drop', 'bottle']: [
      'bottle',
      'bottles',
    ],
    ['injection', 'infusion', 'vial', 'ampoule']: ['vial', 'vials'],
    ['cream', 'ointment', 'gel', 'lotion', 'tube']: ['tube', 'tubes'],
    ['sachet', 'granule', 'powder']: ['sachet', 'sachets'],
    ['inhaler', 'inhalation']: ['inhaler', 'inhalers'],
  };

  for (final entry in forms.entries) {
    for (final keyword in entry.key) {
      if (form.contains(keyword)) {
        return many ? entry.value[1] : entry.value[0];
      }
    }
  }

  return null;
}

/// One medicine on an order that has already been placed.
///
/// [unitPrice] is what it was BOUGHT at, off the ORDER_ITEM row - not what the
/// medicine costs now. MedEx prices move, and lines that quietly repriced
/// themselves would stop adding up to the total printed on the same card.
class OrderedMedicine {
  const OrderedMedicine({
    required this.orderItemId,
    required this.medicineId,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    this.dosage,
  });

  final int orderItemId;
  final int medicineId;
  final String name;

  /// Strength and dosage form together, e.g. "200 mg Capsule (Sustained
  /// Release)".
  final String? dosage;

  final int quantity;
  final double unitPrice;
  final double lineTotal;

  /// How the brand reads on the row, e.g. "Rostil SR  200 mg Capsule".
  String get label =>
      dosage == null || dosage!.isEmpty ? name : '$name  $dosage';

  /// How many, in the medicine's own units: "10 capsules", "10 tablets", or a
  /// plain "x 10" for a form the app has no word for.
  String get quantityLine {
    final noun = unitNoun(dosage, quantity);

    return noun == null ? 'x $quantity' : '$quantity $noun';
  }

  String get unitPriceLine => '${formatTaka(unitPrice)} each';

  String get lineTotalLine => formatTaka(lineTotal);

  factory OrderedMedicine.fromJson(Map<String, dynamic> json) {
    return OrderedMedicine(
      orderItemId: int.tryParse('${json['order_item_id']}') ?? 0,
      medicineId: int.tryParse('${json['medicine_id']}') ?? 0,
      name: (json['medicine_name'] as String?) ?? '',
      dosage: json['dosage'] as String?,
      quantity: int.tryParse('${json['quantity']}') ?? 0,
      unitPrice: double.tryParse('${json['unit_price']}') ?? 0,
      lineTotal: double.tryParse('${json['line_total']}') ?? 0,
    );
  }
}

/// One order in the patient's history: the header, and what was on it.
///
/// The lines travel with the order rather than being fetched per card, because
/// an order and its medicines are one thing on screen - the card cannot be
/// drawn without both.
class OrderHistoryEntry {
  const OrderHistoryEntry({
    required this.id,
    required this.totalCost,
    required this.items,
    this.orderDate,
    this.status = 'Placed',
  });

  final int id;

  /// As the server totalled it when the order was placed, which is the figure
  /// that was stored. It is never re-added from the lines here - if the two
  /// ever disagreed, the stored total is what the patient was charged.
  final double totalCost;

  final String? orderDate;
  final String status;
  final List<OrderedMedicine> items;

  String get totalLine => formatTaka(totalCost);

  /// The order number as the wireframe writes it.
  String get idLine => 'Order ID = $id';

  /// When it was placed, in the same wording the rest of the app uses.
  String? get placedLine =>
      orderDate == null ? null : formatHistoryTimestamp(orderDate!);

  /// "2 medicines · 20 units", counted from the lines themselves.
  String get countLine {
    final units = items.fold<int>(0, (running, item) => running + item.quantity);
    final medicineWord = items.length == 1 ? 'medicine' : 'medicines';
    final unitWord = units == 1 ? 'unit' : 'units';

    return '${items.length} $medicineWord  ·  $units $unitWord';
  }

  factory OrderHistoryEntry.fromJson(Map<String, dynamic> json) {
    final rows = json['items'];

    return OrderHistoryEntry(
      id: int.tryParse('${json['order_id']}') ?? 0,
      totalCost: double.tryParse('${json['total_cost']}') ?? 0,
      orderDate: json['order_date'] as String?,
      status: (json['status'] as String?) ?? 'Placed',
      items: rows is List
          ? rows
                .whereType<Map<String, dynamic>>()
                .map(OrderedMedicine.fromJson)
                .toList()
          : const [],
    );
  }
}

/// One of the patient's orders as their notifications list shows it.
///
/// Deliberately a summary rather than the lines themselves: the notification
/// says what was ordered and what it came to, it is not an invoice. A purchase
/// history screen that wants the individual lines can ask for them when it is
/// built.
class OrderSummary {
  const OrderSummary({
    required this.id,
    required this.totalCost,
    required this.medicineCount,
    required this.unitCount,
    this.orderDate,
    this.status = 'Placed',
    this.medicines,
  });

  final int id;
  final double totalCost;

  /// How many different medicines were on it.
  final int medicineCount;

  /// How many units in total across all of them.
  final int unitCount;

  final String? orderDate;
  final String status;

  /// What was on it, as one line: "Rostil SR x 2, Ace x 10".
  final String? medicines;

  String get totalLine => formatTaka(totalCost);

  /// "2 medicines · 12 units", which is what the row says under the heading.
  String get countLine {
    final medicineWord = medicineCount == 1 ? 'medicine' : 'medicines';
    final unitWord = unitCount == 1 ? 'unit' : 'units';

    return '$medicineCount $medicineWord  ·  $unitCount $unitWord';
  }

  factory OrderSummary.fromJson(Map<String, dynamic> json) {
    return OrderSummary(
      id: int.tryParse('${json['order_id']}') ?? 0,
      totalCost: double.tryParse('${json['total_cost']}') ?? 0,
      medicineCount: int.tryParse('${json['medicine_count']}') ?? 0,
      unitCount: int.tryParse('${json['unit_count']}') ?? 0,
      orderDate: json['order_date'] as String?,
      status: (json['status'] as String?) ?? 'Placed',
      medicines: json['medicines'] as String?,
    );
  }
}
