# 🎬 CINELOG PRO — Especificación Técnica & Prompt de Desarrollo

> **App Flutter** para gestión personal de películas, series, documentales y recomendaciones sociales. Diseño premium, responsive, sin comprimientos de UI, con notificaciones inteligentes.

---

## 1. VISIÓN DEL PRODUCTO

CineLog Pro es una app móvil que permite a los usuarios:
- **Catalogar** todo su contenido audiovisual (películas, series, documentales)
- **Organizar** por género, tipo, duración, estado de visualización
- **Planificar** qué ver, cuándo verlo, y recordatorios
- **Compartir** recomendaciones con amigos
- **Recibir notificaciones** inteligentes sobre estrenos, fechas de visionado, etc.

**Tono de marca:** Premium, cinematográfico, organizado, moderno.

---

## 2. PALETA DE COLORES PROFESIONAL

```dart
// theme.dart — Paleta oficial CineLog Pro
class AppColors {
  // Fondos
  static const Color background = Color(0xFF0F0F0F);        // Negro profundo
  static const Color surface = Color(0xFF1A1A1A);           // Tarjetas/secciones
  static const Color surfaceElevated = Color(0xFF252525);    // Elevación superior

  // Acentos cinematográficos
  static const Color primary = Color(0xFFE50914);          // Rojo Netflix-style (cinemático)
  static const Color primarySoft = Color(0xFFB81D25);      // Rojo suave para hover
  static const Color secondary = Color(0xFF00B4D8);        // Cyan para info/duración
  static const Color tertiary = Color(0xFFFFB703);           // Ámbar para recomendaciones/destacados

  // Estados
  static const Color success = Color(0xFF2ECC71);          // Visto / Completado
  static const Color warning = Color(0xFFF39C12);          // Pendiente / Falta ver
  static const Color info = Color(0xFF3498DB);             // Recomendado
  static const Color error = Color(0xFFE74C3C);            // Eliminar / Error

  // Texto
  static const Color textPrimary = Color(0xFFF5F5F5);      // Blanco hueso
  static const Color textSecondary = Color(0xFFB0B0B0);    // Gris claro
  static const Color textMuted = Color(0xFF707070);        // Gris medio

  // Bordes y divisores
  static const Color border = Color(0xFF2A2A2A);           // Sutil
  static const Color divider = Color(0xFF333333);          // Separadores
}
```

---

## 3. TIPOGRAFÍA (Google Fonts)

```dart
// Font: 'Poppins' + 'Inter'
// - Títulos: Poppins SemiBold (600) / Bold (700)
// - Subtítulos: Poppins Medium (500)
// - Cuerpo: Inter Regular (400) / Medium (500)
// - Etiquetas/Tags: Inter SemiBold (600)

// Tamaños responsive (no fijos, usar MediaQuery o sizer)
// - Título pantalla: 24-28sp
// - Título tarjeta: 16-18sp
// - Subtítulo: 14sp
// - Cuerpo: 13-14sp
// - Caption/Tag: 11-12sp
```

---

## 4. DISEÑO DE COMPONENTES (Anti-Bug Responsive)

### 4.1 Botones (NUNCA comprimidos)

```dart
// BOTÓN PRINCIPAL (usar en todo el app)
class PrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  final bool isFullWidth;

  const PrimaryButton({
    required this.label,
    this.icon,
    required this.onTap,
    this.isFullWidth = true,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final buttonHeight = screenWidth < 360 ? 48.0 : 56.0; // Mínimo 48dp nunca menos

    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      height: buttonHeight,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: AppColors.primary.withOpacity(0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14), // Radio consistente
          ),
          padding: EdgeInsets.symmetric(
            horizontal: 24,
            vertical: (buttonHeight - 20) / 2, // Centrado vertical garantizado
          ),
          minimumSize: Size(isFullWidth ? double.infinity : 120, buttonHeight),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20),
              SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  letterSpacing: 0.3,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// BOTÓN SECUNDARIO (outline)
class SecondaryButton extends StatelessWidget {
  // Similar pero con borde y fondo transparente
  // border: 1.5dp, color: AppColors.border, texto: AppColors.textPrimary
}

// BOTÓN ACCIÓN FLOTANTE (FAB) personalizado
// - Tamaño: 64dp (nunca 56dp, se ve pequeño en esta app)
// - Sombra: elevation 8, shadowColor primary con opacidad 0.3
// - BorderRadius: 20dp (no circular, rounded rectangle moderno)
```

### 4.2 Tarjetas de Contenido (Premier Card)

