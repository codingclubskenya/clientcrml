import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/colors.dart';

class TeamAttendancePage extends StatefulWidget {
  const TeamAttendancePage({super.key});

  @override
  State<TeamAttendancePage> createState() => _TeamAttendancePageState();
}

class _TeamAttendancePageState extends State<TeamAttendancePage> {
  final _supabase = Supabase.instance.client;
  final _searchController = TextEditingController();
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();
  List<_AgentDay> _teamDays = [];
  List<_AgentDay> _filteredDays = [];
  String? _errorMessage;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadAttendance();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final q = _searchController.text.trim().toLowerCase();
    if (q == _searchQuery) return;
    setState(() {
      _searchQuery = q;
      _applyFilter();
    });
  }

  void _applyFilter() {
    if (_searchQuery.isEmpty) {
      _filteredDays = List.of(_teamDays);
    } else {
      _filteredDays = _teamDays.where((d) {
        return d.name.toLowerCase().contains(_searchQuery) ||
            d.email.toLowerCase().contains(_searchQuery);
      }).toList();
    }
  }

  Future<void> _loadAttendance() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final dayStart = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    final dayEnd = dayStart.add(const Duration(days: 1));

    try {
      final response = await _supabase
          .from('visit_checkins')
          .select(
            'id, agent_id, agent_name, checkin_at, checkout_at, duration_seconds, auto_checkout, gps_lat, gps_lng, location_text',
          )
          .gte('checkin_at', dayStart.toUtc().toIso8601String())
          .lt('checkin_at', dayEnd.toUtc().toIso8601String())
          .order('checkin_at', ascending: false);

      final records = List<Map<String, dynamic>>.from(response);
      final Map<String, _AgentDay> byAgent = {};

      for (final r in records) {
        final agentId = r['agent_id']?.toString() ?? '';
        if (agentId.isEmpty) continue;
        final name =
            (r['agent_name']?.toString().trim().isNotEmpty ?? false)
                ? r['agent_name'].toString()
                : 'Unknown';

        final day = byAgent.putIfAbsent(
          agentId,
          () => _AgentDay(
            agentId: agentId,
            name: name,
            email: '',
            role: 5,
            records: [],
          ),
        );
        day.records.add(_SessionRecord(
          id: r['id']?.toString() ?? '',
          checkIn: DateTime.parse(r['checkin_at'] as String).toLocal(),
          checkOut: r['checkout_at'] != null
              ? DateTime.parse(r['checkout_at'] as String).toLocal()
              : null,
          durationSeconds: (r['duration_seconds'] as num?)?.toInt() ?? 0,
          autoCheckOut: r['auto_checkout'] == true,
          locationText: r['location_text']?.toString(),
        ));
      }

      final list = byAgent.values.toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      for (final d in list) {
        d.records.sort((a, b) => b.checkIn.compareTo(a.checkIn));
        d.totalSeconds = d.records.fold<int>(
          0,
          (sum, r) => sum + r.durationSeconds,
        );
      }

      if (!mounted) return;
      setState(() {
        _teamDays = list;
        _isLoading = false;
        _applyFilter();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not load attendance: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 90)),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primaryGreen,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.textDark,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
      _loadAttendance();
    }
  }

  String _formatDate(DateTime d) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${weekdays[d.weekday - 1]}, ${d.day} ${months[d.month - 1]} ${d.year}';
  }

  String _formatShortDate(DateTime d) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${weekdays[d.weekday - 1]}, ${d.day} ${months[d.month - 1]}';
  }

  String _formatTime(DateTime d) {
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m';
    return '0m';
  }

  Color _dayColor(_AgentDay day) {
    if (day.records.isEmpty) return Colors.grey;
    final hasOpen = day.records.any((r) => r.checkOut == null);
    if (hasOpen) return AppColors.accentOrange;
    if (day.isFullDay) return AppColors.primaryGreen;
    if (day.totalSeconds < 60 * 60) return Colors.amber.shade700;
    return AppColors.primaryGreen;
  }

  String _dayStatus(_AgentDay day) {
    if (day.records.isEmpty) return 'NO SHIFT';
    final hasOpen = day.records.any((r) => r.checkOut == null);
    if (hasOpen) return 'ON DUTY';
    if (day.isFullDay) return 'FULL DAY';
    return 'PARTIAL';
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = _formatDate(_selectedDate);
    final isToday = DateUtils.isSameDay(_selectedDate, DateTime.now());

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Team Attendance'),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadAttendance,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildDateBar(dateLabel, isToday),
          _buildSummary(),
          _buildSearchBar(),
          const Divider(height: 1),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                size: 48,
                                color: Colors.red,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.red),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadAttendance,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _teamDays.isEmpty
                        ? _buildEmptyState()
                        : _filteredDays.isEmpty
                            ? _buildNoMatchesState()
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                                itemCount: _filteredDays.length,
                                itemBuilder: (context, index) {
                                  final day = _filteredDays[index];
                                  return _buildAgentCard(day);
                                },
                              ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search by agent name…',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _searchQuery.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () => _searchController.clear(),
                ),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.primaryGreen),
          ),
        ),
      ),
    );
  }

  Widget _buildNoMatchesState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_search, size: 56, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            'No agents match "$_searchQuery".',
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildDateBar(String dateLabel, bool isToday) {
    return Container(
      width: double.infinity,
      color: AppColors.primaryGreen,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isToday ? 'TODAY' : 'SELECTED DATE',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dateLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_today, size: 16, color: Colors.white),
            label: const Text(
              'Pick date',
              style: TextStyle(color: Colors.white),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    final totalAgents = _teamDays.length;
    final onDuty = _teamDays.where((d) => _dayStatus(d) == 'ON DUTY').length;
    final fullDay = _teamDays.where((d) => _dayStatus(d) == 'FULL DAY').length;
    final partial = _teamDays.where((d) => _dayStatus(d) == 'PARTIAL').length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      color: Colors.white,
      child: Row(
        children: [
          _summaryTile('Agents', '$totalAgents', AppColors.primaryDark),
          _summaryTile('On duty', '$onDuty', AppColors.accentOrange),
          _summaryTile('Full day', '$fullDay', AppColors.primaryGreen),
          _summaryTile('Partial', '$partial', Colors.amber.shade700),
        ],
      ),
    );
  }

  Widget _summaryTile(String label, String value, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_busy, size: 56, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            'No check-ins recorded for ${_formatShortDate(_selectedDate)}.',
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildAgentCard(_AgentDay day) {
    final status = _dayStatus(day);
    final color = _dayColor(day);
    final initials = _initials(day.name);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          leading: CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.15),
            child: Text(
              initials,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          title: Text(
            day.name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 10,
                      color: color,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  day.totalSeconds > 0
                      ? _formatDuration(day.totalSeconds)
                      : '—',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontFamily: 'monospace',
                  ),
                ),
                const Spacer(),
                Text(
                  '${day.records.length} session${day.records.length == 1 ? '' : 's'}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          children: day.records
              .map((r) => _buildSessionRow(r))
              .toList(growable: false),
        ),
      ),
    );
  }

  Widget _buildSessionRow(_SessionRecord r) {
    final isOpen = r.checkOut == null;
    final timeFmt = _formatTime;
    final checkInStr = timeFmt(r.checkIn);
    final checkOutStr =
        r.checkOut != null ? timeFmt(r.checkOut!) : '—';
    final color = isOpen ? AppColors.accentOrange : AppColors.primaryGreen;
    final tag = r.autoCheckOut
        ? 'AUTO'
        : (isOpen ? 'ACTIVE' : 'MANUAL');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                tag,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: color,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$checkInStr → $checkOutStr',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  if (r.locationText != null && r.locationText!.isNotEmpty)
                    Text(
                      r.locationText!,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            Text(
              _formatDuration(r.durationSeconds),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                color: AppColors.primaryDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}

class _AgentDay {
  final String agentId;
  final String name;
  final String email;
  final int role;
  final List<_SessionRecord> records;
  int totalSeconds = 0;

  _AgentDay({
    required this.agentId,
    required this.name,
    required this.email,
    required this.role,
    required this.records,
  });

  bool get isFullDay => totalSeconds >= 5 * 3600;
}

class _SessionRecord {
  final String id;
  final DateTime checkIn;
  final DateTime? checkOut;
  final int durationSeconds;
  final bool autoCheckOut;
  final String? locationText;

  _SessionRecord({
    required this.id,
    required this.checkIn,
    required this.checkOut,
    required this.durationSeconds,
    required this.autoCheckOut,
    required this.locationText,
  });
}
