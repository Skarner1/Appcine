import 'package:flutter/material.dart';

import '../../core/l10n/strings.dart';
import '../../data/models/content_item.dart';
import 'genre_chip.dart';

/// Una opción del carrusel. Con [onTap] a null el chip se ve pero no responde.
class ChipCarouselOption {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback? onTap;

  const ChipCarouselOption({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });
}

/// Fila de chips que se arrastra en horizontal. El mismo comportamiento en toda
/// la app, para lo que sea que se elija de una lista.
///
/// Se arrastra en vez de repartirse o saltar de línea por dos motivos que ya
/// nos mordieron:
///
///  - Repartir el ancho a partes iguales ([Row] de [Expanded]) parece buena
///    idea con tres opciones y corta las etiquetas en cuanto hay cinco:
///    "Pelícu…", "Mang…".
///  - Un [Wrap] con ocho tipos y nombres como "Documentales" se va a cuatro
///    filas con el borde derecho irregular.
///
/// Aquí las etiquetas van siempre enteras y el alto es fijo, salgan las
/// opciones que salgan.
class ChipCarousel extends StatelessWidget {
  final List<ChipCarouselOption> options;
  final EdgeInsetsGeometry padding;

  const ChipCarousel({
    super.key,
    required this.options,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // Fijo: deja sitio al rebote del chip elegido (AnimatedScale) sin que la
      // fila dé un salto de alto al cambiar de selección.
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: padding,
        // Los chips ya tienen su propia animación de escala; el rebote del
        // scroll encima marea.
        physics: const ClampingScrollPhysics(),
        itemCount: options.length,
        itemBuilder: (context, index) {
          final option = options[index];
          return Padding(
            padding: EdgeInsets.only(right: index == options.length - 1 ? 0 : 8),
            child: Center(
              child: GenreChip(
                label: option.label,
                icon: option.icon,
                selected: option.selected,
                onTap: option.onTap,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// [ChipCarousel] para elegir tipo de contenido: el caso de siempre (catálogo,
/// búsqueda online y ruleta).
class ContentTypeCarousel extends StatelessWidget {
  /// Tipos a mostrar, en orden.
  final List<ContentType> types;

  /// Tipo activo. Null es "Todo" cuando [includeAll] está puesto.
  final ContentType? selected;

  /// Recibe el tipo elegido, o null si se pulsó "Todo".
  final ValueChanged<ContentType?> onSelect;

  /// Añade "Todo" al principio para quitar el filtro.
  final bool includeAll;

  /// En false los chips se ven pero no responden (la ruleta los apaga mientras
  /// gira).
  final bool enabled;

  final EdgeInsetsGeometry padding;

  const ContentTypeCarousel({
    super.key,
    required this.types,
    required this.selected,
    required this.onSelect,
    this.includeAll = false,
    this.enabled = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
  });

  @override
  Widget build(BuildContext context) {
    return ChipCarousel(
      padding: padding,
      options: [
        if (includeAll)
          ChipCarouselOption(
            label: tr('type.all'),
            selected: selected == null,
            onTap: enabled ? () => onSelect(null) : null,
          ),
        for (final type in types)
          ChipCarouselOption(
            label: type.pluralLabel,
            icon: type.icon,
            selected: selected == type,
            // Volver a pulsar el activo lo quita, si hay a dónde volver.
            onTap: enabled
                ? () => onSelect((includeAll && selected == type) ? null : type)
                : null,
          ),
      ],
    );
  }
}
