// The Vale map, drawn in code on a 400 × 500 grid.
//
// A stand-in for the illustrated map (see ASSETS.md): original shapes, laid
// out by hand. Every layer belongs to a region (by index into `regions`) or
// to the Vale as a whole (-1), so each region can wake by itself.

import 'dart:ui' show Color, Offset;

const double mapWidth = 400;
const double mapHeight = 500;

class MapLayer {
  const MapLayer(this.d, this.color, this.region, [this.stroke = 0]);

  /// SVG path data.
  final String d;
  final Color color;

  /// Index into `regions`, or -1 for the whole Vale.
  final int region;

  /// Stroke width; 0 means a filled shape.
  final double stroke;
}

const List<MapLayer> mapLayers = <MapLayer>[
  MapLayer('M0 0 H400 V500 H0 Z', Color(0xFF4E8C63), -1),
  MapLayer('M0 300 C80 270 160 290 240 330 C300 360 360 350 400 330 V500 H0 Z', Color(0xFF467F5B), -1),
  MapLayer('M120 250 C200 235 300 250 400 240 V330 C340 350 280 355 230 330 C170 300 140 280 120 250 Z', Color(0xFF5C9A68), -1),
  MapLayer('M0 0 H228 C236 60 206 120 218 172 C160 214 70 220 0 206 Z', Color(0xFF73879E), 3),
  MapLayer('M0 150 C40 132 95 150 135 140 C170 132 200 150 218 172 C160 214 70 220 0 206 Z', Color(0xFF6C8F86), 3),
  MapLayer('M125 22 L72 150 L127 150 Z', Color(0xFFA3B5C7), 3),
  MapLayer('M125 22 L127 150 L188 150 Z', Color(0xFF62768F), 3),
  MapLayer('M125 22 L108.872 60.4 L118.856 54.256 L125 63.472 L132.68 52.72 L142.664 60.4 Z', Color(0xFFF2F6F7), 3),
  MapLayer('M58 40 L8 152 L60 152 Z', Color(0xFFA3B5C7), 3),
  MapLayer('M58 40 L60 152 L116 152 Z', Color(0xFF62768F), 3),
  MapLayer('M58 40 L43.888 73.6 L52.624 68.224 L58 76.288 L64.72 66.88 L73.456 73.6 Z', Color(0xFFF2F6F7), 3),
  MapLayer('M172 74 L134 160 L174 160 Z', Color(0xFFA3B5C7), 3),
  MapLayer('M172 74 L174 160 L212 160 Z', Color(0xFF62768F), 3),
  MapLayer('M172 74 L161.164 99.8 L167.872 95.672 L172 101.864 L177.16 94.64 L183.868 99.8 Z', Color(0xFFF2F6F7), 3),
  MapLayer('M26 96 L-6 172 L28 172 Z', Color(0xFFA3B5C7), 3),
  MapLayer('M26 96 L28 172 L66 172 Z', Color(0xFF62768F), 3),
  MapLayer('M26 96 L16.424 118.8 L22.352 115.152 L26 120.624 L30.56 114.24 L36.488 118.8 Z', Color(0xFFF2F6F7), 3),
  MapLayer('M98 92 L68 162 L100 162 Z', Color(0xFFA3B5C7), 3),
  MapLayer('M98 92 L100 162 L134 162 Z', Color(0xFF62768F), 3),
  MapLayer('M228 0 H400 V172 C340 188 270 184 218 172 C206 120 236 60 228 0 Z', Color(0xFFB49C74), 4),
  MapLayer('M250 44 C290 22 362 26 388 62 C396 104 352 140 300 144 C254 142 238 104 250 44 Z', Color(0xFFD3BF97), 4),
  MapLayer('M262 120 C300 100 350 104 384 124 C360 150 300 156 262 120 Z', Color(0xFFC4AF86), 4),
  MapLayer('M256 60 H263 V96 H256 Z', Color(0xFFEFE3C5), 4),
  MapLayer('M261 60 H263 V96 H261 Z', Color(0xFFC9B88F), 4),
  MapLayer('M254 93 H265 V96 H254 Z', Color(0xFFE0D2AE), 4),
  MapLayer('M272 72 H279 V98 H272 Z', Color(0xFFEFE3C5), 4),
  MapLayer('M277 72 H279 V98 H277 Z', Color(0xFFC9B88F), 4),
  MapLayer('M270 95 H281 V98 H270 Z', Color(0xFFE0D2AE), 4),
  MapLayer('M382 84 H389 V118 H382 Z', Color(0xFFEFE3C5), 4),
  MapLayer('M387 84 H389 V118 H387 Z', Color(0xFFC9B88F), 4),
  MapLayer('M380 115 H391 V118 H380 Z', Color(0xFFE0D2AE), 4),
  MapLayer('M286 62 V34 A15 15 0 0 1 316 34 V62 H308 V36 A7 7 0 0 0 294 36 V62 Z', Color(0xFFEFE3C5), 4),
  MapLayer('M308 36 A7 7 0 0 0 301 29 A12 12 0 0 1 316 34 V62 H308 Z', Color(0xFFC9B88F), 4),
  MapLayer('M240 132 H262 V140 H240 Z', Color(0xFFE0D2AE), 4),
  MapLayer('M246 124 H256 V132 H246 Z', Color(0xFFEFE3C5), 4),
  MapLayer('M-10 233 C60 222 110 252 172 240 C232 228 252 200 312 205 C352 208 382 194 410 188', Color(0xFF7DB79B), 2, 54),
  MapLayer('M-10 233 C60 222 110 252 172 240 C232 228 252 200 312 205 C352 208 382 194 410 188', Color(0xFF3F8FB8), 2, 22),
  MapLayer('M-10 229 C60 218 110 248 172 236 C232 224 252 196 312 201 C352 204 382 190 410 184', Color(0xFF8CC8E0), 2, 3),
  MapLayer('M20 238 C50 236 70 242 96 246 M190 240 C214 234 232 222 250 214 M330 208 C350 207 366 203 384 198', Color(0xFFBFE3EF), 2, 1.6),
  MapLayer('M196 344 C214 292 282 286 304 344 Z', Color(0xFF8CC474), 1),
  MapLayer('M276 330 C298 272 372 272 396 330 Z', Color(0xFF77B263), 1),
  MapLayer('M318 388 C336 340 388 336 404 366 V388 Z', Color(0xFF96CC7D), 1),
  MapLayer('M222 396 C242 350 300 348 322 396 Z', Color(0xFF6CA75C), 1),
  MapLayer('M214 326 C228 304 262 300 282 318', Color(0xFFB6DC98), 1, 2),
  MapLayer('M292 314 C310 288 352 286 374 308', Color(0xFFA3D086), 1, 2),
  MapLayer('M240 380 C254 362 288 360 304 378', Color(0xFF93C57C), 1, 2),
  MapLayer('M14 398 C60 364 150 364 206 400 C218 442 192 482 140 494 C80 502 24 482 8 440 Z', Color(0xFF9ACB76), 0),
  MapLayer('M24 446 L62 434 L72 458 L34 470 Z', Color(0xFFC8D886), 0),
  MapLayer('M150 452 L188 444 L194 466 L156 474 Z', Color(0xFFB9D27C), 0),
  MapLayer('M30 452 L66 441 M34 460 L69 449', Color(0xFFA9C26C), 0, 1.4),
  MapLayer('M154 459 L190 451 M157 467 L192 459', Color(0xFFA1BC66), 0, 1.4),
  MapLayer('M84 404 H100 V413 H84 Z', Color(0xFFF3E6C8), 0),
  MapLayer('M82 404 L92 396 L102 404 Z', Color(0xFFC5653C), 0),
  MapLayer('M112 394 H128 V403 H112 Z', Color(0xFFF3E6C8), 0),
  MapLayer('M110 394 L120 386 L130 394 Z', Color(0xFFB5543A), 0),
  MapLayer('M134 410 H150 V419 H134 Z', Color(0xFFF3E6C8), 0),
  MapLayer('M132 410 L142 402 L152 410 Z', Color(0xFFD08A3E), 0),
  MapLayer('M96 450 H112 V459 H96 Z', Color(0xFFF3E6C8), 0),
  MapLayer('M94 450 L104 442 L114 450 Z', Color(0xFFB5543A), 0),
  MapLayer('M122 458 H138 V467 H122 Z', Color(0xFFF3E6C8), 0),
  MapLayer('M120 458 L130 450 L140 458 Z', Color(0xFFC5653C), 0),
  MapLayer('M160 420 H176 V429 H160 Z', Color(0xFFF3E6C8), 0),
  MapLayer('M158 420 L168 412 L178 420 Z', Color(0xFFC5653C), 0),
  MapLayer('M323 430 A9 9 0 1 1 341 430 A9 9 0 1 1 323 430 Z', Color(0xFF2F6B50), -1),
  MapLayer('M340 440 A10 10 0 1 1 360 440 A10 10 0 1 1 340 440 Z', Color(0xFF3B7C60), -1),
  MapLayer('M359 426 A9 9 0 1 1 377 426 A9 9 0 1 1 359 426 Z', Color(0xFF2F6B50), -1),
  MapLayer('M374 444 A10 10 0 1 1 394 444 A10 10 0 1 1 374 444 Z', Color(0xFF346F54), -1),
  MapLayer('M330 460 A10 10 0 1 1 350 460 A10 10 0 1 1 330 460 Z', Color(0xFF346F54), -1),
  MapLayer('M351 468 A11 11 0 1 1 373 468 A11 11 0 1 1 351 468 Z', Color(0xFF2F6B50), -1),
  MapLayer('M375 472 A9 9 0 1 1 393 472 A9 9 0 1 1 375 472 Z', Color(0xFF3B7C60), -1),
  MapLayer('M314 474 A8 8 0 1 1 330 474 A8 8 0 1 1 314 474 Z', Color(0xFF3B7C60), -1),
  MapLayer('M292 452 A8 8 0 1 1 308 452 A8 8 0 1 1 292 452 Z', Color(0xFF2F6B50), -1),
  MapLayer('M273 470 A9 9 0 1 1 291 470 A9 9 0 1 1 273 470 Z', Color(0xFF346F54), -1),
  MapLayer('M253 456 A7 7 0 1 1 267 456 A7 7 0 1 1 253 456 Z', Color(0xFF3B7C60), -1),
  MapLayer('M235 478 A9 9 0 1 1 253 478 A9 9 0 1 1 235 478 Z', Color(0xFF2F6B50), -1),
  MapLayer('M5 286 A9 9 0 1 1 23 286 A9 9 0 1 1 5 286 Z', Color(0xFF2F6B50), -1),
  MapLayer('M20 300 A10 10 0 1 1 40 300 A10 10 0 1 1 20 300 Z', Color(0xFF3B7C60), -1),
  MapLayer('M3 318 A9 9 0 1 1 21 318 A9 9 0 1 1 3 318 Z', Color(0xFF346F54), -1),
  MapLayer('M32 326 A8 8 0 1 1 48 326 A8 8 0 1 1 32 326 Z', Color(0xFF2F6B50), -1),
  MapLayer('M53 298 A7 7 0 1 1 67 298 A7 7 0 1 1 53 298 Z', Color(0xFF346F54), -1),
  MapLayer('M14 344 A8 8 0 1 1 30 344 A8 8 0 1 1 14 344 Z', Color(0xFF3B7C60), -1),
  MapLayer('M143 300 A7 7 0 1 1 157 300 A7 7 0 1 1 143 300 Z', Color(0xFF346F54), -1),
  MapLayer('M158 312 A8 8 0 1 1 174 312 A8 8 0 1 1 158 312 Z', Color(0xFF2F6B50), -1),
  MapLayer('M131 318 A7 7 0 1 1 145 318 A7 7 0 1 1 131 318 Z', Color(0xFF3B7C60), -1),
  MapLayer('M382 250 A8 8 0 1 1 398 250 A8 8 0 1 1 382 250 Z', Color(0xFF346F54), -1),
  MapLayer('M369 262 A7 7 0 1 1 383 262 A7 7 0 1 1 369 262 Z', Color(0xFF2F6B50), -1),
];

