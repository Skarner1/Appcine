import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Colección personalizada: una lista con nombre (p. ej. "Halloween",
/// "Para ver en pareja") que agrupa ids de contenido del catálogo.
///
/// Se guarda como JSON en el box de ajustes de Hive, así que no necesita
/// TypeAdapter propio.
class Collection {
  final String id; // UUID v4
  final String name;

  /// Color de acento (valor ARGB). Ver [Collection.palette].
  final int color;

  /// Ids de [ContentItem] que pertenecen a la colección, en orden de adición.
  final List<String> itemIds;

  final DateTime createdAt;

  const Collection({
    required this.id,
    required this.name,
    required this.color,
    this.itemIds = const [],
    required this.createdAt,
  });

  /// Paleta de colores sugeridos al crear una colección.
  static const List<Color> palette = [
    AppColors.primary,
    AppColors.secondary,
    AppColors.tertiary,
    AppColors.success,
    AppColors.info,
    Color(0xFF9B5DE5), // violeta
    Color(0xFFF15BB5), // rosa
  ];

  Color get accent => Color(color);

  bool contains(String itemId) => itemIds.contains(itemId);

  Collection copyWith({
    String? name,
    int? color,
    List<String>? itemIds,
  }) {
    return Collection(
      id: id,
      name: name ?? this.name,
      color: color ?? this.color,
      itemIds: itemIds ?? this.itemIds,
      createdAt: createdAt,
    );
  }

  /// Devuelve una copia con [itemId] añadido (al final) o quitado.
  Collection toggle(String itemId) {
    final ids = List<String>.of(itemIds);
    if (!ids.remove(itemId)) ids.add(itemId);
    return copyWith(itemIds: ids);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'color': color,
        'itemIds': itemIds,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Collection.fromJson(Map<String, dynamic> json) {
    return Collection(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Sin nombre',
      color: (json['color'] as num?)?.toInt() ?? AppColors.primary.toARGB32(),
      itemIds: (json['itemIds'] as List?)?.cast<String>() ?? const [],
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
              DateTime.now(),
    );
  }
}