```dart
class ContentCard extends StatelessWidget {
  // Cada tarjeta DEBE tener:
  // - Aspect ratio poster: 2:3 (poster cinematográfico)
  // - BorderRadius: 16dp
  // - Sombra suave: elevation 2, shadowColor black con opacidad 0.3
  // - Overlay degradado en la parte inferior para texto
  // - Badge de estado (Visto, Pendiente, Recomendado) en esquina superior derecha
  // - Título truncado con ellipsis, max 2 líneas
  // - Género como chip pequeño debajo del título
  // - Duración/episodios con icono de reloj
}
```

### 4.3 Chips de Género/Estado (Anti-Overflow)

```dart
class GenreChip extends StatelessWidget {
  // Usar Wrap() en lugar de Row() cuando hay múltiples chips
  // Padding: 8dp horiz, 6dp vert
  // BorderRadius: 20dp (fully rounded)
  // FontSize: 11sp
  // Background: AppColors.surfaceElevated
  // Border: 1dp AppColors.border
}
```

### 4.4 Bottom Navigation (Premium)

```dart
// BottomNavigationBar personalizado:
// - Altura: 72dp (no 56dp, se ve más premium)
// - Background: AppColors.surface con border top 1dp AppColors.border
// - 4 pestañas: Catálogo, Por Ver, Recomendados, Mi Perfil
// - Iconos: LineIcons o PhosphorIcons (outline, no filled)
// - Icono seleccionado: filled + color primary + scale 1.1
// - Label: siempre visible, fontSize 11, fontWeight 500
// - AnimatedContainer para transiciones suaves
// - SafeArea garantizada arriba
```

---

## 5. ESTRUCTURA DE NAVEGACIÓN

```
📱 App Structure (BottomNavigationBar: 4 tabs)

├── Tab 1: CATÁLOGO (Home)
│   ├── AppBar con search bar integrada
│   ├── Chips de filtro rápido (Películas | Series | Documentales | Todo)
│   ├── Grid de contenido (2 columnas, gap 16dp)
│   └── FAB: "+ Agregar"
│
├── Tab 2: POR VER (Watchlist)
│   ├── Segmented control: Falta Ver | Volver a Ver | Vistos
│   ├── Lista vertical con cards horizontales (mejor info)
│   └── Indicador de fecha programada si existe
│
├── Tab 3: RECOMENDADOS (Social)
│   ├── Toggle: Amigos | Sistema | Tendencias
│   ├── Cards con avatar de amigo y nota personal
│   └── Botón "Marcar como Pendiente"
│
└── Tab 4: PERFIL & NOTIFICACIONES
    ├── Resumen de estadísticas (vistas, por género, tiempo total)
    ├── Lista de notificaciones programadas
    └── Configuración (exportar, importar, tema)
```

---

## 6. MODELO DE DATOS (Hive/Isar para local)

```dart
// content_model.dart
@HiveType(typeId: 1)
class ContentItem extends HiveObject {
  @HiveField(0)
  String id; // UUID v4

  @HiveField(1)
  String title; // Título original

  @HiveField(2)
  ContentType type; // enum: movie, series, documentary, anime, shortFilm

  @HiveField(3)
  List<String> genres; // Acción, Drama, Comedia, etc.

  @HiveField(4)
  int durationMinutes; // Para películas

  @HiveField(5)
  int? episodes; // Para series (null si es película)

  @HiveField(6)
  int? currentEpisode; // Último episodio visto

  @HiveField(7)
  WatchStatus status; // enum: notStarted, watching, completed, onHold, dropped

  @HiveField(8)
  double? userRating; // 1.0 - 10.0

  @HiveField(9)
  String? personalNote; // Nota del usuario

  @HiveField(10)
  String? posterUrl; // URL local o remota

  @HiveField(11)
  DateTime? watchDate; // Fecha en que la vio / planea ver

  @HiveField(12)
  DateTime? releaseDate; // Fecha de estreno

  @HiveField(13)
  DateTime addedAt; // Cuándo se agregó al catálogo

  @HiveField(14)
  ContentSource source; // enum: own, friendRecommended, trending, algorithm

  @HiveField(15)
  String? recommendedBy; // Nombre del amigo que recomendó

  @HiveField(16)
  String? recommendedNote; // Nota que dejó el amigo

  @HiveField(17)
  bool notifyMe; // Si tiene notificación activa

  @HiveField(18)
  DateTime? notificationDate; // Fecha/hora de la notificación

  @HiveField(19)
  int? rewatchCount; // Cuántas veces la ha visto

  @HiveField(20)
  bool isFavorite; // Marcada como favorita
}

enum ContentType { movie, series, documentary, anime, shortFilm }

enum WatchStatus { 
  notStarted,      // Falta ver
  watching,        // Viendo ahora
  completed,       // Visto
  onHold,          // Pausada
  dropped,         // Abandonada
  rewatchPending,  // Volver a ver
}

enum ContentSource { own, friendRecommended, trending, algorithm }
```

