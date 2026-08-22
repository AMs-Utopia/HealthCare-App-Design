import 'dart:async';

import 'package:flutter/material.dart';

import '../models/emr.dart';
import '../models/order.dart';
import '../models/signed_in_user.dart';
import '../services/order_service.dart';
import '../theme/app_colors.dart';
import '../widgets/primary_button.dart';
import '../widgets/screen_header.dart';

/// Screen 18 (User / Patient) - Order Summary.
///
/// Reached from Services in the patient's drawer, then Order Medicine.
///
/// The patient searches for a brand exactly the way a doctor does when writing
/// a prescription - typing it, with every real Bangladeshi brand coming back
/// live from MedEx - and taps one to put it on the order. Each medicine sits on
/// its own line with a minus, its count and a plus beside it, the total adds up
/// underneath, and Confirm Order asks "Are you sure?" before anything is
/// written.
///
/// The order lives in this screen's memory until it is confirmed. A medicine
/// added and then taken off again never reaches the database at all, which is
/// why CART and CART_ITEM stay empty: those are for a basket that survives
/// closing the app, and this screen does not promise that.
///
/// The one thing ordering needs that prescribing never did is a price. MedEx's
/// suggestion list carries none, so a price is fetched from the chosen brand's
/// own page as it is added - which is why a line takes a moment to appear, and
/// why a medicine MedEx publishes no price for is refused rather than added
/// for nothing.
///
/// Refill on the Medications screen opens this same screen with [refill]
/// already set, so the patient lands on an order that is made up rather than
/// being asked to search for the medicine they have just asked to reorder.
class OrderMedicineScreen extends StatefulWidget {
  const OrderMedicineScreen({
    super.key,
    required this.patient,
    this.refill,
  });

  /// The signed in patient. The order is placed against their account, and
  /// the notification it raises is theirs.
  final SignedInUser patient;

  /// A medicine to start the order with, when the screen was opened by Refill.
  ///
  /// It goes through exactly the same adding as a searched brand - priced on
  /// the way in and refused if it has no price - because a refill is an order
  /// like any other, and a medicine that cannot be priced cannot be bought
  /// however the patient arrived at it.
  final MedicineOption? refill;

  @override
  State<OrderMedicineScreen> createState() => _OrderMedicineScreenState();
}

