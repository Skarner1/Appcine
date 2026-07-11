import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/content_item.dart';
import '../../data/models/online_result.dart';
import '../../providers/providers.dart';
import '../../shared/widgets/app_buttons.dart';
import '../../shared/widgets/custom_bottom_sheet.dart';
import '../../shared/widgets/genre_chip.dart';
import '../../shared/widgets/poster_image.dart';
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
        title: Text(_isEditing ? 'Editar contenido' : 'Agregar contenido'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              _buildPosterHeader(),
              const SizedBox(height: 20),
              _sectionLabel('Título'),
              TextFormField(
                controller: _titleController,
                autofocus: !_isEditing,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 1,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
                decoration: const InputDecoration(
                  hintText: 'Ej. Interstellar',
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'El título es obligatorio'
                    : null,
              ),
              const SizedBox(height: 20),
              _sectionLabel('Tipo'),
              _buildTypeSelector(),
              const SizedBox(height: 20),
              _sectionLabel('Géneros'),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final genre in kGenres)
                    GenreChip(
                      label: genre,
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
                _type.hasEpisodes ? 'Duración por episodio' : 'Duración',
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
                          _sectionLabel('Episodios'),
                          TextFormField(
                            controller: _episodesController,
                            keyboardType: TextInputType.number,
                            maxLines: 1,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: AppColors.textPrimary,
                            ),
                            decoration:
                                const InputDecoration(hintText: 'Ej. 10'),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return null;
                              }
                              final n = int.tryParse(value.trim());
                              return (n == null || n <= 0)
                                  ? 'Número inválido'
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
                          _sectionLabel('Último ep. visto'),
                          TextFormField(
                            controller: _currentEpisodeController,
                            keyboardType: TextInputType.number,
                            maxLines: 1,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: AppColors.textPrimary,
                            ),
                            decoration:
                                const InputDecoration(hintText: 'Ej. 3'),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return null;
                              }
                              final n = int.tryParse(value.trim());
                              return (n == null || n < 0)
                                  ? 'Número inválido'
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
              _sectionLabel('Estado'),
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
              _sectionLabel('Calificación'),
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
                      tooltip: 'Quitar calificación',
                      onPressed: () => setState(() => _rating = null),
                      icon: const Icon(
                        Icons.close,
                        color: AppColors.textMuted,
                        size: 20,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              _sectionLabel('Fecha planificada / de visionado'),
              _buildDateTile(
                value: _watchDate,
                hint: 'Elegir fecha',
                icon: Icons.event_outlined,
                onPick: _pickWatchDate,
                onClear: () => setState(() => _watchDate = null),
              ),
              const SizedBox(height: 20),
              _sectionLabel('Nota personal'),
              TextFormField(
                controller: _noteController,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
                decoration: const InputDecoration(
                  hintText: '¿Por qué la quieres ver? ¿Qué te pareció?',
                ),
              ),
              const SizedBox(height: 20),
              _buildToggleTile(
                title: '¿Es una recomendación?',
                subtitle: 'Guarda quién te la recomendó y su nota',
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
                  decoration: const InputDecoration(
                    labelText: 'Recomendado por',
                    hintText: 'Nombre del amigo',
                  ),
                  validator: (value) {
                    if (!_isRecommendation) return null;
                    return (value == null || value.trim().isEmpty)
                        ? 'Indica quién la recomendó'
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
                  decoration: const InputDecoration(
                    labelText: 'Nota del amigo',
                    hintText: '"Tienes que verla, es una joya…"',
                  ),
                ),
              ],
              const SizedBox(height: 14),
              _buildToggleTile(
                title: 'Recordatorio de visionado',
                subtitle: _notifyMe && _notificationDate != null
                    ? formatDateTime(_notificationDate!)
                    : 'Recibe una notificación para no olvidarla',
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
                  hint: 'Elegir fecha y hora',
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
                      label: 'Cancelar',
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PrimaryButton(
                      label: _isEditing ? 'Guardar cambios' : 'Guardar',
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
        onTap: _openPosterOptions,
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
          icon: const Icon(
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
                  child: const Icon(
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
      locale: const Locale('es'),
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
      locale: const Locale('es'),
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
          const SnackBar(
            content: Text('La fecha del recordatorio debe ser futura.'),
          ),
        );
      }
      return null;
    }
    return result;
  }

  void _openPosterOptions() {
    showAppBottomSheet<void>(
      context: context,
      title: 'Imagen de portada',
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.all(20),
        children: [
          _posterOption(
            icon: Icons.travel_explore_rounded,
            label: 'Buscar en internet',
            color: AppColors.primary,
            onTap: () async {
              Navigator.of(context).pop();
              await _searchOnline();
            },
          ),
          const SizedBox(height: 12),
          _posterOption(
            icon: Icons.photo_library_outlined,
            label: 'Elegir de la galería',
            onTap: () async {
              Navigator.of(context).pop();
              await _pickFromGallery();
            },
          ),
          const SizedBox(height: 12),
          _posterOption(
            icon: Icons.link,
            label: 'Usar URL de imagen',
            onTap: () async {
              Navigator.of(context).pop();
              await _askPosterUrl();
            },
          ),
          if (_posterUrl != null) ...[
            const SizedBox(height: 12),
            _posterOption(
              icon: Icons.delete_outline,
              label: 'Quitar portada',
              color: AppColors.error,
              onTap: () {
                Navigator.of(context).pop();
                setState(() => _posterUrl = null);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _posterOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = AppColors.textPrimary,
  }) {
    return Material(
      color: AppColors.surfaceElevated,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _searchOnline() async {
    final result = await Navigator.of(context).push<OnlineResult>(
      MaterialPageRoute(
        builder: (_) => OnlineSearchScreen(pickerMode: true, lockedType: _type),
      ),
    );
    if (result != null && mounted) _applyOnlineResult(result);
  }

  /// Trae datos del resultado elegido a la ficha en edición: el póster siempre;
  /// el resto de campos solo si están vacíos (no piso lo que ya escribiste).
  void _applyOnlineResult(OnlineResult r) {
    var importedInfo = false;
    setState(() {
      if (r.posterUrl != null && r.posterUrl!.isNotEmpty) {
        _posterUrl = r.posterUrl;
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
          importedInfo
              ? 'Póster e información importados de internet'
              : 'Póster actualizado desde internet',
        ),
      ),
    );
  }

  Future<void> _pickFromGallery() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        imageQuality: 88,
      );
      if (picked == null) return;

      // Copia persistente en el directorio de la app.
      final dir = await getApplicationDocumentsDirectory();
      final postersDir = Directory('${dir.path}/posters');
      if (!postersDir.existsSync()) {
        postersDir.createSync(recursive: true);
      }
      final ext = picked.path.contains('.')
          ? picked.path.substring(picked.path.lastIndexOf('.'))
          : '.jpg';
      final target = '${postersDir.path}/${const Uuid().v4()}$ext';
      await File(picked.path).copy(target);

      if (mounted) setState(() => _posterUrl = target);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo cargar la imagen.')),
        );
      }
    }
  }

  Future<void> _askPosterUrl() async {
    final controller = TextEditingController(
      text: (_posterUrl?.startsWith('http') ?? false) ? _posterUrl : '',
    );
    final result = await showDialog<String>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'URL del póster',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                maxLines: 1,
                keyboardType: TextInputType.url,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
                decoration: const InputDecoration(
                  hintText: 'https://…',
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: SecondaryButton(
                      label: 'Cancelar',
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PrimaryButton(
                      label: 'Usar',
                      onTap: () =>
                          Navigator.of(context).pop(controller.text.trim()),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (result != null && result.startsWith('http')) {
      setState(() => _posterUrl = result);
    }
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
            _isEditing
                ? '"${item.title}" actualizado'
                : '"${item.title}" agregado al catálogo',
          ),
        ),
      );
    }
  }
}