---

## 7. PANTALLAS DETALLADAS

### 7.1 Pantalla: Agregar/Editar Contenido

```
ScrollView con:
├── Header con imagen de portada (tap para cambiar)
├── Formulario:
│   ├── Título (TextField, autofocus)
│   ├── Tipo (Dropdown/Drop con iconos: 🎬 🎞️ 📺)
│   ├── Géneros (Multi-select chips con Wrap)
│   ├── Duración (Number input con slider visual)
│   ├── Episodios (solo si es serie, condicional)
│   ├── Estado (Radio/Chip group: Falta ver, Viendo, Visto, Pausada, Volver a ver)
│   ├── Calificación (Star rating 1-10 con estrellas media)
│   ├── Fecha planificada (DatePicker moderno)
│   ├── Nota personal (TextField multiline, max 3 líneas visible)
│   ├── ¿Es recomendación? (Toggle)
│   │   └── Si SÍ: campo "Recomendado por" + "Nota del amigo"
│   └── Notificación (Toggle + DateTimePicker si activo)
│
└── Bottom: 2 botones en Row (Cancelar | Guardar)
    // Cancelar: outline, Guardar: primary filled
    // Padding bottom: 24dp + SafeArea
```

### 7.2 Pantalla: Detalle del Contenido

```
CustomScrollView con SliverAppBar:
├── SliverAppBar (collapsedHeight: 80, expandedHeight: 400)
│   ├── Background: poster con blur overlay
│   └── Title: título truncado cuando colapsa
│
├── SliverToBoxAdapter:
│   ├── Row de acciones rápidas:
│   │   [Marcar como Visto] [Programar] [Compartir] [Editar]
│   │   // Cada uno: IconButton + label debajo, en Wrap
│   ├── Info grid: Año | Duración | Géneros | Episodios
│   ├── Sinopsis/Nota personal (expandible)
│   ├── Si es recomendación: Card especial con avatar y nota del amigo
│   └── Historial de visionados (si rewatched > 0)
│
└── SliverFillRemaining: Contenido relacionado o similar
```

### 7.3 Pantalla: Notificaciones

```
ListView con grupos por fecha:
├── Hoy
│   └── [🎬] "Dune: Parte Dos" — Programado para hoy a las 20:00
│       [Ver ahora] [Posponer] [Descartar]
├── Próximos 7 días
│   └── [📺] "Breaking Bad S01E01" — Viernes 22:00
├── Próximos 30 días
│   └── [📺] "The Last of Us S02E03" — 15 de marzo
└── Pasadas
    └── [✅] "Oppenheimer" — Visto el 10 de enero
```

---

## 8. REGLAS DE RESPONSIVE ANTI-BUG

```dart
// RESPONSIVE RULES — obligatorias en todo el app:

// 1. NUNCA usar Container sin constraints para botones
//    ❌ Mal: Container(width: double.infinity, height: 40) 
//    ✅ Bien: SizedBox(width: double.infinity, height: 56)

// 2. NUNCA poner Row de botones sin Wrap o Expanded
//    ❌ Mal: Row(children: [Button1(), Button2(), Button3()])
//    ✅ Bien: Wrap(spacing: 12, children: [Button1(), Button2(), Button3()])
//    ✅ O bien: Row(children: [Expanded(flex: 1, child: Button1()), Expanded(flex: 1, child: Button2())])

// 3. Textos siempre con overflow: TextOverflow.ellipsis, maxLines: 1 o 2
// 4. Icons: tamaño mínimo 24dp, nunca 16dp en botones principales
// 5. Padding mínimo entre elementos: 12dp (nunca 4dp o 8dp en espaciados grandes)
// 6. Grid spacing: 16dp mínimo
// 7. Bottom sheet: altura mínima 60% de pantalla, max 90%, con Handle bar (4x32dp) arriba
// 8. TextFields: altura mínima 56dp, borderRadius 12dp, filled: true con AppColors.surfaceElevated
// 9. Modales: usar Dialog con borderRadius 20dp, no AlertDialog del sistema
// 10. SafeArea SIEMPRE en pantallas con navegación inferior

// Layout breakpoints:
// - Compact: < 360dp width (teléfonos pequeños) → 1 columna en grid, botones apilados
// - Medium: 360-600dp → 2 columnas en grid, botones en fila
// - Expanded: > 600dp → 3-4 columnas, side panel si es tablet
```