/// The road: one segment per region, 40 Paces each.
const List<String> roadSegments = <String>[
  'M36 494 C66 474 58 444 98 434 C138 424 150 402 192 392',
  'M192 392 C234 382 250 354 290 352 C336 350 362 322 336 296 C318 278 292 282 268 270',
  'M268 270 C255 258 247 246 238 232 C230 220 226 212 210 208 C176 200 136 214 100 204',
  'M100 204 C80 196 70 180 84 166 C100 150 120 162 140 152 C166 140 180 150 200 128 C208 118 210 108 224 100',
  'M224 100 C246 88 256 110 280 112 C306 114 312 90 336 86 C350 84 358 78 366 66',
];

/// Where each drafted place sits, in waking order.
const List<Offset> placeSpots = <Offset>[
  Offset(54, 458),
  Offset(82, 424),
  Offset(128, 444),
  Offset(166, 408),
  Offset(226, 366),
  Offset(274, 334),
  Offset(352, 300),
  Offset(306, 300),
  Offset(252, 244),
  Offset(214, 190),
  Offset(162, 222),
  Offset(118, 186),
  Offset(64, 182),
  Offset(112, 142),
  Offset(160, 164),
  Offset(190, 108),
  Offset(246, 112),
  Offset(288, 92),
  Offset(330, 104),
  Offset(356, 48),
];

