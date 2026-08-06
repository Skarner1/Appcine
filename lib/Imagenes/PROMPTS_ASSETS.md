# Prompts de assets — CineLog Pro

Guía de prompts para generar iconos, botones e ilustraciones con ChatGPT
(generador de imágenes) que peguen con la identidad visual de la app: el icono
de palomitas 3D roja/crema con botón de play sobre negro con glow rojo.

> **Regla de oro:** genera **uno** primero y, para los demás, añade al final
> *"con EXACTAMENTE el mismo estilo, ángulo de cámara, iluminación y acabado que
> la imagen anterior"*. Así todo el set se ve coherente y profesional.

---

## Paleta oficial (copia estos HEX en los prompts)

| Uso | HEX |
|---|---|
| Rojo cinemático (principal) | `#E50914` |
| Degradado rojo | `#FF3B44` → `#C01019` |
| Cyan (info/duración) | `#00B4D8` |
| Ámbar (recomendaciones) | `#FFB703` |
| Verde éxito (visto/completado) | `#2ECC71` |
| Crema / blanco hueso | `#F5F5F5` |
| Fondo negro profundo | `#0F0F0F` |

---

## 🧬 BLOQUE DE ESTILO — pégalo al inicio de CADA prompt

```
Estilo "CineLog Pro": render 3D de plástico brillante, reflejos suaves,
sombras limpias e iluminación de estudio (igual que un icono premium de app).
Paleta EXACTA: rojo cinemático #E50914 con degradado #FF3B44 a #C01019,
detalles crema/blanco hueso #F5F5F5, y toques de cyan #00B4D8 o ámbar #FFB703
solo como acento. Fondo negro profundo #0F0F0F con un glow rojo radial sutil
detrás del objeto. Objeto único centrado, composición 1:1, márgenes amplios,
sin texto, sin letras, sin marcas de agua. Debe combinar con un icono de caja
de palomitas 3D roja y crema con botón de play.
```

---

## 1) Iconos de sección

```
[BLOQUE DE ESTILO] + Icono de "Por ver": una caja de palomitas roja y crema
con un marcador/bookmark 3D asomando en la parte superior.
```
```
[BLOQUE DE ESTILO] + Icono de "Diario de visionado": una claqueta de cine
roja con una marca de verificación verde #2ECC71 en relieve.
```
```
[BLOQUE DE ESTILO] + Icono de "Estadísticas": un gráfico de barras 3D con
las barras en degradado rojo #FF3B44→#C01019 sobre una pequeña tira de película.
```
```
[BLOQUE DE ESTILO] + Icono de "Ruleta": una rueda de casino/fortuna 3D roja
y crema con un pequeño símbolo de play en el centro.
```
```
[BLOQUE DE ESTILO] + Icono de "Colecciones": tres cajas de película apiladas,
rojas y crema, con lomos tipo estuche de cine.
```
```
[BLOQUE DE ESTILO] + Icono de "Libros y manga": un libro 3D rojo junto a un
tomo de manga, con un pequeño marcador de play.
```
```
[BLOQUE DE ESTILO] + Icono de "Recordatorios": una campana de notificación 3D
roja con una mini claqueta colgando.
```
```
[BLOQUE DE ESTILO] + Icono de "Perfil": una butaca de cine roja 3D vista de
frente, acabado tapizado brillante.
```

---

## 2) Ilustraciones de "empty state" (pantallas vacías)

```
[BLOQUE DE ESTILO] + Ilustración amable para pantalla vacía: una caja de
palomitas vacía y volcada con un par de granos alrededor, expresión "aún no
hay nada aquí". Mucho espacio negativo, minimalista.
```
```
[BLOQUE DE ESTILO] + Ilustración de pantalla vacía "sin resultados": una lupa
3D roja sobre una tira de película enrollada, sin encontrar nada.
```

---

## 3) Botones, FAB y estados (pide FONDO TRANSPARENTE)