---

## 9. ANIMACIONES Y MICRO-INTERACCIONES

```dart
// 1. Page transitions: Fade + Slide desde derecha, 300ms, Curves.easeInOutCubic
// 2. Card tap: Scale 0.97 al presionar, 200ms
// 3. FAB: Scale + Rotate al aparecer, 400ms, elasticOut
// 4. List items: Staggered animation (100ms delay entre cada item)
// 5. Chips: Scale bounce al seleccionar
// 6. Bottom sheet: Slide up + fade, 350ms, Curves.decelerate
// 7. Skeleton loading: Shimmer effect en cards mientras carga imágenes
// 8. Estado toggle: Color transition 300ms, icon flip
// 9. Pull-to-refresh: Custom animation con logo de la app
// 10. Empty states: Ilustración animada Lottie + mensaje amigable
```

---

## 10. NOTIFICACIONES (flutter_local_notifications)

```dart
// Tipos de notificaciones:
enum NotificationType {
  watchReminder,      // "Hoy toca ver: Dune a las 20:00"
  newEpisode,         // "Breaking Bad S03E05 disponible"
  releaseDate,        // "Oppenheimer se estrena hoy en cines"
  rewatchSuggestion,  // "Hace 1 año viste Interstellar. ¿Volver a ver?"
  friendRecommendation,// "Juan te recomendó ver 'The Batman'"
}

// Requisitos:
// - Icono de app con badge
// - Sonido personalizado sutil (no default)
// - Acciones rápidas: [Ver ahora] [Posponer 1h] [Descartar]
// - Canal: "recordatorios_visionado" con alta prioridad
// - Programación: flutter_local_notifications + timezone
```

---

## 11. DEPENDENCIAS FLUTTER REQUERIDAS

```yaml
dependencies:
  flutter:
    sdk: flutter
  # Estado
  flutter_bloc: ^8.1.3
  # o riverpod: ^2.4.0

  # Almacenamiento local
  hive_flutter: ^1.1.0
  # o isar_flutter_libs: ^3.1.0

  # Notificaciones
  flutter_local_notifications: ^16.0.0
  timezone: ^0.9.0

  # UI
  google_fonts: ^6.1.0
  flutter_svg: ^2.0.0
  cached_network_image: ^3.3.0
  shimmer: ^3.0.0
  lottie: ^2.7.0
  intl: ^0.18.0
  fl_chart: ^0.65.0  # Para estadísticas en perfil

  # Utilidades
  uuid: ^4.0.0
  equatable: ^2.0.0
  freezed_annotation: ^2.4.0
  json_annotation: ^4.8.0
  image_picker: ^1.0.0
  url_launcher: ^6.2.0
  share_plus: ^7.0.0

dev_dependencies:
  build_runner: ^2.4.0
  freezed: ^2.4.0
  json_serializable: ^6.7.0
  hive_generator: ^2.0.0
```

---

## 12. PROMPT TÉCNICO PARA GENERACIÓN DE CÓDIGO (Copiar y pegar en IA)

