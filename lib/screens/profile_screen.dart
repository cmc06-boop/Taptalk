import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../core/l10n/app_strings.dart';
import '../core/theme/theme_tokens.dart';
import '../core/utils/auth_validation.dart';
import '../data/repositories/app_repository.dart';
import '../providers/app_state.dart';
import '../widgets/learner_scaffold.dart';
import '../widgets/password_strength_hint.dart';
import '../widgets/panel_card.dart';
import '../widgets/code_qr_sheet.dart';
import '../widgets/taptalk_result_dialog.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _ageController = TextEditingController();
  final _yearController = TextEditingController();
  final _monthController = TextEditingController();
  final _dayController = TextEditingController();
  final _yearFocus = FocusNode();
  final _monthFocus = FocusNode();
  final _dayFocus = FocusNode();
  final _gradeLevelController = TextEditingController();
  final _emergency1Controller = TextEditingController();
  final _emergency2Controller = TextEditingController();
  String _savedFirstName = '';
  String _savedLastName = '';
  String _savedName = '';
  String _savedAddress = '';
  String _savedAge = '';
  String _savedGradeLevel = '';
  String _savedBirthdate = '';
  String _birthdateIso = '';
  List<String> _savedEmergencyContacts = const [];
  bool _showSecondEmergency = false;
  bool _editing = false;
  bool _saving = false;
  bool _showFloatingCancel = false;
  bool _syncingLinkedDates = false;
  final _scrollController = ScrollController();
  final _editCancelKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_syncFloatingCancel);
  }

  void _syncFloatingCancel() {
    var show = false;
    if (_editing && _scrollController.hasClients) {
      final ctx = _editCancelKey.currentContext;
      final box = ctx?.findRenderObject();
      final scrollBox =
          _scrollController.position.context.notificationContext?.findRenderObject();
      if (box is RenderBox &&
          box.hasSize &&
          box.attached &&
          scrollBox is RenderBox &&
          scrollBox.hasSize) {
        final buttonTop = box.localToGlobal(Offset.zero).dy;
        final viewportTop = scrollBox.localToGlobal(Offset.zero).dy;
        show = buttonTop < viewportTop;
      }
    }
    if (show != _showFloatingCancel && mounted) {
      setState(() => _showFloatingCancel = show);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _addressController.dispose();
    _ageController.dispose();
    _yearController.dispose();
    _monthController.dispose();
    _dayController.dispose();
    _yearFocus.dispose();
    _monthFocus.dispose();
    _dayFocus.dispose();
    _gradeLevelController.dispose();
    _emergency1Controller.dispose();
    _emergency2Controller.dispose();
    super.dispose();
  }

  void _applyNameToControllers({required String first, required String last}) {
    if (_firstNameController.text != first) {
      _firstNameController.text = first;
    }
    if (_lastNameController.text != last) {
      _lastNameController.text = last;
    }
  }

  String get _composedName =>
      '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}'
          .trim();

  void _syncFromUser(AppState app) {
    if (_editing || _saving) return;
    final name = app.user?.fullName ?? '';
    final firstName = app.profileFirstName;
    final lastName = app.profileLastName;
    final address = app.address;
    final age = app.age?.toString() ?? '';
    final gradeLevel = app.gradeLevel;
    final birthdate = app.birthdate;
    final isLearner = app.user?.isLearner ?? false;
    final contacts = isLearner ? app.emergencyContacts : const <String>[];
    if (_savedName == name &&
        _savedFirstName == firstName &&
        _savedLastName == lastName &&
        _savedAddress == address &&
        _savedAge == age &&
        _savedGradeLevel == gradeLevel &&
        _savedBirthdate == birthdate &&
        _savedEmergencyContacts.join('|') == contacts.join('|')) {
      return;
    }
    _savedName = name;
    _savedFirstName = firstName;
    _savedLastName = lastName;
    _savedAddress = address;
    _savedAge = age;
    _savedGradeLevel = gradeLevel;
    _savedBirthdate = birthdate;
    _savedEmergencyContacts = List.from(contacts);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _applyNameToControllers(first: firstName, last: lastName);
      if (_addressController.text != address) {
        _addressController.text = address;
      }
      if (_ageController.text != age) {
        _ageController.text = age;
      }
      if (_gradeLevelController.text != gradeLevel) {
        _gradeLevelController.text = gradeLevel;
      }
      if (_birthdateIso != birthdate ||
          (birthdate.isNotEmpty && _yearController.text.isEmpty)) {
        _birthdateIso = birthdate;
        _setBirthdatePartsFromIso(birthdate);
      }
      if (!isLearner) return;
      final first = contacts.isNotEmpty ? contacts.first : '';
      final second = contacts.length > 1 ? contacts[1] : '';
      if (_emergency1Controller.text != first) {
        _emergency1Controller.text = first;
      }
      if (_emergency2Controller.text != second) {
        _emergency2Controller.text = second;
      }
      final shouldShowSecond = second.isNotEmpty;
      if (_showSecondEmergency != shouldShowSecond) {
        setState(() => _showSecondEmergency = shouldShowSecond);
      }
    });
  }

  List<String> get _draftEmergencyContacts {
    final first = _emergency1Controller.text.trim();
    final second = _emergency2Controller.text.trim();
    final raw = <String>[];
    if (first.isNotEmpty) raw.add(first);
    if (_showSecondEmergency && second.isNotEmpty) raw.add(second);
    return AppRepository.normalizeEmergencyContacts(raw);
  }

  bool _hasUnsavedChanges(AppState app) {
    final isLearner = app.user?.isLearner ?? false;
    if (_firstNameController.text.trim() != _savedFirstName) return true;
    if (_lastNameController.text.trim() != _savedLastName) return true;
    if (_addressController.text.trim() != _savedAddress) return true;
    if (_ageController.text.trim() != _savedAge) return true;
    if (_birthdateToSave() != _savedBirthdate) return true;
    final date = _dateFromParts();
    final partsEmpty = _yearController.text.isEmpty &&
        _monthController.text.isEmpty &&
        _dayController.text.isEmpty;
    if (!partsEmpty && date == null) return true;
    if (isLearner && _gradeLevelController.text.trim() != _savedGradeLevel) {
      return true;
    }
    if (isLearner) {
      return _draftEmergencyContacts.join('|') !=
          _savedEmergencyContacts.join('|');
    }
    return false;
  }

  bool _canSave(AppState app) {
    return _editing && !_saving && _hasUnsavedChanges(app);
  }

  void _cancelEdits() {
    _applyNameToControllers(first: _savedFirstName, last: _savedLastName);
    _addressController.text = _savedAddress;
    _ageController.text = _savedAge;
    _gradeLevelController.text = _savedGradeLevel;
    _birthdateIso = _savedBirthdate;
    _setBirthdatePartsFromIso(_savedBirthdate);
    _emergency1Controller.text = _savedEmergencyContacts.isNotEmpty ? _savedEmergencyContacts[0] : '';
    _emergency2Controller.text = _savedEmergencyContacts.length > 1 ? _savedEmergencyContacts[1] : '';
    _showSecondEmergency = _savedEmergencyContacts.length > 1;
    _editing = false;
    setState(() {});
  }

  Future<void> _save(AppState app, AppLanguage lang) async {
    final isLearner = app.user?.isLearner ?? false;
    final isParent = app.user?.isParent ?? false;
    final isTeacher = app.user?.isTeacher ?? false;
    final name = _composedName;
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    if ((firstName.isNotEmpty && !AuthValidation.isValidFullName(firstName)) ||
        (lastName.isNotEmpty && !AuthValidation.isValidFullName(lastName))) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.invalidFullName(lang))),
      );
      return;
    }
    final contacts = isLearner ? _draftEmergencyContacts : const <String>[];
    final address = _addressController.text.trim();
    final ageRaw = _ageController.text.trim();
    final gradeLevel = _gradeLevelController.text.trim();
    int? age;
    if (ageRaw.isNotEmpty) {
      age = int.tryParse(ageRaw);
      if (age == null || age < 1 || age > 120) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.invalidAge(lang))),
        );
        return;
      }
    } else {
      final fromBirth = _ageFromIso(_birthdateToSave());
      if (fromBirth != null) age = fromBirth;
    }
    if (isLearner && gradeLevel.isNotEmpty) {
      final grade = int.tryParse(gradeLevel);
      if (grade == null || grade < 1 || grade > 12) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.invalidGradeLevel(lang))),
        );
        return;
      }
    }
    if (isLearner) {
      final contactsToCheck = <String>[
        _emergency1Controller.text.trim(),
        if (_showSecondEmergency) _emergency2Controller.text.trim(),
      ];
      for (final raw in contactsToCheck) {
        if (raw.isEmpty) continue;
        if (AppRepository.emergencyPhoneKey(raw) == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppStrings.invalidContactNumber(lang))),
          );
          return;
        }
      }
    }
    setState(() => _saving = true);
    String? err;
    if (name.isNotEmpty) {
      err = await app.updateProfileName(
        firstName: firstName,
        lastName: lastName,
      );
    } else {
      _applyNameToControllers(first: _savedFirstName, last: _savedLastName);
    }
    if (err == null && (isLearner || isParent || isTeacher)) {
      final birthIso = _birthdateToSave();
      _birthdateIso = birthIso;
      await app.updateProfileExtras(
        address: address,
        age: age,
        gradeLevel: isLearner ? gradeLevel : '',
        birthdate: birthIso,
      );
    }
    if (err == null && isLearner) {
      await app.updateEmergencyContacts(contacts);
    }
    if (!mounted) return;
    setState(() => _saving = false);
    if (err != null) {
      await TapTalkResultDialog.showError(
        context,
        title: AppStrings.somethingWentWrong(lang),
        message: err,
      );
      return;
    }
    _savedName = name;
    _savedFirstName = firstName;
    _savedLastName = lastName;
    _savedAddress = address;
    _savedAge = age?.toString() ?? '';
    _savedGradeLevel = isLearner ? gradeLevel : '';
    _savedBirthdate = _birthdateIso;
    if (isLearner) {
      _savedEmergencyContacts = List.from(contacts);
    }
    _editing = false;
    setState(() {});
    await TapTalkResultDialog.showSuccess(
      context,
      title: AppStrings.profileUpdatedTitle(lang),
      message: AppStrings.profileUpdated(lang),
    );
  }

  Future<void> _pickBirthdate() async {
    if (!_editing || _saving) return;
    final parsed = _dateFromParts() ?? DateTime.tryParse(_birthdateIso);
    final now = DateTime.now();
    var initial = parsed ?? DateTime(now.year - 8, now.month, now.day);
    if (initial.isAfter(now)) initial = now;
    if (initial.isBefore(DateTime(1920))) initial = DateTime(1920);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1920),
      lastDate: now,
    );
    if (picked == null || !mounted) return;
    _applyPickedBirthdate(picked);
  }

  void _applyPickedBirthdate(DateTime picked) {
    final iso = _isoDate(picked);
    final age = _ageFromDate(picked);
    _syncingLinkedDates = true;
    _yearController.text = picked.year.toString();
    _monthController.text = picked.month.toString().padLeft(2, '0');
    _dayController.text = picked.day.toString().padLeft(2, '0');
    _birthdateIso = iso;
    if (age != null) {
      _ageController.text = age.toString();
    }
    _syncingLinkedDates = false;
    setState(() {});
  }

  void _setBirthdatePartsFromIso(String iso) {
    _syncingLinkedDates = true;
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) {
      _yearController.clear();
      _monthController.clear();
      _dayController.clear();
    } else {
      _yearController.text = parsed.year.toString();
      _monthController.text = parsed.month.toString().padLeft(2, '0');
      _dayController.text = parsed.day.toString().padLeft(2, '0');
    }
    _syncingLinkedDates = false;
  }

  DateTime? _dateFromParts() {
    if (_yearController.text.length != 4) return null;
    final year = int.tryParse(_yearController.text);
    final month = int.tryParse(_monthController.text);
    final day = int.tryParse(_dayController.text);
    if (year == null || month == null || day == null) return null;
    if (year < 1920) return null;
    if (month < 1 || month > 12) return null;
    final maxDay = DateTime(year, month + 1, 0).day;
    if (day < 1 || day > maxDay) return null;
    final date = DateTime(year, month, day);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (date.isAfter(today)) return null;
    return date;
  }

  String _birthdateToSave() {
    final date = _dateFromParts();
    if (date != null) return _isoDate(date);
    if (_yearController.text.isEmpty &&
        _monthController.text.isEmpty &&
        _dayController.text.isEmpty) {
      return '';
    }
    return _birthdateIso;
  }

  void _applyBirthdateToAge() {
    if (_syncingLinkedDates) return;
    final date = _dateFromParts();
    if (date == null) return;
    final age = _ageFromDate(date);
    _syncingLinkedDates = true;
    _birthdateIso = _isoDate(date);
    if (age != null && _ageController.text != age.toString()) {
      _ageController.text = age.toString();
    }
    _syncingLinkedDates = false;
  }

  void _applyAgeToBirthdate() {
    if (_syncingLinkedDates) return;
    final age = int.tryParse(_ageController.text.trim());
    if (age == null || age < 1 || age > 120) return;
    final now = DateTime.now();
    var month = int.tryParse(_monthController.text);
    var day = int.tryParse(_dayController.text);
    month ??= now.month;
    day ??= now.day;
    month = month.clamp(1, 12);
    final maxThisYear = DateTime(now.year, month + 1, 0).day;
    final dayThisYear = day.clamp(1, maxThisYear);
    var year = now.year - age;
    if (now.month < month || (now.month == month && now.day < dayThisYear)) {
      year -= 1;
    }
    if (year < 1920) year = 1920;
    if (year > now.year) year = now.year;
    final maxDay = DateTime(year, month + 1, 0).day;
    day = day.clamp(1, maxDay);
    _syncingLinkedDates = true;
    _yearController.text = year.toString();
    if (_monthController.text.isNotEmpty) {
      _monthController.text = month.toString().padLeft(2, '0');
    }
    if (_dayController.text.isNotEmpty) {
      _dayController.text = day.toString().padLeft(2, '0');
    }
    if (_monthController.text.isNotEmpty && _dayController.text.isNotEmpty) {
      _birthdateIso = _isoDate(DateTime(year, month, day));
    }
    _syncingLinkedDates = false;
  }

  void _onYearChanged(String value) {
    if (_syncingLinkedDates) return;
    if (value.length == 4) {
      final year = int.tryParse(value);
      final nowYear = DateTime.now().year;
      if (year != null) {
        var next = year;
        if (next < 1920) next = 1920;
        if (next > nowYear) next = nowYear;
        if (next.toString() != value) {
          _syncingLinkedDates = true;
          _yearController.value = TextEditingValue(
            text: next.toString(),
            selection: const TextSelection.collapsed(offset: 4),
          );
          _syncingLinkedDates = false;
        }
      }
      _monthFocus.requestFocus();
    }
    _applyBirthdateToAge();
    setState(() {});
  }

  void _onMonthChanged(String value) {
    if (_syncingLinkedDates) return;
    if (value.length == 1) {
      final n = int.tryParse(value);
      if (n != null && n >= 2 && n <= 9) {
        _syncingLinkedDates = true;
        _monthController.value = TextEditingValue(
          text: '0$n',
          selection: const TextSelection.collapsed(offset: 2),
        );
        _syncingLinkedDates = false;
        _dayFocus.requestFocus();
      }
    } else if (value.length == 2) {
      var n = int.tryParse(value) ?? 0;
      if (n == 0) n = 1;
      if (n > 12) n = 12;
      final padded = n.toString().padLeft(2, '0');
      if (padded != value) {
        _syncingLinkedDates = true;
        _monthController.value = TextEditingValue(
          text: padded,
          selection: const TextSelection.collapsed(offset: 2),
        );
        _syncingLinkedDates = false;
      }
      _dayFocus.requestFocus();
    }
    _applyBirthdateToAge();
    setState(() {});
  }

  void _onDayChanged(String value) {
    if (_syncingLinkedDates) return;
    if (value.length == 1) {
      final n = int.tryParse(value);
      if (n != null && n >= 4 && n <= 9) {
        _syncingLinkedDates = true;
        _dayController.value = TextEditingValue(
          text: '0$n',
          selection: const TextSelection.collapsed(offset: 2),
        );
        _syncingLinkedDates = false;
      }
    } else if (value.length == 2) {
      var n = int.tryParse(value) ?? 0;
      final year = int.tryParse(_yearController.text);
      final month = int.tryParse(_monthController.text);
      var maxDay = 31;
      if (year != null && month != null && month >= 1 && month <= 12) {
        maxDay = DateTime(year, month + 1, 0).day;
      }
      if (n == 0) n = 1;
      if (n > maxDay) n = maxDay;
      final padded = n.toString().padLeft(2, '0');
      if (padded != value) {
        _syncingLinkedDates = true;
        _dayController.value = TextEditingValue(
          text: padded,
          selection: const TextSelection.collapsed(offset: 2),
        );
        _syncingLinkedDates = false;
      }
    }
    _applyBirthdateToAge();
    setState(() {});
  }

  Widget _birthdateEditor(TapTalkThemeToken theme, AppLanguage lang) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.birthdate(lang),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: theme.textMain.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              _DatePartField(
                controller: _yearController,
                focusNode: _yearFocus,
                enabled: _editing,
                theme: theme,
                hint: 'YYYY',
                maxLength: 4,
                width: 34,
                embedded: true,
                onChanged: _editing ? _onYearChanged : null,
              ),
              Text(
                '/',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: theme.textMain.withValues(alpha: 0.45),
                ),
              ),
              _DatePartField(
                controller: _monthController,
                focusNode: _monthFocus,
                enabled: _editing,
                theme: theme,
                hint: 'MM',
                maxLength: 2,
                width: 20,
                embedded: true,
                onChanged: _editing ? _onMonthChanged : null,
              ),
              Text(
                '/',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: theme.textMain.withValues(alpha: 0.45),
                ),
              ),
              _DatePartField(
                controller: _dayController,
                focusNode: _dayFocus,
                enabled: _editing,
                theme: theme,
                hint: 'DD',
                maxLength: 2,
                width: 20,
                embedded: true,
                onChanged: _editing ? _onDayChanged : null,
              ),
              const Spacer(),
              GestureDetector(
                onTap: _editing && !_saving ? _pickBirthdate : null,
                child: Icon(
                  Icons.calendar_month_rounded,
                  size: 16,
                  color: _editing
                      ? theme.bgAccent
                      : theme.textMain.withValues(alpha: 0.35),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showEditPassword(AppState app, AppLanguage lang) async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (ctx) => _EditPasswordDialog(app: app, lang: lang),
    );
    if (!mounted || updated != true) return;
    await TapTalkResultDialog.showSuccess(
      context,
      title: AppStrings.passwordUpdatedTitle(lang),
      message: AppStrings.passwordUpdated(lang),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final user = app.user;
    final lang = app.language;
    final theme = app.theme;

    _syncFromUser(app);

    return LearnerScaffold(
      title: AppStrings.profile(lang),
      titleWidget: SizedBox(
        height: 85,
        child: Center(
          child: Text(
            AppStrings.profile(lang),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: theme.textMain,
            ),
          ),
        ),
      ),
      currentRoute: AppRoute.profile,
      headerContentHeight: 85,
      headerBottomSpacing: 0,
      bodyTopOffset: -4,
      showBottomNav: true,
      body: Stack(
        children: [
          ListView(
            controller: _scrollController,
            padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
            children: [
              PanelCard(
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            borderRadius: 14,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        AppStrings.personalDetails(lang),
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: theme.textMain,
                          height: 1.1,
                        ),
                      ),
                    ),
                    TextButton(
                      key: _editCancelKey,
                      onPressed: _editing
                          ? (_saving ? null : _cancelEdits)
                          : () {
                              setState(() => _editing = true);
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                _syncFloatingCancel();
                              });
                            },
                      style: TextButton.styleFrom(
                        backgroundColor: _editing
                            ? Colors.transparent
                            : Color.lerp(theme.bgAccent, Colors.black, 0.12),
                        foregroundColor:
                            _editing ? theme.textMain : Colors.white,
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        _editing
                            ? AppStrings.cancel(lang)
                            : AppStrings.edit(lang),
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  AppStrings.profileSubtitle(lang),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: theme.textMain.withValues(alpha: 0.72),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _ProfileField(
                        label: AppStrings.firstName(lang),
                        controller: _firstNameController,
                        theme: theme,
                        enabled: _editing,
                        keyboardType: TextInputType.name,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r"[A-Za-zÀ-ÿÑñ\s'-]"),
                          ),
                          LengthLimitingTextInputFormatter(40),
                        ],
                        onChanged: _editing ? (_) => setState(() {}) : null,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _ProfileField(
                        label: AppStrings.lastName(lang),
                        controller: _lastNameController,
                        theme: theme,
                        enabled: _editing,
                        keyboardType: TextInputType.name,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r"[A-Za-zÀ-ÿÑñ\s'-]"),
                          ),
                          LengthLimitingTextInputFormatter(40),
                        ],
                        onChanged: _editing ? (_) => setState(() {}) : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                _ProfileReadOnlyValue(
                  label: AppStrings.emailAddress(lang),
                  value: user?.email ?? '',
                  theme: theme,
                ),
                if ((user?.isLearner ?? false) ||
                    (user?.isParent ?? false) ||
                    (user?.isTeacher ?? false)) ...[
                  const SizedBox(height: AppSpacing.md),
                  _ProfileField(
                    label: AppStrings.address(lang),
                    controller: _addressController,
                    theme: theme,
                    enabled: _editing,
                    keyboardType: TextInputType.streetAddress,
                    onChanged: _editing ? (_) => setState(() {}) : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (user?.isLearner ?? false)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 4,
                          child: _birthdateEditor(theme, lang),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          flex: 1,
                          child: _ProfileField(
                            label: AppStrings.age(lang),
                            controller: _ageController,
                            theme: theme,
                            enabled: _editing,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(3),
                            ],
                            onChanged: _editing
                                ? (value) {
                                    _applyAgeToBirthdate();
                                    setState(() {});
                                  }
                                : null,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          flex: 3,
                          child: _ProfileField(
                            label: AppStrings.gradeLevel(lang),
                            controller: _gradeLevelController,
                            theme: theme,
                            enabled: _editing,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(2),
                            ],
                            onChanged: _editing ? (_) => setState(() {}) : null,
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: _birthdateEditor(theme, lang),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          flex: 1,
                          child: _ProfileField(
                            label: AppStrings.age(lang),
                            controller: _ageController,
                            theme: theme,
                            enabled: _editing,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(3),
                            ],
                            onChanged: _editing
                                ? (value) {
                                    _applyAgeToBirthdate();
                                    setState(() {});
                                  }
                                : null,
                          ),
                        ),
                      ],
                    ),
                ],
                if (user?.isLearner ?? false) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    AppStrings.emergencyContacts(lang),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.textMain.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  _ProfileField(
                    label: '',
                    controller: _emergency1Controller,
                    theme: theme,
                    keyboardType: TextInputType.phone,
                    enabled: _editing,
                    showLabel: false,
                    hintText: AppStrings.emergencyContactHint(lang, 1),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s]')),
                      LengthLimitingTextInputFormatter(16),
                    ],
                    onChanged: _editing ? (_) => setState(() {}) : null,
                  ),
                  if (_showSecondEmergency) ...[
                    const SizedBox(height: AppSpacing.sm),
                    _ProfileField(
                      label: '',
                      controller: _emergency2Controller,
                      theme: theme,
                      keyboardType: TextInputType.phone,
                      enabled: _editing,
                      showLabel: false,
                      hintText: AppStrings.emergencyContactHint(lang, 2),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s]')),
                        LengthLimitingTextInputFormatter(16),
                      ],
                      onChanged: _editing ? (_) => setState(() {}) : null,
                    ),
                  ],
                  if (!_showSecondEmergency)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _editing
                            ? () => setState(() => _showSecondEmergency = true)
                            : null,
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: Text(AppStrings.addAnotherContact(lang)),
                        style: TextButton.styleFrom(
                          foregroundColor: theme.bgAccent,
                          padding: const EdgeInsets.only(top: 6, bottom: 2),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    AppStrings.profileCode(lang),
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: theme.textMain.withValues(alpha: 0.65),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            app.profileCode,
                            maxLines: 1,
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: theme.textMain,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: app.profileCode.isEmpty
                            ? null
                            : () async {
                                await Clipboard.setData(
                                  ClipboardData(text: app.profileCode),
                                );
                                if (!context.mounted) return;
                                await TapTalkResultDialog.showSuccess(
                                  context,
                                  title: AppStrings.copiedTitle(lang),
                                  message: AppStrings.copied(lang),
                                );
                              },
                        tooltip: AppStrings.copy(lang),
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(
                          minWidth: 28,
                          minHeight: 28,
                        ),
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          Icons.copy_rounded,
                          size: 16,
                          color: theme.bgAccent,
                        ),
                      ),
                      const Spacer(),
                      OutlinedButton(
                        onPressed: app.profileCode.isEmpty
                            ? null
                            : () => CodeQrSheet.show(
                                  context,
                                  title: AppStrings.showQrCode(lang),
                                  code: app.profileCode,
                                  subtitle: AppStrings.profileCodeHint(lang),
                                  shareMessage: AppStrings.shareProfileCodeMessage(
                                    lang,
                                    app.profileCode,
                                  ),
                                ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.textMain,
                          padding: const EdgeInsets.all(6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          side: BorderSide(
                            color: theme.textMain.withValues(alpha: 0.2),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                          ),
                        ),
                        child: Icon(
                          Icons.qr_code_2_rounded,
                          size: 24,
                          color: theme.textMain.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    AppStrings.profileCodeHint(lang),
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: theme.textMain.withValues(alpha: 0.62),
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                if (_editing && (_hasUnsavedChanges(app) || _saving))
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: _canSave(app) ? () => _save(app, lang) : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.bgAccent,
                        foregroundColor: Colors.white,
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusSm),
                        ),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              AppStrings.saveChanges(lang),
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
              ],
            ),
          ),
          PanelCard(
            borderRadius: 14,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                Text(
                  AppStrings.password(lang),
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: theme.textMain,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => _showEditPassword(app, lang),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: theme.textMain,
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    AppStrings.editPassword(lang),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
            ],
          ),
          if (_editing && _showFloatingCancel)
            Positioned(
              right: AppSpacing.lg,
              top: AppSpacing.sm,
              child: Material(
                color: Colors.white,
                elevation: 4,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: _saving ? null : _cancelEdits,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 7,
                    ),
                    child: Text(
                      AppStrings.cancel(lang),
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: theme.textMain,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EditPasswordDialog extends StatefulWidget {
  const _EditPasswordDialog({required this.app, required this.lang});

  final AppState app;
  final AppLanguage lang;

  @override
  State<_EditPasswordDialog> createState() => _EditPasswordDialogState();
}

class _EditPasswordDialogState extends State<_EditPasswordDialog> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;
  bool _busy = false;
  bool _obscureCurrent = true;
  bool _obscureNext = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    _next.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final lang = widget.lang;
    if (_current.text.isEmpty || _next.text.isEmpty || _confirm.text.isEmpty) {
      setState(() => _error = AppStrings.fillAllFields(lang));
      return;
    }
    if (_next.text != _confirm.text) {
      setState(() => _error = AppStrings.passwordsDoNotMatch(lang));
      return;
    }
    if (!AuthValidation.isStrongPassword(_next.text)) {
      setState(() => _error = AppStrings.passwordTooShort(lang));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await widget.app.changePassword(_current.text, _next.text);
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _busy = false;
        _error = err;
      });
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.lang;
    final theme = widget.app.theme;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      title: Row(
        children: [
          Expanded(
            child: Text(
              AppStrings.editPassword(lang),
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: theme.textMain,
              ),
            ),
          ),
          IconButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded, size: 20),
            color: theme.textMain,
            tooltip: AppStrings.cancel(lang),
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ProfileField(
                label: AppStrings.currentPassword(lang),
                controller: _current,
                theme: theme,
                obscure: _obscureCurrent,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 6,
                ),
                onToggleObscure: () =>
                    setState(() => _obscureCurrent = !_obscureCurrent),
              ),
              const SizedBox(height: AppSpacing.sm),
              _ProfileField(
                label: AppStrings.newPassword(lang),
                controller: _next,
                theme: theme,
                obscure: _obscureNext,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 6,
                ),
                onToggleObscure: () => setState(() => _obscureNext = !_obscureNext),
              ),
              PasswordStrengthHint(
                password: _next.text,
                lang: lang,
              ),
              const SizedBox(height: AppSpacing.sm),
              _ProfileField(
                label: AppStrings.confirmPassword(lang),
                controller: _confirm,
                theme: theme,
                obscure: _obscureConfirm,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 6,
                ),
                onToggleObscure: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text(AppStrings.cancel(lang)),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(AppStrings.saveChanges(lang)),
        ),
      ],
    );
  }
}