```
[BLOQUE DE ESTILO] + Botón flotante circular (FAB) rojo con degradado
#FF3B44→#C01019, con un símbolo "+" blanco #F5F5F5 en relieve, acabado glossy,
FONDO TRANSPARENTE (PNG), sin sombra recortada.
```
```
[BLOQUE DE ESTILO] + Botón de play circular 3D rojo brillante con triángulo
blanco, estados normal y presionado, FONDO TRANSPARENTE.
```
```
[BLOQUE DE ESTILO] + Icono de botón "Compartir por QR": un código QR estilizado
dentro de una tarjeta roja glossy, FONDO TRANSPARENTE.
```

---

## 4) Badges / logros (para gamificar Estadísticas)

```
[BLOQUE DE ESTILO] + Medalla/insignia 3D "Maratón": una claqueta dorada con
laureles ámbar #FFB703, estilo trofeo brillante, FONDO TRANSPARENTE.
```

---

## 5) Bonus — Gráfico destacado de Google Play (1024×500)

```
[BLOQUE DE ESTILO PERO en formato horizontal 1024x500] + Banner de portada
para Google Play de una app de cine llamada "CineLog Pro": la caja de
palomitas con play a la izquierda, y a la derecha pósters de película flotando
en 3D con desenfoque, fondo negro #0F0F0F con glow rojo. Deja espacio libre a
la derecha para poner texto después. Sin texto en la imagen.
```

---

## Consejos para que salgan usables

1. **Fondo transparente:** para iconos/botones dentro de la app añade
   *"FONDO TRANSPARENTE (PNG)"*. Si sale con fondo, quítalo en https://remove.bg
2. **Iconos pequeños de barra/botón → mejor SVG que imagen.** Pídele a ChatGPT:
   *"En vez de imagen, genérame el código SVG de este icono en rojo #E50914"*.
   El SVG escala perfecto, pesa poco y se puede tintar. (Requiere el paquete
   `flutter_svg`).
3. **Cuadrado y grande:** pide 1:1 a 1024×1024; luego se exporta a densidades.
4. **Consistencia:** genera todo el set en la misma sesión y repite
   *"mismo estilo que la anterior"*.

---

## Cómo integrarlos en Flutter (referencia rápida)

1. Guardar los PNG en `lib/Imagenes/` (o mejor en `assets/` en la raíz).
2. Declararlos en `pubspec.yaml`:
   ```yaml
   flutter:
     assets:
       - assets/iconos/
   ```
3. Usarlos: `Image.asset('assets/iconos/ruleta.png', width: 32)`.
4. Para SVG: añadir `flutter_svg` y usar `SvgPicture.asset(...)`.

---

## 🔘 Botones con FONDO TRANSPARENTE (reintento)

Los botones (FAB, play, QR) salieron con fondo horneado. Para botones NO se usa
el bloque de estilo con fondo negro (el glow necesita fondo). Usa este bloque de
transparencia y sé MUY explícito.

### 🧬 BLOQUE DE TRANSPARENCIA — pégalo al inicio de cada botón
```
Objeto 3D aislado tipo "sticker troquelado" (die-cut), plástico rojo brillante
(#E50914 con degradado #FF3B44→#C01019) y detalles en blanco hueso #F5F5F5,
reflejos de estudio. FONDO 100% TRANSPARENTE (PNG con canal alfa). SIN fondo,
sin escenario, sin suelo, sin degradado de fondo, sin glow detrás, SIN sombra
proyectada sobre ninguna superficie. Un solo objeto centrado, ocupa ~80% del
lienzo con márgenes iguales, cuadrado 1:1, 1024x1024, sin texto ni marcas.
```

### Los 3 botones
```
[BLOQUE DE TRANSPARENCIA] + Botón circular abombado con un símbolo "+" blanco
hueso en relieve en el centro. Acabado glossy tipo caramelo.
```
```
[BLOQUE DE TRANSPARENCIA] + Botón circular abombado con un triángulo de "play"
blanco hueso en relieve en el centro. Acabado glossy tipo caramelo.
```
```
[BLOQUE DE TRANSPARENCIA] + Ficha redondeada (squircle) roja abombada con un
código QR estilizado en blanco hueso en relieve en el centro.
```

> Si aun así sale con fondo: dile *"el fondo debe ser transparente, exporta PNG
> con alfa, elimina cualquier color de fondo"*, o pásalo por https://remove.bg.
> Para estos botones pequeños, un SVG o el icono vectorial suele verse más
> nítido que un render 3D.
