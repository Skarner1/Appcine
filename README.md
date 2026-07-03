# 🎬 CineLog Pro

App Flutter para gestión personal de películas, series, documentales y
recomendaciones sociales. Diseño premium oscuro, responsive, offline-first y
con notificaciones inteligentes. Implementada según la especificación en
`lib/docs/CineLog_Pro_Flutter_Spec.md`.

## Funcionalidades

- **Catálogo** — grid responsive (1–4 columnas según ancho), búsqueda por
  título/género, filtros rápidos por tipo, filtro de género en bottom sheet,
  favoritos.
- **Por Ver** — segmented control con *Falta Ver / Volver a Ver / Vistos*,
  tarjetas horizontales con progreso de episodios y fecha programada.
- **Recomendados** — pestañas *Amigos / Sistema / Tendencias*, tarjetas con
  avatar del amigo y su nota, botón "Marcar como Pendiente".
- **Perfil** — estadísticas con gráficos (donut por tipo, barras por género),
  tiempo total visto, racha de visionado, recordatorios programados,
  exportar/importar catálogo en JSON, notificación de prueba.
- **Detalle** — SliverAppBar con póster desenfocado, acciones rápidas
  (Visto / Programar / Compartir / Editar), progreso de episodios con
  stepper, nota expandible, tarjeta de recomendación, historial y contenido
  similar.
- **Agregar/Editar** — formulario completo: tipo con iconos, géneros
  multi-select, duración con slider, episodios, estado, calificación 1–10 con
  media estrella, fecha planificada, recordatorio con fecha/hora, portada
  desde galería o URL.
- **Notificaciones locales** — canal `recordatorios_visionado` (alta
  prioridad), acciones rápidas *Ver ahora / Posponer 1h / Descartar*,
  agrupadas por *Hoy / 7 días / 30 días / Pasadas*. Se reprograman tras
  reiniciar el dispositivo.

## Stack

| Capa | Tecnología |
|---|---|
| Estado | Riverpod 3 (Notifier / StreamProvider) |
| Persistencia | Hive (adapter manual, sin build_runner) |
| Notificaciones | flutter_local_notifications + timezone |
| UI | google_fonts (Poppins/Inter), shimmer, cached_network_image, fl_chart |

## Estructura

```
lib/
├── main.dart                 # Init Hive + notificaciones + seed
├── app.dart                  # MaterialApp + AppShell (bottom nav 72dp)
├── core/
│   ├── theme/                # AppColors (paleta oficial) + AppTheme
│   ├── constants/            # Géneros, breakpoints responsive
│   ├── services/             # NotificationService
│   └── utils/                # Formatters de fechas y duración
├── data/
│   ├── models/               # ContentItem + enums + adapter Hive
│   ├── repositories/         # ContentRepository (offline-first)
│   └── seed_data.dart        # Contenido de ejemplo (primer arranque)
├── providers/                # Providers Riverpod (filtros, stats, acciones)
├── features/
│   ├── catalog/              # Tab 1 — Catálogo
│   ├── watchlist/            # Tab 2 — Por Ver
│   ├── recommendations/      # Tab 3 — Recomendados
│   ├── profile/              # Tab 4 — Perfil + Notificaciones
│   ├── content_form/         # Agregar / Editar
│   └── detail/               # Detalle del contenido
└── shared/widgets/           # PrimaryButton, ContentCard, chips, badges…
```

## Ejecutar

```bash
flutter pub get
flutter run          # dispositivo/emulador Android
flutter test         # tests de modelo/repositorio
```

Notas Android: el proyecto ya tiene configurado *core library desugaring*,
permisos (`POST_NOTIFICATIONS`, `SCHEDULE_EXACT_ALARM`, `RECEIVE_BOOT_COMPLETED`)
y los receivers de `flutter_local_notifications` en el manifest.

En el primer arranque se cargan ~12 títulos de ejemplo para que la app no se
sienta vacía; puedes borrarlos desde el detalle o con *Perfil → Vaciar catálogo*.