String _isoDate(DateTime d) {
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

int? _ageFromDate(DateTime birth) {
  final now = DateTime.now();
  var age = now.year - birth.year;
  final hadBirthday = now.month > birth.month ||
      (now.month == birth.month && now.day >= birth.day);
  if (!hadBirthday) age--;
  if (age < 1 || age > 120) return null;
  return age;
}

int? _ageFromIso(String iso) {
  final parsed = DateTime.tryParse(iso);
  if (parsed == null) return null;
  return _ageFromDate(parsed);
}

class _DatePartField extends StatelessWidget {
  const _DatePartField({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.theme,
    required this.hint,
    required this.maxLength,
    required this.width,
    this.embedded = false,
    this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final TapTalkThemeToken theme;
  final String hint;
  final int maxLength;
  final double width;
  final bool embedded;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: embedded ? 16 : null,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        enabled: enabled,
        onChanged: onChanged,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        textAlignVertical: TextAlignVertical.center,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(maxLength),
        ],
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: theme.textMain,
        ),
        decoration: InputDecoration(
          isDense: true,
          isCollapsed: embedded,
          filled: !embedded,
          fillColor: embedded ? Colors.transparent : Colors.white,
          hintText: hint,
          hintStyle: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w400,
            color: theme.textMain.withValues(alpha: 0.4),
          ),
          contentPadding: embedded
              ? EdgeInsets.zero
              : const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: AppSpacing.sm,
                ),
          border: embedded
              ? InputBorder.none
              : OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
        ),
      ),
    );
  }
}