class MapLabel {
  const MapLabel(this.region, this.at);
  final int region;
  final Offset at;
}

const List<MapLabel> mapLabels = <MapLabel>[
  MapLabel(0, Offset(96, 486)),
  MapLabel(1, Offset(330, 400)),
  MapLabel(2, Offset(86, 262)),
  MapLabel(3, Offset(86, 18)),
  MapLabel(4, Offset(318, 160)),
];

class FogBank {
  const FogBank(this.centre, this.rx, this.ry);
  final Offset centre;
  final double rx;
  final double ry;
}

/// Fog over each sleeping region, by region index.
const List<List<FogBank>> mapFog = <List<FogBank>>[
  <FogBank>[
    FogBank(Offset(70, 420), 70, 36),
    FogBank(Offset(150, 450), 66, 34),
    FogBank(Offset(110, 480), 80, 26),
  ],
  <FogBank>[
    FogBank(Offset(250, 330), 66, 34),
    FogBank(Offset(340, 310), 64, 36),
    FogBank(Offset(300, 380), 80, 30),
  ],
  <FogBank>[
    FogBank(Offset(60, 236), 70, 28),
    FogBank(Offset(190, 232), 76, 30),
    FogBank(Offset(330, 204), 78, 28),
  ],
  <FogBank>[
    FogBank(Offset(60, 80), 70, 44),
    FogBank(Offset(150, 70), 72, 46),
    FogBank(Offset(100, 160), 96, 36),
  ],
  <FogBank>[
    FogBank(Offset(280, 60), 66, 40),
    FogBank(Offset(350, 90), 60, 44),
    FogBank(Offset(300, 140), 84, 30),
  ],
];
