import 'package:flutter/material.dart';

import '../models/department.dart';
import '../models/doctor_listing.dart';
import '../models/hospital.dart';
import '../models/search_match.dart';
import '../models/signed_in_user.dart';
import '../models/weekday.dart';
import '../services/doctor_service.dart';
import '../services/search_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/dashboard_search_bar.dart';
import '../widgets/screen_header.dart';
import 'book_slot_screen.dart';

/// Screen 11 - Doctors List.
///
/// Reached two ways, and it behaves slightly differently for each:
///
///   browsing  by picking a department on the choose department screen. Lists
///             the doctors of that department who hold a chamber at that
///             hospital. The hospital is fixed, so no card repeats it.
///   searching by typing in the search bar on the patient dashboard. Results
///             can span departments, hospitals and areas, so each card says
///             where that sitting is, and the search can be changed from here
///             without going back.
///
/// Either way the list ends in the same Book button onto the same screen.
class DoctorsListScreen extends StatefulWidget {
  /// Browsing: the patient already chose the hospital and the department.
  const DoctorsListScreen({
    super.key,
    required this.hospital,
    required this.department,
    required this.patient,
  }) : searchQuery = null;

  /// Searching: one typed line, which the server works out the meaning of.
  const DoctorsListScreen.search({
    super.key,
    required this.patient,
    required String query,
  }) : searchQuery = query,
       hospital = null,
       department = null;

  /// Null when searching, because results can come from many hospitals.
  final Hospital? hospital;

  /// Null when searching, because results can come from many departments.
  final Department? department;

  final SignedInUser patient;

  /// What the patient typed. Null when browsing.
  final String? searchQuery;

  bool get isSearch => searchQuery != null;

  @override
  State<DoctorsListScreen> createState() => _DoctorsListScreenState();
}

class _DoctorsListScreenState extends State<DoctorsListScreen> {
  List<DoctorListing> _doctors = [];
  bool _isLoading = true;
  String? _loadError;

  /// What the server understood the search to mean. Empty when browsing.
  List<SearchMatch> _matches = [];

  /// The server's own count line, e.g. "3 doctors found."
  String? _resultMessage;

  /// The search being shown, which is not the same as the one that was typed on
  /// the dashboard once it has been changed here.
  late String _query;

  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _query = widget.searchQuery ?? '';
    _searchController = TextEditingController(text: _query);
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    if (widget.isSearch) {
      await _runSearch();
    } else {
      await _loadDepartmentDoctors();
    }
  }

  Future<void> _loadDepartmentDoctors() async {
    final result = await DoctorService.fetchForHospitalDepartment(
      hospitalId: widget.hospital!.id,
      departmentId: widget.department!.id,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result.isSuccess) {
        _doctors = result.doctors;
      } else {
        _loadError = result.error;
      }
    });
  }

  Future<void> _runSearch() async {
    final result = await SearchService.search(query: _query);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result.isSuccess) {
        _doctors = result.doctors;
        _matches = result.matches;
        _resultMessage = result.message;
      } else {
        _doctors = [];
        _matches = [];
        _resultMessage = null;
        _loadError = result.error;
      }
    });
  }

  /// Searching again from the results screen, so a search can be narrowed
  /// without going back to the dashboard for every attempt.
  void _onSearchSubmitted(String query) {
    if (query.trim().isEmpty || query.trim() == _query) return;

    setState(() => _query = query.trim());
    _load();
  }

  void _onBookPressed(DoctorListing doctor) {
    // Browsing already knows the hospital; searching carries it on the row.
    final hospital = widget.hospital ?? doctor.hospital;

    if (hospital == null) {
      // Only reachable if the API stopped sending the hospital with a search
      // result, which would make the booking screen unable to say where to go.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'This result is missing its hospital, so it cannot be booked yet.',
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookSlotScreen(
          patient: widget.patient,
          doctor: doctor,
          hospital: hospital,
        ),
      ),
    );
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
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ScreenHeader(
                title: widget.isSearch ? 'Search Results' : 'Doctors List',
              ),
              const SizedBox(height: 12),

              if (widget.isSearch) ..._buildSearchHeader() else _buildBrowseHeader(),

              const SizedBox(height: 14),

              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  /// Which department at which hospital these doctors belong to.
  Widget _buildBrowseHeader() {
    return Text(
      '${widget.department!.name}  ·  ${widget.hospital!.name}',
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textMuted,
        height: 1.3,
      ),
    );
  }

  /// The search bar again, plus what the words were understood to mean.
  List<Widget> _buildSearchHeader() {
    return [
      DashboardSearchBar(
        controller: _searchController,
        hint: 'Try a problem, area, hospital or day',
        onSubmitted: _onSearchSubmitted,
      ),

      // The chips are the honest bit: they show what was searched for, so a
      // wrong guess by the server is visible instead of silent.
      if (_matches.isNotEmpty) ...[
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final match in _matches) _MatchChip(match: match),
          ],
        ),
      ],

      if (_resultMessage != null && !_isLoading && _loadError == null) ...[
        const SizedBox(height: 12),
        Text(
          _resultMessage!,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
        ),
      ],
    ];
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.logoGreen),
            SizedBox(height: 16),
            Text(
              'Loading doctors...',
              style: TextStyle(fontSize: 15, color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }

    if (_loadError != null) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _loadError!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.red.shade900),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Try again'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.logoGreen,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_doctors.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: _doctors.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _DoctorCard(
          doctor: _doctors[index],
          // Browsing repeats one hospital on every card, which is noise. A
          // search spans hospitals, so there it is the useful part.
          showHospital: widget.isSearch,
          onBook: () => _onBookPressed(_doctors[index]),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    final message = widget.isSearch
        ? 'No doctor matches "$_query" yet.\nTry an area, a hospital, a day, '
              'or a problem like "gastric".'
        : 'No ${widget.department!.name} doctors sit at this hospital yet.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.person_off_outlined,
              size: 48,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: AppColors.textDark),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Refresh'),
              style: TextButton.styleFrom(foregroundColor: AppColors.logoGreen),
            ),
          ],
        ),
      ),
    );
  }
}