class _ProfileReadOnlyValue extends StatelessWidget {
  const _ProfileReadOnlyValue({
    required this.label,
    required this.value,
    required this.theme,
  });

  final String label;
  final String value;
  final TapTalkThemeToken theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: theme.textMain.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: theme.textMain,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileField extends StatelessWidget {
  const _ProfileField({
    required this.label,
    required this.controller,
    required this.theme,
    this.obscure = false,
    this.onToggleObscure,
    this.onChanged,
    this.keyboardType,
    this.hintText,
    this.showLabel = true,
    this.enabled = true,
    this.inputFormatters,
    this.contentPadding,
  });

  final String label;
  final TextEditingController controller;
  final TapTalkThemeToken theme;
  final bool obscure;
  final VoidCallback? onToggleObscure;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final String? hintText;
  final bool showLabel;
  final bool enabled;
  final List<TextInputFormatter>? inputFormatters;
  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabel) ...[
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: theme.textMain.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        TextField(
          controller: controller,
          enabled: enabled,
          obscureText: obscure,
          onChanged: onChanged,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: theme.textMain,
          ),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            hintText: hintText,
            hintStyle: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: theme.textMain.withValues(alpha: 0.45),
            ),
            contentPadding: contentPadding ??
                const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.sm,
                ),
            suffixIconConstraints: onToggleObscure == null
                ? null
                : const BoxConstraints(minWidth: 32, minHeight: 32),
            suffixIcon: onToggleObscure == null
                ? null
                : IconButton(
                    icon: Icon(
                      obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 18,
                      color: theme.textMain.withValues(alpha: 0.55),
                    ),
                    onPressed: onToggleObscure,
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}
