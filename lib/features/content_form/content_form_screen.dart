import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/content_item.dart';
import '../../data/models/online_result.dart';
import '../../data/services/poster_store.dart';
import '../../providers/providers.dart';
import '../../shared/widgets/app_buttons.dart';
import '../../shared/widgets/genre_chip.dart';
import '../../shared/widgets/poster_image.dart';
import '../../shared/widgets/poster_picker.dart';
import '../../shared/widgets/rating_stars.dart';
import '../online_search/online_search_screen.dart';

/// Pantalla Agregar/Editar contenido (spec 7.1).
class ContentFormScreen extends ConsumerStatefulWidget {
  /// Si [original] es null se crea contenido nuevo.
  final ContentItem? original;

  /// Datos iniciales para contenido nuevo (p. ej. desde la búsqueda online).
  /// Se ignora si [original] no es null. No cuenta como edición: al guardar
  /// se genera un id nuevo.
  final ContentItem? draft;

  const ContentFormScreen({super.key, this.original, this.draft});

  @override
  ConsumerState<ContentFormScreen> createState() => _ContentFormScreenState();
}

class _ContentFormScreenState extends ConsumerState<ContentFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _noteController;
  late final TextEditingController _friendNameController;
  late final TextEditingController _friendNoteController;
  late final TextEditingController _episodesController;
  late final TextEditingController _currentEpisodeController;

  late ContentType _type;
  late List<String> _genres;
  late double _durationMinutes;
  late WatchStatus _status;
  double? _rating;
  DateTime? _watchDate;
  String? _posterUrl;
  late bool _isRecommendation;
  late bool _notifyMe;
  DateTime? _notificationDate;
  DateTime? _releaseDate;

  bool get _isEditing => widget.original != null;

  @override
  void initState() {
    super.initState();
    final item = widget.original ?? widget.draft;
    _titleController = TextEditingController(text: item?.title ?? '');
    _noteController = TextEditingController(text: item?.personalNote ?? '');
    _friendNameController =
        TextEditingController(text: item?.recommendedBy ?? '');
    _friendNoteController =
        TextEditingController(text: item?.recommendedNote ?? '');
    _episodesController =
        TextEditingController(text: item?.episodes?.toString() ?? '');
    _currentEpisodeController =
        TextEditingController(text: item?.currentEpisode?.toString() ?? '');

    _type = item?.type ?? ContentType.movie;
    _genres = List.of(item?.genres ?? const []);
    _durationMinutes = (item?.durationMinutes ?? 120).toDouble();
    _status = item?.status ?? WatchStatus.notStarted;
    _rating = item?.userRating;
    _watchDate = item?.watchDate;
    _posterUrl = item?.posterUrl;
    _isRecommendation = item?.source == ContentSource.friendRecommended;
    _notifyMe = item?.notifyMe ?? false;
    _notificationDate = item?.notificationDate;
    _releaseDate = item?.releaseDate;

    // El placeholder del póster usa la inicial del título.
    _titleController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    _friendNameController.dispose();
    _friendNoteController.dispose();
    _episodesController.dispose();
    _currentEpisodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(_isEditing ? 'form.title.edit' : 'form.title.add')),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              _buildPosterHeader(),
              const SizedBox(height: 20),
              _sectionLabel(tr('form.field.title')),
              TextFormField(
                controller: _titleController,
                autofocus: !_isEditing,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 1,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: tr('form.hint.example', {'x': 'Interstellar'}),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? tr('form.validator.titleRequired')
                    : null,
              ),
              const SizedBox(height: 20),
              _sectionLabel(tr('form.field.type')),
              _buildTypeSelector(),
              const SizedBox(height: 20),
              _sectionLabel(tr('form.field.genres')),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final genre in kGenres)
                    GenreChip(
                      label: localizedGenre(genre),
                      selected: _genres.contains(genre),
                      onTap: () => setState(() {
                        _genres.contains(genre)
                            ? _genres.remove(genre)
                            : _genres.add(genre);
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              _sectionLabel(
                _type.hasEpisodes
                    ? tr('form.field.durationPer', {'unit': _type.unitLabel})
                    : tr('form.field.duration'),
              ),
              _buildDurationSlider(),
              if (_type.hasEpisodes) ...[
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionLabel(
                            _type.unitsLabel[0].toUpperCase() +
                                _type.unitsLabel.substring(1),
                          ),
                          TextFormField(
                            controller: _episodesController,
                            keyboardType: TextInputType.number,
                            maxLines: 1,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: AppColors.textPrimary,
                            ),
                            decoration: InputDecoration(
                              hintText: tr('form.hint.example', {'x': '10'}),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return null;
                              }
                              final n = int.tryParse(value.trim());
                              return (n == null || n <= 0)
                                  ? tr('form.validator.invalidNumber')
                                  : null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionLabel(
                            _type.isRead
                                ? tr('form.field.lastVolumeRead')
                                : tr('form.field.lastEpisodeSeen'),
                          ),
                          TextFormField(
                            controller: _currentEpisodeController,
                            keyboardType: TextInputType.number,
                            maxLines: 1,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: AppColors.textPrimary,
                            ),
                            decoration: InputDecoration(
                              hintText: tr('form.hint.example', {'x': '3'}),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return null;
                              }
                              final n = int.tryParse(value.trim());
                              return (n == null || n < 0)
                                  ? tr('form.validator.invalidNumber')
                                  : null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              _sectionLabel(tr('form.field.status')),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final status in WatchStatus.values)
                    GenreChip(
                      label: status.label,
                      icon: status.icon,
                      selected: _status == status,
                      onTap: () => setState(() => _status = status),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              _sectionLabel(tr('form.field.rating')),
              Row(
                children: [
                  RatingStars(
                    rating: _rating,
                    size: 32,
                    onChanged: (value) => setState(() => _rating = value),
                  ),
                  const Spacer(),
                  if (_rating != null)
                    IconButton(
                      tooltip: tr('form.tooltip.clearRating'),
                      onPressed: () => setState(() => _rating = null),
                      icon: Icon(
                        Icons.close,
                        color: AppColors.textMuted,
                        size: 20,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              _sectionLabel(tr('form.field.watchDate')),
              _buildDateTile(
                value: _watchDate,
                hint: tr('form.hint.pickDate'),
                icon: Icons.event_outlined,
                onPick: _pickWatchDate,
                onClear: () => setState(() => _watchDate = null),
              ),
              const SizedBox(height: 20),
              _sectionLabel(tr('form.field.note')),
              TextFormField(
                controller: _noteController,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: tr('form.hint.note'),
                ),
              ),
              const SizedBox(height: 20),
              _buildToggleTile(
                title: tr('form.toggle.isRec.title'),
                subtitle: tr('form.toggle.isRec.subtitle'),
                value: _isRecommendation,
                icon: Icons.people_outline,
                onChanged: (value) =>
                    setState(() => _isRecommendation = value),
              ),
              if (_isRecommendation) ...[
                const SizedBox(height: 14),
                TextFormField(
                  controller: _friendNameController,
                  maxLines: 1,
                  textCapitalization: TextCapitalization.words,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    labelText: tr('form.field.recommendedBy'),
                    hintText: tr('form.hint.friendName'),
                  ),
                  validator: (value) {
                    if (!_isRecommendation) return null;
                    return (value == null || value.trim().isEmpty)
                        ? tr('form.validator.recommendedByRequired')
                        : null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _friendNoteController,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    labelText: tr('form.field.friendNote'),
                    hintText: tr('form.hint.friendNote'),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              _buildToggleTile(
                title: tr('form.toggle.reminder.title'),
                subtitle: _notifyMe && _notificationDate != null
                    ? formatDateTime(_notificationDate!)
                    : tr('form.toggle.reminder.subtitle'),
                value: _notifyMe,
                icon: Icons.notifications_active_outlined,
                onChanged: (value) async {
                  if (value) {
                    final picked = await _pickNotificationDateTime();
                    if (picked != null) {
                      setState(() {
                        _notifyMe = true;
                        _notificationDate = picked;
                      });
                    }
                  } else {
                    setState(() {
                      _notifyMe = false;
                      _notificationDate = null;
                    });
                  }
                },
              ),
              if (_notifyMe && _notificationDate != null) ...[
                const SizedBox(height: 14),
                _buildDateTile(
                  value: _notificationDate,
                  hint: tr('form.hint.pickDateTime'),
                  icon: Icons.alarm,
                  withTime: true,
                  onPick: () async {
                    final picked = await _pickNotificationDateTime();
                    if (picked != null) {
                      setState(() => _notificationDate = picked);
                    }
                  },
                  onClear: () => setState(() {
                    _notifyMe = false;
                    _notificationDate = null;
                  }),
                ),
              ],
              const SizedBox(height: 32),
              // Botones finales: Cancelar | Guardar (Expanded, nunca comprimidos).
              Row(
                children: [
                  Expanded(
                    child: SecondaryButton(
                      label: tr('common.cancel'),
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PrimaryButton(
                      label: tr(_isEditing ? 'form.saveChanges' : 'common.save'),
                      icon: Icons.check,
                      onTap: _save,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Widgets auxiliares ----------------------------------------------------

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      );

  Widget _buildPosterHeader() {
    final preview = ContentItem(
      id: 'preview',
      title: _titleController.text.isEmpty ? '?' : _titleController.text,
      type: _type,
      posterUrl: _posterUrl,
      addedAt: DateTime.now(),
    );

    return Center(
      child: GestureDetector(
        onTap: () => showPosterOptions(
          context,
          hasPoster: _posterUrl != null,
          currentUrl: _posterUrl,
          onChanged: (value) => setState(() => _posterUrl = value),
          onSearchOnline: _searchOnline,
        ),
        child: Stack(
          children: [
            Container(
              width: 150,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: 2 / 3,
                  child: PosterImage(item: preview),
                ),
              ),
            ),
            Positioned(
              right: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.photo_camera_outlined,
                  size: 18,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<ContentType>(
          value: _type,
          isExpanded: true,
          borderRadius: BorderRadius.circular(14),
          dropdownColor: AppColors.surfaceElevated,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.textSecondary,
          ),
          items: [
            for (final type in ContentType.values)
              DropdownMenuItem(
                value: type,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(type.emoji, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        type.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          onChanged: (value) {
            if (value != null) setState(() => _type = value);
          },
        ),
      ),
    );
  }

  Widget _buildDurationSlider() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.schedule, size: 18, color: AppColors.secondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  formatDuration(_durationMinutes.round()),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                '${_durationMinutes.round()} min',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          Slider(
            value: _durationMinutes.clamp(5, 300),
            min: 5,
            max: 300,
            divisions: 59,
            onChanged: (value) => setState(() => _durationMinutes = value),
          ),
        ],
      ),
    );
  }

  Widget _buildDateTile({
    required DateTime? value,
    required String hint,
    required IconData icon,
    required VoidCallback onPick,
    required VoidCallback onClear,
    bool withTime = false,
  }) {
    return Material(
      color: AppColors.surfaceElevated,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPick,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: AppColors.secondary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value == null
                      ? hint
                      : withTime
                          ? formatDateTime(value)
                          : formatDate(value),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight:
                        value == null ? FontWeight.w400 : FontWeight.w500,
                    color: value == null
                        ? AppColors.textMuted
                        : AppColors.textPrimary,
                  ),
                ),
              ),
              if (value != null)
                GestureDetector(
                  onTap: onClear,
                  child: Icon(
                    Icons.close,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggleTile({
    required String title,
    required String subtitle,
    required bool value,
    required IconData icon,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: AppColors.tertiary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  // --- Pickers ---------------------------------------------------------------

  Future<void> _pickWatchDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _watchDate ?? now,
      firstDate: DateTime(1950),
      lastDate: DateTime(now.year + 5),
      locale: S.lang.locale,
    );
    if (picked != null) setState(() => _watchDate = picked);
  }

  Future<DateTime?> _pickNotificationDateTime() async {
    final now = DateTime.now();
    final initial = _notificationDate != null && _notificationDate!.isAfter(now)
        ? _notificationDate!
        : now.add(const Duration(hours: 1));

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5),
      locale: S.lang.locale,
    );
    if (date == null || !mounted) return null;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return null;

    final result =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    if (result.isBefore(DateTime.now())) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('form.reminder.mustBeFuture')),
          ),
        );
      }
      return null;
    }
    return result;
  }

  Future<void> _searchOnline() async {
    final result = await Navigator.of(context).push<OnlineResult>(
      MaterialPageRoute(
        builder: (_) => OnlineSearchScreen(pickerMode: true, lockedType: _type),
      ),
    );
    if (result != null && mounted) await _applyOnlineResult(result);
  }

  /// Trae datos del resultado elegido a la ficha en edición: el póster siempre;
  /// el resto de campos solo si están vacíos (no piso lo que ya escribiste).
  ///
  /// El póster se baja al disco aquí mismo: es el único momento en que sabemos
  /// que hay red, y así la ficha ya no depende de que la URL siga viva.
  Future<void> _applyOnlineResult(OnlineResult r) async {
    final remotePoster = r.posterUrl;
    String? poster;
    if (remotePoster != null && remotePoster.isNotEmpty) {
      poster = await ref.read(posterStoreProvider).download(remotePoster) ??
          remotePoster;
      if (!mounted) return;
    }

    var importedInfo = false;
    setState(() {
      if (poster != null) {
        _posterUrl = poster;
      }
      if (_titleController.text.trim().isEmpty && r.title.isNotEmpty) {
        _titleController.text = r.title;
        importedInfo = true;
      }
      if (_genres.isEmpty && r.genres.isNotEmpty) {
        _genres = List.of(r.genres);
        importedInfo = true;
      }
      if (_noteController.text.trim().isEmpty &&
          (r.overview?.isNotEmpty ?? false)) {
        _noteController.text = r.overview!;
        importedInfo = true;
      }
      if (_type.hasEpisodes &&
          r.episodes != null &&
          _episodesController.text.trim().isEmpty) {
        _episodesController.text = r.episodes.toString();
        importedInfo = true;
      }
      if (_releaseDate == null && r.releaseDate != null) {
        _releaseDate = r.releaseDate;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          tr(importedInfo
              ? 'form.imported.info'
              : 'form.imported.posterOnly'),
        ),
      ),
    );
  }
  // --- Guardado ----------------------------------------------------------------

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final original = widget.original;
    final episodes = _type.hasEpisodes
        ? int.tryParse(_episodesController.text.trim())
        : null;
    var currentEpisode = _type.hasEpisodes
        ? int.tryParse(_currentEpisodeController.text.trim())
        : null;
    if (currentEpisode != null && episodes != null) {
      currentEpisode = currentEpisode.clamp(0, episodes);
    }

    ContentSource source;
    if (_isRecommendation) {
      source = ContentSource.friendRecommended;
    } else if (original != null &&
        original.source != ContentSource.friendRecommended) {
      source = original.source;
    } else {
      source = ContentSource.own;
    }

    final item = ContentItem(
      id: original?.id ?? const Uuid().v4(),
      title: _titleController.text.trim(),
      type: _type,
      genres: _genres,
      durationMinutes: _durationMinutes.round(),
      episodes: episodes,
      currentEpisode: currentEpisode,
      status: _status,
      userRating: _rating,
      personalNote: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
      posterUrl: _posterUrl,
      watchDate: _watchDate,
      releaseDate: _releaseDate,
      addedAt: original?.addedAt ?? DateTime.now(),
      source: source,
      recommendedBy: _isRecommendation
          ? _friendNameController.text.trim()
          : null,
      recommendedNote:
          _isRecommendation && _friendNoteController.text.trim().isNotEmpty
              ? _friendNoteController.text.trim()
              : null,
      notifyMe: _notifyMe && _notificationDate != null,
      notificationDate: _notifyMe ? _notificationDate : null,
      rewatchCount: original?.rewatchCount,
      isFavorite: original?.isFavorite ?? false,
    );

    await ref.read(contentActionsProvider).save(item);

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(_isEditing ? 'form.saved.updated' : 'form.saved.added',
                {'title': item.title}),
          ),
        ),
      );
    }
  }
}