/// One chip saying what the search was understood to mean.
class _MatchChip extends StatelessWidget {
  const _MatchChip({required this.match});

  final SearchMatch match;

  /// A different icon per kind, so the five ways of searching are told apart at
  /// a glance rather than by reading every chip.
  IconData get _icon {
    switch (match.type) {
      case 'speciality':
        return Icons.medical_services_outlined;
      case 'experience':
        return Icons.workspace_premium_outlined;
      case 'location':
        return Icons.place_outlined;
      case 'hospital':
        return Icons.local_hospital_outlined;
      case 'availability':
        return Icons.calendar_month_outlined;
      default:
        return Icons.search;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Free text means nothing in the catalogues matched, so it is drawn plainly
    // rather than in the confident green of a real match.
    final isText = match.type == 'text';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: isText ? Colors.white : const Color(0xFFF0FFEC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isText ? AppColors.fieldBorder : AppColors.logoGreen,
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _icon,
            size: 15,
            color: isText ? AppColors.textMuted : AppColors.logoGreen,
          ),
          const SizedBox(width: 6),
          Text(
            match.label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isText ? AppColors.textMuted : AppColors.logoGreen,
            ),
          ),
        ],
      ),
    );
  }
}

/// One doctor row: who they are on the left, Book on the right.
class _DoctorCard extends StatelessWidget {
  const _DoctorCard({
    required this.doctor,
    required this.onBook,
    this.showHospital = false,
  });

  final DoctorListing doctor;
  final VoidCallback onBook;

  /// Whether to name the hospital on the card. Only useful when the list spans
  /// more than one, which is the case for a search.
  final bool showHospital;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.fieldBorder, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            doctor.displayName,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),

          // In a search the department is what tells two results apart, so it
          // sits right under the name.
          if (showHospital && doctor.departmentName.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              doctor.departmentName,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
          ],

          // Degrees are why a patient picks one doctor over another, so they
          // sit directly under the name.
          if (doctor.degrees != null && doctor.degrees!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              doctor.degrees!,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.logoBlue,
                height: 1.3,
              ),
            ),
          ],

          // What they treat. This is the thing the search matched on, so it is
          // the thing the patient most needs to see to trust the result.
          if (doctor.specialization != null &&
              doctor.specialization!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              doctor.specialization!,
              style: const TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: AppColors.textDark,
                height: 1.35,
              ),
            ),
          ],

          const SizedBox(height: 10),

          if (showHospital && doctor.hospitalLine != null)
            _InfoLine(
              icon: Icons.local_hospital_outlined,
              text: doctor.hospitalLine!,
            ),
          if (doctor.experienceLine != null)
            _InfoLine(
              icon: Icons.workspace_premium_outlined,
              text: doctor.experienceLine!,
            ),
          if (doctor.experience != null && doctor.experience!.isNotEmpty)
            _InfoLine(
              icon: Icons.school_outlined,
              text: doctor.experience!.replaceAll(' | ', '\n'),
            ),
          if (doctor.weekdays.isNotEmpty)
            _InfoLine(
              icon: Icons.calendar_month_outlined,
              text: Weekday.describe(doctor.weekdays),
            ),
          if (doctor.timeSlot.isNotEmpty)
            _InfoLine(icon: Icons.schedule_outlined, text: doctor.timeSlot),
          if (doctor.offday != null)
            _InfoLine(
              icon: Icons.event_busy_outlined,
              text: 'Off day: ${doctor.offday!.fullName}',
            ),
          if (doctor.chamberLine != null)
            _InfoLine(
              icon: Icons.meeting_room_outlined,
              text: doctor.chamberLine!,
            ),

          const SizedBox(height: 12),

          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: onBook,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.logoGreen,
                foregroundColor: Colors.white,
                elevation: 2,
                padding: const EdgeInsets.symmetric(
                  horizontal: 26,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Book',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One small icon plus text line inside a doctor card.
class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textDark,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