class _OrderMedicineScreenState extends State<OrderMedicineScreen> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();

  /// The order as it stands. This is the whole basket.
  final List<OrderLine> _lines = [];

  List<MedicineOption> _results = [];
  bool _isSearching = false;
  String _searchMessage = '';
  String? _searchError;

  /// True when the last answer came out of the offline fallback rather than
  /// MedEx, which the patient is told about - three local brands must not look
  /// like all MedEx has.
  bool _isFallback = false;

  /// The brand currently being priced, so its row can show a spinner and no
  /// second tap can add it twice.
  MedicineOption? _pricing;

  /// True from the moment Yes is tapped until the server answers, so the order
  /// cannot be placed twice by an impatient second tap.
  bool _isPlacing = false;

  /// Waits for the patient to stop typing, so "rosuva" is one lookup rather
  /// than six.
  Timer? _debounce;

  /// Guards against an early search answering after a later one. Without it a
  /// slow reply for "ro" could land on top of the results for "rosuv".
  int _requestId = 0;

  /// Longer than the list one screen can show. Anything past this means
  /// another letter, not a scroll.
  static const int _maxShown = 8;

  /// Same as the server's cap, so the plus button stops where the API would
  /// have refused rather than letting the patient hit an error.
  static const int _maxQuantity = 99;

  @override
  void initState() {
    super.initState();

    final refill = widget.refill;

    if (refill != null) {
      // After the first frame, because adding sets state and can raise a
      // snackbar - neither of which may happen while the screen is still
      // being built.
      WidgetsBinding.instance.addPostFrameCallback((_) => _add(refill));
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  double get _total =>
      _lines.fold(0, (running, line) => running + line.lineTotal);

  // ===========================================================================
  // Searching
  // ===========================================================================

  void _onTyped(String value) {
    _debounce?.cancel();

    if (value.trim().length < 2) {
      setState(() {
        _results = [];
        _isSearching = false;
        _searchMessage = '';
        _searchError = null;
      });
      return;
    }

    setState(() => _isSearching = true);
    _debounce = Timer(const Duration(milliseconds: 400), _search);
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.length < 2) return;

    final requestId = ++_requestId;

    final result = await OrderService.searchMedicines(query);

    // A reply for a query the patient has already typed past is thrown away.
    if (!mounted || requestId != _requestId) return;

    setState(() {
      _isSearching = false;
      if (result.isSuccess) {
        _results = result.medicines;
        _searchMessage = result.message;
        _isFallback = !result.isLive;
        _searchError = null;
      } else {
        _results = [];
        _searchError = result.error;
      }
    });
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchController.clear();
    _searchFocus.unfocus();

    setState(() {
      _results = [];
      _isSearching = false;
      _searchMessage = '';
      _searchError = null;
    });
  }

  // ===========================================================================
  // Building the order
  // ===========================================================================

  /// Adds the brand the patient tapped, once its price is known.
  ///
  /// A brand already on the order is counted up rather than added twice: it is
  /// one medicine on the order either way, and a second line for it would make
  /// the screen disagree with what gets stored.
  Future<void> _add(MedicineOption option) async {
    if (_pricing != null || _isPlacing) return;

    final existing = _lineFor(option);

    if (existing != null) {
      final before = existing.quantity;

      _bump(existing, 1);
      _clearSearch();

      // Only said when it actually moved. At the cap _bump has already
      // explained why it did not, and saying "it went up to 99" over the top
      // of that would contradict it.
      if (existing.quantity != before) {
        _say('${existing.medicine.name} is already on the order, so it went '
            'up to ${existing.quantity}.');
      }
      return;
    }

    setState(() => _pricing = option);

    final result = await OrderService.priceFor(option);

    if (!mounted) return;

    setState(() => _pricing = null);

    if (!result.isSuccess) {
      // Most often this is MedEx publishing no price for the brand, which is a
      // real answer rather than a fault - so it is said plainly and the
      // medicine is simply not added.
      _say(result.error!);
      return;
    }

    setState(() => _lines.add(OrderLine(medicine: result.medicine!)));

    _clearSearch();
  }

  /// The line for a brand already on the order, or null.
  ///
  /// Matched on our own medicine id where there is one, and otherwise on the
  /// name and strength together - which is the same pair the MEDICINE table
  /// treats as one brand. Rostil SR 200 mg and Rostil 135 mg are different
  /// things to take, so they are different lines.
  OrderLine? _lineFor(MedicineOption option) {
    for (final line in _lines) {
      if (option.id > 0 && line.medicine.medicineId == option.id) {
        return line;
      }

      final sameName =
          line.medicine.name.toLowerCase() == option.name.toLowerCase();
      final sameDosage =
          (line.medicine.dosage ?? '').toLowerCase() ==
          (option.dosage ?? '').toLowerCase();

      if (sameName && sameDosage) return line;
    }

    return null;
  }

  void _bump(OrderLine line, int by) {
    final wanted = line.quantity + by;

    // Taking the last one off removes the line. A line for nought of something
    // is not an order for none of it, it is a line that should not be there -
    // which is what the minus button means once it reaches 1.
    if (wanted < 1) {
      _remove(line);
      return;
    }

    if (wanted > _maxQuantity) {
      _say('$_maxQuantity is the most you can order of one medicine at a time.');
      return;
    }

    setState(() => line.quantity = wanted);
  }

  void _remove(OrderLine line) {
    setState(() => _lines.remove(line));
    _say('${line.medicine.name} removed from the order.');
  }

  // ===========================================================================
  // Confirming
  // ===========================================================================

  Future<void> _confirm() async {
    if (_lines.isEmpty || _isPlacing) return;

    final sure = await _askAreYouSure();

    if (sure != true || !mounted) return;

    setState(() => _isPlacing = true);

    final result = await OrderService.placeOrder(
      patientId: widget.patient.id,
      lines: _lines,
    );

    if (!mounted) return;

    setState(() => _isPlacing = false);

    if (!result.isSuccess) {
      _say(result.error!);
      return;
    }

    // The basket is emptied only once the order is safely stored, so a failure
    // leaves the patient with everything they picked still in front of them.
    setState(() => _lines.clear());

    await _showPlaced(result.order!);
  }

  /// "Are you sure?" - the last step before anything is written.
  Future<bool?> _askAreYouSure() {
    final medicineWord = _lines.length == 1 ? 'medicine' : 'medicines';

    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Are you sure?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Place this order for ${_lines.length} $medicineWord?',
              style: const TextStyle(fontSize: 15, color: AppColors.textDark),
            ),
            const SizedBox(height: 12),

            // The total is repeated here on purpose. It is the figure the
            // patient is agreeing to, and it should not be behind the dialog
            // they are agreeing in.
            Row(
              children: [
                const Text(
                  'Total cost',
                  style: TextStyle(fontSize: 14, color: AppColors.textMuted),
                ),
                const Spacer(),
                Text(
                  formatTaka(_total),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            style: TextButton.styleFrom(foregroundColor: AppColors.textMuted),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.logoGreen),
            child: const Text(
              'Yes',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showPlaced(PlacedOrder order) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: AppColors.logoGreen,
              size: 26,
            ),
            const SizedBox(width: 10),
            const Text('Order placed'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Order #${order.id} for ${order.totalLine} has been placed.',
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textDark,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'It is on your dashboard bell, and it stays in your purchase '
              'history.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
                height: 1.35,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            style: TextButton.styleFrom(foregroundColor: AppColors.logoGreen),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _say(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
      );
  }

  // ===========================================================================
  // Drawing it
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ScreenHeader(title: 'Order Summary'),
              const SizedBox(height: 16),

              _buildSearchField(),
              ..._buildSearchNotes(),

              if (_results.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildSuggestions(),
              ],

              const SizedBox(height: 14),

              // The order itself takes whatever room is left, and scrolls by
              // itself rather than pushing the total off the bottom.
              Expanded(
                child: _lines.isEmpty ? _buildEmptyNote() : _buildLines(),
              ),

              const SizedBox(height: 8),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      focusNode: _searchFocus,
      enabled: !_isPlacing,
      textCapitalization: TextCapitalization.words,
      onChanged: _onTyped,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        hintText: 'Search Medicine',
        hintStyle: const TextStyle(fontSize: 15, color: AppColors.textMuted),
        filled: true,
        fillColor: Colors.white,
        prefixIcon: const Icon(
          Icons.search,
          size: 22,
          color: AppColors.textMuted,
        ),
        suffixIcon: _isSearching
            ? const Padding(
                padding: EdgeInsets.all(14),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.logoGreen,
                  ),
                ),
              )
            : (_searchController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: _clearSearch,
                      icon: const Icon(Icons.close, size: 20),
                      color: AppColors.textMuted,
                      tooltip: 'Clear',
                    )),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
        // The rounded box the wireframe draws the search bar as.
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(26),
          borderSide: const BorderSide(color: AppColors.fieldBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(26),
          borderSide: const BorderSide(color: AppColors.fieldBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(26),
          borderSide: const BorderSide(color: AppColors.logoGreen, width: 2),
        ),
      ),
    );
  }

  List<Widget> _buildSearchNotes() {
    if (_searchError != null) {
      return [
        const SizedBox(height: 8),
        Text(
          _searchError!,
          style: TextStyle(fontSize: 12, color: Colors.red.shade700),
        ),
      ];
    }

    // Saying where the suggestions came from matters when they came from the
    // fallback: a handful of local brands must not look like the whole
    // catalogue.
    if (_isFallback && _searchMessage.isNotEmpty) {
      return [
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 14,
              color: AppColors.historyRescheduled,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                _searchMessage,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.historyRescheduled,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ];
    }

    // "No brand on MedEx starts with that", which is worth showing.
    if (!_isSearching &&
        _results.isEmpty &&
        _searchController.text.trim().length >= 2 &&
        _searchMessage.isNotEmpty) {
      return [
        const SizedBox(height: 8),
        Text(
          _searchMessage,
          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
      ];
    }

    return const [];
  }

  Widget _buildSuggestions() {
    return Container(
      // Tall enough for a useful list, short enough that the order underneath
      // never disappears behind it.
      constraints: const BoxConstraints(maxHeight: 268),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.fieldBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        child: Column(
          children: [
            for (final medicine in _results.take(_maxShown))
              _SuggestionRow(
                medicine: medicine,
                // Only the row being priced shows a spinner, and every row
                // stops responding while one is - two medicines cannot be
                // half added at once.
                isPricing: identical(_pricing, medicine),
                enabled: _pricing == null && !_isPlacing,
                onTap: () => _add(medicine),
              ),
            if (_results.length > _maxShown)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Text(
                  '${_results.length - _maxShown} more - type another letter '
                  'to narrow it down.',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyNote() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.local_pharmacy_outlined,
              size: 44,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 12),
            const Text(
              'Nothing on the order yet.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.refill == null
                  ? 'Type the first letters of a brand above, then tap it to '
                        'add it.'
                  : 'Type the first letters of a brand above to add more.',
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

  Widget _buildLines() {
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: _lines.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, index) {
        final line = _lines[index];

        return _OrderLineRow(
          line: line,
          enabled: !_isPlacing,
          onLess: () => _bump(line, -1),
          onMore: () => _bump(line, 1),
          onRemove: () => _remove(line),
        );
      },
    );
  }

  /// The total on the left and Confirm Order on the right, the way the
  /// wireframe closes the screen off.
  Widget _buildFooter() {
    final hasLines = _lines.isNotEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.fieldBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Total cost',
                  style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                ),
                const SizedBox(height: 2),
                Text(
                  formatTaka(_total),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          _isPlacing
              ? const SizedBox(
                  width: 168,
                  height: 48,
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.logoGreen,
                      ),
                    ),
                  ),
                )
              : PrimaryButton(
                  label: 'Confirm Order',
                  width: 168,
                  // Lit up only once there is something to confirm, the same
                  // way every other button in the app shows it is ready.
                  glow: hasLines,
                  onPressed: hasLines ? _confirm : null,
                ),
        ],
      ),
    );
  }
}