```
Desarrolla una app Flutter profesional llamada "CineLog Pro" con las siguientes características:

### ESTÉTICA Y DISEÑO (CRÍTICO - NO NEGOCIABLE):
- Paleta cinematográfica: fondo #0F0F0F, superficie #1A1A1A, acento primario #E50914 (rojo cinematográfico), acento secundario #00B4D8 (cian info), acento terciario #FFB703 (ámbar recomendaciones).
- Tipografía: Poppins para títulos (SemiBold 600, Bold 700), Inter para cuerpo (Regular 400, Medium 500).
- TODOS los botones deben tener altura mínima de 48dp (ideal 56dp), nunca menos.
- NUNCA usar botones que se compriman o deformen. Usar Wrap() o Expanded() cuando haya múltiples botones en fila.
- Textos siempre con overflow: ellipsis y maxLines definido.
- Tarjetas con borderRadius 16dp, sombra suave, aspect ratio 2:3 para posters.
- BottomNavigationBar con altura 72dp, 4 pestañas, iconos line/outline, label siempre visible.
- SafeArea obligatoria en todas las pantallas con navegación inferior.
- Animaciones: page transitions fade+slide 300ms, card tap scale 0.97, staggered lists.

### FUNCIONALIDAD PRINCIPAL:
1. **Catálogo Personal**: Grid de 2 columnas mostrando películas, series, documentales, anime. Filtros por tipo y género.
2. **Agregar Contenido**: Formulario con título, tipo (dropdown con iconos), géneros (chips multiselect), duración/episodios, estado (Falta Ver, Viendo, Visto, Pausada, Volver a Ver), calificación 1-10, fecha planificada, nota personal, opción de notificación.
3. **Sección "Por Ver"**: Tres tabs - "Falta Ver" (notStarted), "Volver a Ver" (rewatchPending), "Vistos" (completed). Lista vertical con cards horizontales ricas en información.
4. **Recomendaciones**: Toggle Amigos / Sistema / Tendencias. Cards con avatar de amigo, nota personal, botón para marcar como pendiente.
5. **Notificaciones Inteligentes**: flutter_local_notifications con recordatorios de visionado programados, alertas de estreno, sugerencias de rewatch. Acciones rápidas: [Ver ahora] [Posponer] [Descartar].
6. **Perfil y Estadísticas**: Dashboard con gráficos (fl_chart) de contenido por género, tiempo total visto, películas vs series, streak de visionado.

### MODELO DE DATOS:
- Usar Hive o Isar para almacenamiento local offline-first.
- ContentItem: id, title, type (enum), genres (List<String>), durationMinutes, episodes, currentEpisode, status (enum), userRating, personalNote, posterUrl, watchDate, releaseDate, addedAt, source (enum), recommendedBy, recommendedNote, notifyMe, notificationDate, rewatchCount, isFavorite.

### ARQUITECTURA:
- Clean Architecture con BLoC o Riverpod.
- Repositorio local (Hive/Isar) con abstracción de interfaz.
- UseCases para cada operación (agregar, actualizar, filtrar, programar notificación).
- UI layer con widgets reutilizables y atómicos.

### COMPONENTES UI REUTILIZABLES:
- PrimaryButton (filled, full-width o compact, con icono opcional)
- SecondaryButton (outline)
- ContentCard (poster, título, género, badge de estado)
- GenreChip (fully rounded, responsive con Wrap)
- StatusBadge (color según estado: verde=visto, amarillo=pendiente, azul=recomendado, rojo=abandonado)
- RatingStars (1-10, media estrella permitida)
- EmptyState (Lottie animación + mensaje)
- ShimmerCard (loading skeleton)
- CustomBottomSheet (con handle bar, altura 60-90%, borderRadius 20dp arriba)

### RESPONSIVE ANTI-BUG:
- Breakpoints: <360dp (1 columna, botones apilados), 360-600dp (2 columnas, botones fila), >600dp (3-4 columnas, tablet layout).
- Padding mínimo entre elementos: 12dp.
- Grid spacing: 16dp.
- Bottom sheets: altura mínima 60% pantalla.
- TextFields: altura 56dp, filled, borderRadius 12dp.
- Modales: custom Dialog con borderRadius 20dp, NO AlertDialog del sistema.

Genera el código completo: main.dart, theme.dart, modelos, repositorios, BLoCs/Providers, pantallas principales, y widgets reutilizables. Organiza en carpetas feature-based: lib/features/catalog/, lib/features/watchlist/, lib/features/recommendations/, lib/features/profile/, lib/core/, lib/shared/.
```

---

## 13. CHECKLIST DE CALIDAD PRE-ENTREGA

- [ ] Todos los botones miden mínimo 48dp de alto (ideal 56dp)
- [ ] Ningún botón se comprime en pantallas pequeñas (<360dp)
- [ ] Todos los textos truncan con ellipsis, nunca overflow
- [ ] Wrap() usado en lugar de Row() cuando hay chips o botones múltiples
- [ ] SafeArea presente en todas las pantallas con navegación inferior
- [ ] Grid funciona en 1, 2, 3 y 4 columnas según ancho de pantalla
- [ ] Notificaciones se programan y disparan correctamente
- [ ] Datos persisten después de cerrar y reabrir la app
- [ ] Animaciones fluidas a 60fps en dispositivo de gama media
- [ ] Empty states implementados en todas las listas vacías
- [ ] Dark mode nativo (único tema, bien hecho)
- [ ] Sin errores de layout (no yellow/black stripes en debug)
- [ ] Sin botones del sistema (Android/iOS) tapados por UI

---

**Documento versión:** 1.0  
**Autor:** CineLog Pro Spec  
**Última actualización:** 2025
```