/// One brand in the suggestion list, waiting to be added.
class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({
    required this.medicine,
    required this.isPricing,
    required this.enabled,
    required this.onTap,
  });

  final MedicineOption medicine;

  /// True while this brand's price is being read off MedEx.
  final bool isPricing;

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            const Icon(
              Icons.medication_outlined,
              size: 16,
              color: AppColors.logoGreen,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    medicine.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                  if (medicine.dosage != null && medicine.dosage!.isNotEmpty)
                    Text(
                      medicine.dosage!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // The suggestion carries no price - MedEx's list has none - so the
            // spinner is the honest thing to show while one is fetched.
            if (isPricing)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.logoGreen,
                ),
              )
            else
              const Icon(
                Icons.add_circle_outline,
                size: 20,
                color: AppColors.logoGreen,
              ),
          ],
        ),
      ),
    );
  }
}

/// One medicine on the order: what it is, what one costs, and how many.
class _OrderLineRow extends StatelessWidget {
  const _OrderLineRow({
    required this.line,
    required this.enabled,
    required this.onLess,
    required this.onMore,
    required this.onRemove,
  });

  final OrderLine line;
  final bool enabled;
  final VoidCallback onLess;
  final VoidCallback onMore;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final medicine = line.medicine;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.fieldBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      medicine.name,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    if (medicine.dosage != null && medicine.dosage!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Text(
                          medicine.dosage!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    const SizedBox(height: 4),

                    // What one of them costs, and what "one" means. A syrup
                    // priced per bottle has to say so, or ৳28.00 "each" would
                    // be a false statement about what is being bought.
                    Text(
                      medicine.unitPriceLine,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.logoBlue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              _QuantityStepper(
                quantity: line.quantity,
                enabled: enabled,
                onLess: onLess,
                onMore: onMore,
              ),
            ],
          ),

          const SizedBox(height: 8),
          const Divider(height: 1, color: AppColors.background),
          const SizedBox(height: 6),

          Row(
            children: [
              // Taking the last one off the line already removes it, but a
              // patient with ten of something should not have to press minus
              // ten times to change their mind.
              TextButton.icon(
                onPressed: enabled ? onRemove : null,
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('Remove', style: TextStyle(fontSize: 12.5)),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.historyCancelled,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: const Size(0, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const Spacer(),
              Text(
                formatTaka(line.lineTotal),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(width: 6),
            ],
          ),
        ],
      ),
    );
  }
}

/// The minus, the count and the plus - the "-1+" the wireframe puts beside
/// every medicine.
class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.quantity,
    required this.enabled,
    required this.onLess,
    required this.onMore,
  });

  final int quantity;
  final bool enabled;
  final VoidCallback onLess;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.fieldBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepButton(
            icon: Icons.remove,
            // At one, minus takes the medicine off the order - which is what
            // the wireframe's "add or discard" asks for.
            tooltip: quantity == 1 ? 'Remove from order' : 'One less',
            enabled: enabled,
            onPressed: onLess,
          ),
          SizedBox(
            width: 30,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
          ),
          _StepButton(
            icon: Icons.add,
            tooltip: 'One more',
            enabled: enabled,
            onPressed: onMore,
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: enabled ? onPressed : null,
      icon: Icon(icon, size: 18),
      color: AppColors.logoGreen,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      padding: EdgeInsets.zero,
      splashRadius: 20,
    );
  }
}
