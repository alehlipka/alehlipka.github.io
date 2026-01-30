---
title: KTX 2.0 / Basis Universal текстуры — Руководство для разработчиков
description: Перевод поста Khronos Group "KTX 2.0 / Basis Universal Textures — Developer Guide"
date: 2026-01-30 11:11:11 +0300
author: me
categories: [Переводы, Khronos Group]
tags: [перевод, khronos, ktx, opengl]
image: /assets/img/ktx.png
---

**Пост не является авторским и/или официальным**  
**Ссылка на оригинал:** [KTX 2.0 / Basis Universal Textures — Developer Guide](https://github.com/KhronosGroup/3D-Formats-Guidelines/blob/main/KTXDeveloperGuide.md)  
**Автор оригинала:** [Khronos Group](https://github.com/KhronosGroup)  

## Формат Контейнера KTX

При реализации поддержки сжатых текстур разработчикам следует различать три концептуальных формата:

1. **Формат контейнера:** Пояснительная обёртка вокруг данных формата передачи. Описывает размеры изображения, типы сжатия и способ доступа к данным и их транскодирования в пиксельный формат, поддерживаемый GPU. Без формата контейнера сжатые данные нельзя корректно переносить между приложениями.
  - _Примеры: KTX 2.0_
2. **Формат передачи:** Сильно сжатое представление пиксельных данных в разметке, рассчитанной на эффективное транскодирование в один или несколько форматов сжатия GPU.
  - _Примеры: ETC1S и UASTC_
3. **Сжатый пиксельный формат GPU:** Сжатое представление пиксельных данных, которое понимает GPU.
  - _Примеры: BCn, ASTC, ETC и PVRTC1_

Портативные 3D-модели [glTF 2.0](https://github.com/KhronosGroup/glTF) могут использовать сжатые текстуры, хранящиеся в [формате контейнера KTX 2.0](https://github.khronos.org/KTX-Specification/) (`.ktx2`), как описано в расширении glTF [`KHR_texture_basisu`](https://github.com/KhronosGroup/glTF/tree/master/extensions/2.0/Khronos/KHR_texture_basisu). KTX 2.0 — относительно простой бинарный формат; его можно читать и записывать без готовых библиотек, ориентируясь на спецификацию. Доступны несколько реализаций:

- [KTX-Software](https://github.com/KhronosGroup/KTX-Software/): Официальные библиотеки C/C++ для чтения, записи и транскодирования KTX-файлов, с опциональной поддержкой создания текстур в различных графических API. Включает [готовые бинарные пакеты](https://github.com/KhronosGroup/KTX-Software/releases) и сборки WebAssembly.
- [Basis Universal](https://github.com/BinomialLLC/basis_universal/): Библиотеки Binomial на C/C++ для записи и транскодирования KTX-файлов с текстурами формата BasisU. Включает сборки WebAssembly.
- [KTX-Parse](https://github.com/donmccurdy/KTX-Parse): Легковесная JavaScript/TypeScript/Node.js библиотека для чтения и записи KTX-файлов. Транскодирование в сжатый формат GPU нужно реализовывать отдельно<sup>1</sup>.

<small><sub><sup>1</sup> Транскодеры из форматов передачи Basis Universal в форматы сжатия GPU входят в [KTX-Software](https://github.com/KhronosGroup/KTX-Software/) и доступны отдельно в [транскодерах Binomial C/C++/WASM](https://github.com/BinomialLLC/basis_universal/) и [транскодерах Khronos Group WASM](https://github.com/KhronosGroup/Basis-Universal-Transcoders).
</sub></small>

## Блочное сжатие

Для поддержки произвольного доступа сжатые текстуры обычно организуют в блоки одного размера. Basis Universal всегда использует блоки 4x4 пикселя.

Для вычисления количества блоков для заданной текстуры (например, для оценки необходимого объема памяти GPU) приложениям следует использовать следующие выражения:

```
WIDTH_IN_BLOCKS = (WIDTH_IN_PIXELS + 3) >> 2;
HEIGHT_IN_BLOCKS = (HEIGHT_IN_PIXELS + 3) >> 2;

BLOCK_COUNT = WIDTH_IN_BLOCKS * HEIGHT_IN_BLOCKS;
```

Приложения должны ожидать, что размеры базового уровня mip будут равны 1, 2 или кратны 4. Входные данные, не соответствующие этому ограничению, являются недействительными и должны быть отклонены.

Размеры следующих уровней mip определяются по стандартному правилу целочисленного деления на 2. Например:

| Уровень Mip | Ширина x Высота, px | Ширина x Высота, блоки |
|:-:|-:|-:|
| 0 | 100 x 200 | 25 x 50 |
| 1 | 50 x 100 | 13 x 25 |
| 2 | 25 x 50 | 7 x 13 |
| 3 | 12 x 25 | 3 x 7 |
| 4 | 6 x 12 | 2 x 3 |
| 5 | 3 x 6 | 1 x 2 |
| 6 | 1 x 3 | 1 x 1 |
| 7 | 1 x 1 | 1 x 1 |

Здесь базовый уровень mip полностью заполняет сжатые блоки размером `25 x 50`. У следующих уровней часть пикселей в блоках остаётся заполненной дополнением (padding). Это дополнение (если оно присутствует) не влияет на обертывание текстурных координат и недоступно при сэмплинге.

Некоторые старые платформы (например, WebGL 1.0) могут требовать, чтобы все текстуры имели размеры, кратные степени двойки. В таком случае приложениям не остается ничего другого, кроме как распаковывать и масштабировать текстуры, размеры которых не являются кратными степени двойки, тем самым теряя все преимущества сжатия текстур на GPU.

## Кодек ETC1S / BasisLZ

### Обзор

ETC1S / BasisLZ — это гибридная схема сжатия, в которой данные текстурных блоков ETC1S переупорядочиваются и сжимаются без потерь в стиле LZ. Высокая эффективность хранения / передачи достигается за счёт приоритета информации о яркости. Таким образом, этот кодек лучше подходит для цветовых текстур (альбедо, базовый цвет и т.п.), чем для произвольных нецветовых данных, таких как карты нормалей.

После декодирования LZ-сжатия данные ETC1S можно без потерь переупаковать в обычные текстурные блоки ETC1 или транскодировать в другие блочно-сжатые форматы GPU.

### Формат данных

ETC1S представляет собой подмножество ETC1, поэтому сжатые данные всегда имеют три цветовых канала. Для поддержки сценариев использования, отличных от непрозрачных цветовых текстур, сжатые данные могут содержать дополнительный "срез" (slice) ETC1S.

Дескриптор формата данных ETC1S в контейнерном формате KTX v2 может содержать одну или две записи `channelType`.

Поддерживаемые конфигурации включают:

| Каналы | Первый срез | Второй срез | Типичное применение |
|-|-|-|-|
| RGB | `KHR_DF_CHANNEL_ETC1S_RGB` | Отсутствует | Непрозрачная цветовая текстура |
| RGBA | `KHR_DF_CHANNEL_ETC1S_RGB` | `KHR_DF_CHANNEL_ETC1S_AAA` | Цветовая текстура с альфа-каналом |
| Red | `KHR_DF_CHANNEL_ETC1S_RRR` | Отсутствует | Одноканальная текстура |
| Red-Green | `KHR_DF_CHANNEL_ETC1S_RRR` | `KHR_DF_CHANNEL_ETC1S_GGG` | Двухканальная текстура |

### Использование в рантайме

Использование данных ETC1S / BasisLZ включает в себя три шага:

1. Инициализация транскодера общими для всех срезов текстуры данными (грани, элементы массива, уровни mip и т.д.).
  > **Примечание.** В контейнере KTX v2 такие данные хранятся в блоке `supercompressionGlobalData`. Подробнее: разделы [BasisLZ Global Data](https://github.khronos.org/KTX-Specification/#basislz_gd) и [BasisLZ Bitstream Specification](https://github.khronos.org/KTX-Specification/#basisLZ).

2. Вызов декодера с данными по каждому срезу и нужным целевым форматом текстуры. Приложения должны выбирать целевой формат в зависимости от возможностей платформы и предполагаемого использования.

3. Загрузка транскодированных данных в GPU.

  Когда в текстурных данных используется нелинейное кодирование sRGB (практически все цветные текстуры используют его), приложениям следует использовать аппаратный sRGB-декодер для достижения корректной фильтрации. Это может быть легко достигнуто загрузкой сжатых данных с соответствующим значением формата текстуры (см. ниже).

  > **Примечание.** Одноканальные (Red) и двухканальные (Red-Green) текстуры не поддерживают sRGB-кодирование.

### Выбор цели транскодирования (RGB и RGBA)

- По замыслу ETC1S — это строгое подмножество ETC1, поэтому всегда предпочтительно транскодировать его в форматы ETC. Текстуры с одним срезом — в [ETC1 RGB](#etc1-rgb), с двумя срезами — в [ETC2 RGBA](#etc2-rgba).
  > **Примечание.** ETC1 RGB является строгим подмножеством ETC2 RGB.

  > **Примечание.** На платформах, которые поддерживают только ETC1 каждый срез ETC1S можно транскодировать в отдельную текстуру ETC1 и использовать два сэмплера одновременно.

- На десктопных GPU без поддержки ETC следует выполнять транскодирование в [BC7](#bc7).
  > **Примечание.** BC7 всегда поддерживает альфа-канал. Для непрозрачных (single-slice) входных данных ETC1S эталонный транскодер выдаёт блоки BC7 со значениями альфа-канала, установленными в `255`.

- На старых десктопах без поддержки BC7, RGB текстуры (single-slice) должны быть транскодированы в [BC1](#bc1-s3tc-rgb), а текстуры RGBA (dual-slice) — в [BC3](#bc3-s3tc-rgba).

- Транскодирование в [PVRTC1](#pvrtc1-1) также поддерживается, но его стоит использовать только при отсутствии других вариантов.
  > **Примечание.** Транскодирование в PVRTC1 возможно только для текстур с размерами, кратными степени двойки.

  > **Примечание.** Платформы Apple могут не принимать неквадратные текстуры PVRTC1.

- Если платформа не поддерживает ни один из перечисленных форматов, данные ETC1S можно декодировать в [несжатый RGBA](#несжатые-форматы).

![ETC1S Target Format Selection Flowchart](/assets/img/ktx-basisu-dev-guide/ETC1S_targets.png)

### Выбор цели транскодирования (Red)

- Как и в случае с данными RGB, [ETC1 RGB](#etc1-rgb) является наиболее предпочтительным вариантом, поскольку обеспечивает транскодирование без потерь.
  > **Примечание.** При сэмплинге зеленый и синий каналы будут иметь то же значение, что и красный.

  > **Примечание.** [EAC R11](#eac-r11) можно использовать, когда семантически неиспользуемые каналы (Green и Blue) должны возвращать нули, а сведение каналов (swizzling) не поддерживается.

- На десктопных GPU без поддержки ETC1 следует выполнять транскодирование в [BC4](#bc4).
  > **Примечание.** При сэмплинге зеленый и синий каналы будут нулевыми.

- На очень старых десктопах без поддержки BC4 следует выполнять транскодирование в [BC1](#bc1-s3tc-rgb).
  > **Примечание.** При сэмплинге синий канал будет иметь тоже значение, что и красным. Зеленый канал будет немного отличаться, поскольку BC1 использует для него больше битов квантования.

- Транскодирование в [PVRTC1](#pvrtc1-1) должно быть использовано только при отсутствии других вариантов.
  > **Примечание.** Транскодирование в PVRTC1 поддерживается только для текстур с размерами, кратными степени двойки.

  > **Примечание.** Платформы Apple могут не принимать неквадратные текстуры PVRTC1.

  > **Примечание.** При сэмплинге зеленый и синий каналы будут иметь то же значение, что и красный.

- В крайнем случае данные ETC1S можно декодировать в несжатые пиксели [R8](#r8) или [RGBA8](#rgba8).

![ETC1S Target Format Selection Flowchart](/assets/img/ktx-basisu-dev-guide/ETC1S_targets_red.png)

### Выбор цели транскодирования (Red-Green)

- У текстур ETC1S Red-Green два независимо закодированных среза, поэтому предпочтительно использовать [EAC RG11](#eac-rg11).
  > **Примечание.** При сэмплинге канал синего будет нулевым.

  > **Примечание.** На платформах, которые поддерживают только ETC1 RGB каждый срез ETC1S можно транскодировать в отдельную текстуру ETC1 RGB и использовать два сэмплера одновременно.

- На десктопных GPU без поддержки EAC RG11 оба среза транскодируют в одну текстуру [BC5](#bc5).
  > **Примечание.** При сэмплинге синий канал будет нулевым.

- В крайнем случае данные ETC1S можно декодировать в несжатые [RG8](#rg8) или [RGBA8](#rgba8).

![ETC1S Target Format Selection Flowchart](/assets/img/ktx-basisu-dev-guide/ETC1S_targets_red_green.png)

## Кодек UASTC

### Обзор

UASTC — это виртуальный формат текстур с блочным сжатием, разработанный для быстрого и эффективного транскодирования (преобразования) в аппаратно поддерживаемые блочно-сжатые форматы GPU. Созданный на основе передовых методов сжатия текстур ASTC и BC7, он может обрабатывать все виды 8-битных текстурных данных: цветовых карт, карт нормалей, карт высот и т.д. Применение RDO (оптимизация скорости и искажения) во время кодирования позволяет оптимизировать выходные данные UASTC для последующего сжатия без потерь в стиле LZ, что обеспечивает более эффективную передачу и хранение. Контейнер формата KTX v2 использует Zstandard для сжатия без потерь.

### Формат данных

Блоки UASTC внутри могут иметь от 2 до 4 каналов цвета. Кодировщик выбирает различные режимы блоков в зависимости от содержимого текстуры. Во всех случаях используется только один "срез" (slice) данных UASTC.

Дескриптор формата данных UASTC в контейнере формата KTX v2 содержит одну запись `channelType`.

Поддерживаемые конфигурации включают:

| Каналы | `channelType` | Типичное применение |
|-|-|-|
| RGB | `KHR_DF_CHANNEL_UASTC_RGB` | Непрозрачная цветовая текстура |
| RGBA | `KHR_DF_CHANNEL_UASTC_RGBA` | Цветовая текстура с альфа-каналом |
| Red | `KHR_DF_CHANNEL_UASTC_RRR` | Одноканальная текстура |
| Red-Green | `KHR_DF_CHANNEL_UASTC_RG` | Двухканальная текстура |

### Использование в рантайме

Текстуры UASTC состоят из блоков 4x4, каждый блок занимает ровно 16 байт. Сжатие Zstandard (если оно присутствует) следует декодировать до транскодирования текстуры.

Поскольку UASTC — "виртуальный" формат, перед загрузкой в GPU его нужно преобразовать в один из аппаратно поддерживаемых форматов. Приложения должны выбирать целевой формат опираясь на возможности платформы и сценарий использования.

Когда в текстурных данных используется нелинейное кодирование sRGB (практически все цветные текстуры используют его), приложениям следует использовать аппаратные декодеры sRGB для корректной фильтрации. Это может быть легко достигнуто загрузкой сжатых данных с соответствующим значением формата текстуры (см. ниже).

### Основные цели транскодирования

По замыслу UASTC оптимизирован для быстрого и предсказуемого транскодирования в ASTC и BC7. Транскодирование в ASTC всегда осуществляется без потерь (результат совпадает с декодированием в RGBA8), транскодирование в BC7 — практически без потерь.

[ASTC 4x4](#astc-4x4) следует выбирать по умолчанию, при наличии поддержки ASTC LDR.

> **Примечание.** На момент написания ASTC LDR поддерживают, в частности:
> * Apple A8 и новее, Apple M1
> * Arm Mali-T620 и новее
> * ImgTec PowerVR Series6 и новее
> * Intel Gen9 («Skylake») и новее
> * NVIDIA Tegra
> * Qualcomm Adreno 3xx и новее

[BC7](#bc7) следует выбирать когда BC7 поддерживается, а ASTC — нет. К таким платформам относится большинство десктопных GPU.

Если нужен результат высокого качества (например, для карт нормалей или других нецветовых карт), но ни ASTC, ни BC7 недоступны, данные UASTC следует декодировать в несжатый [RGBA8](#rgba8).
> **Примечание.** Даже для заведомо непрозрачной текстуры обычно лучше загружать её как RGBA8, а не RGB8, из-за выравнивания памяти GPU.

Помимо текстур типов RGB и RGBA, кодек UASTC подходит для текстур Red и Red-Green, поскольку он обеспечивает качество выше, чем у ETC1S. ASTC и BC7 по-прежнему остаются основными целевыми форматами для транскодирования, а несжатые форматы [R8](#r8) и [RG8](#rg8) являются высококачественными резервными вариантами.

> **Примечание.** Даже для UASTC текстур типа Red или Red-Green после транскодирования неиспользуемые каналы могут содержать ненулевые значения. Приложениям следует сэмплировать только из используемых каналов.

### Дополнительные цели транскодирования (RGB и RGBA)

Хотя транскодирование в следующие форматы может привести к потере качества, иногда это может быть лучшим вариантом, чем декодирование в несжатый формат, учитывая уменьшение объема памяти графического процессора. Обычно потеря данных для текстур, содержащих информацию о цвете, является приемлемой.

![UASTC RGBA Target Format Selection Flowchart](/assets/img/ktx-basisu-dev-guide/UASTC_targets.png)

#### ETC

Транскодирование UASTC в ETC включает декодирование текстуры в несжатые пиксели и их перекодирование в ETC. Этот процесс полностью реализован эталонным транскодером и частично укорен за счет специфических ETC подсказок (hints), присутствующих в данных UASTC.

Непрозрачные UASTC текстуры должны быть транскодированы и загружены как [ETC1 RGB](#etc1-rgb).

UASTC текстуры с альфа-каналом следует транскодировать и загружать как [ETC2 RGBA](#etc2-rgba).

#### S3TC (BC1 / BC3)

Транскодирование UASTC в формат S3TC (также известный как DXT) включает декодирование текстуры в несжатые пиксели и их перекодирование в [BC1](#bc1-s3tc-rgb) или [BC3](#bc3-s3tc-rgba). Этот процесс полностью реализован эталонным транскодером. Транскодирование данных RGB может быть частично ускорено за счет специфических для BC1 подсказок (hints), которые могут присутствовать в данных UASTC.

Непрозрачные UASTC текстуры должны быть транскодированы и загружены как [BC1](#bc1-s3tc-rgb).

UASTC текстуры с альфа-каналом должны быть транскодированы и загружены как [BC3](#bc3-s3tc-rgba).

#### PVRTC1

Транскодирование UASTC в PVRTC1 включает в себя декодирование текстуры в несжатые пиксели и их перекодирование в PVRTC1. Этот процесс полностью реализован эталонным транскодером.

> **Примечание.** Транскодирование в PVRTC1 поддерживается только для текстур с размерами, кратными степени двойки.

> **Примечание.** Эталонному транскодеру UASTC→PVRTC1 нужно знать, используется ли альфа-канал.

> **Примечание.** Оборудование Apple может не принимать неквадратные текстуры PVRTC1.

#### 16-битные упакованные форматы

Иногда декодирование UASTC в [16-битные упакованные форматы](#16-битные-упакованные-форматы-1) (RGB565 или RGBA4444) может давать лучший результат, чем транскодирование в ETC, BC1/BC3 или PVRTC1, ценой увеличения (примерно в 2 раза) объёма памяти GPU.

### Дополнительные цели транскодирования (Red)

Когда ни ASTC, ни BC7 недоступны, Red (одноканальные) UASTC текстуры можно транскодировать в [EAC R11](#eac-r11) или [BC4](#bc4). Оба варианта занимают меньше памяти GPU, чем несжатый [R8](#r8). Транскодирование в них требует декодирования UASTC и перекодирования, поэтому оно может быть медленнее, чем использование декодированных данных в исходном виде. Потери качества при транскодировании обычно незначительны, если в текстуре нет контрастных высокочастотных данных.

![UASTC Red Target Format Selection Flowchart](/assets/img/ktx-basisu-dev-guide/UASTC_targets_red.png)

### Дополнительные цели транскодирования (Red-Green)

Когда ни ASTC, ни BC7 недоступны, Red-Green (двухканальные) UASTC текстуры можно транскодировать в [EAC RG11](#eac-rg11) или [BC5](#bc5). Оба варианта занимают меньше памяти GPU, чем несжатый [RG8](#rg8). Транскодирование в них требует декодирования UASTC и перекодирования, поэтому оно может быть медленнее, чем использование декодированных данных в исходном виде. Потери качества при транскодировании обычно незначительны, если в текстуре нет контрастных высокочастотных данных.

![UASTC Red-Green Target Format Selection Flowchart](/assets/img/ktx-basisu-dev-guide/UASTC_targets_red_green.png)

## Поддержка GPU API

### Сжатые форматы

#### ASTC 4x4

Транскодированные данные занимают 16 байт на каждый блок 4x4.

| API | Определение поддержки | Формат sRGB | Линейный формат |
|-|-|-|-|
| Vulkan | Функция устройства `textureCompressionASTC_LDR` | `VK_FORMAT_ASTC_4x4_SRGB_BLOCK` | `VK_FORMAT_ASTC_4x4_UNORM_BLOCK` |
| WebGL | Расширение `WEBGL_compressed_texture_astc` | `COMPRESSED_SRGB8_ALPHA8_ASTC_4x4_KHR` | `COMPRESSED_RGBA_ASTC_4x4_KHR` |
| OpenGL (ES) | Расширение `GL_KHR_texture_compression_astc_ldr` | `GL_COMPRESSED_SRGB8_ALPHA8_ASTC_4x4_KHR` | `GL_COMPRESSED_RGBA_ASTC_4x4_KHR` |
| Direct3D | N/A | N/A | N/A |
| Metal | GPU с `MTLGPUFamilyApple2` | `MTLPixelFormatASTC_4x4_sRGB` | `MTLPixelFormatASTC_4x4_LDR` |

Если платформа позволяет задать режим декодирования ASTC (например, через `VK_EXT_astc_decode_mode` или `GL_EXT_texture_compression_astc_decode_mode`), приложениям следует установить значение `unorm8`.

#### BC1 (S3TC RGB)

Транскодированные данные занимают 8 байт на каждый блок 4x4.

| API | Определение поддержки | Формат sRGB | Линейный формат |
|-|-|-|-|
| Vulkan | Функция устройства `textureCompressionBC` | `VK_FORMAT_BC1_RGB_SRGB_BLOCK` | `VK_FORMAT_BC1_RGB_UNORM_BLOCK` |
| WebGL | Расширения `WEBGL_compressed_texture_s3tc` и `WEBGL_compressed_texture_s3tc_srgb` | `COMPRESSED_SRGB_S3TC_DXT1_EXT` | `COMPRESSED_RGB_S3TC_DXT1_EXT` |
| OpenGL | Расширения `GL_EXT_texture_compression_s3tc` и `GL_EXT_texture_sRGB` | `GL_COMPRESSED_SRGB_S3TC_DXT1_EXT` | `GL_COMPRESSED_RGB_S3TC_DXT1_EXT` |
| OpenGL ES | Расширения `GL_EXT_texture_compression_s3tc` и `GL_EXT_texture_compression_s3tc_srgb` | `GL_COMPRESSED_SRGB_S3TC_DXT1_EXT` | `GL_COMPRESSED_RGB_S3TC_DXT1_EXT` |
| Direct3D | Уровень `9_1` и выше | `DXGI_FORMAT_BC1_UNORM_SRGB` | `DXGI_FORMAT_BC1_UNORM` |
| Metal | GPU с `MTLGPUFamilyMac1` или `MTLGPUFamilyMacCatalyst1` | `MTLPixelFormatBC1_RGBA_sRGB` | `MTLPixelFormatBC1_RGBA` |

> **Примечание.** В Direct3D и Metal используются перечисления BC1 RGBA, так как эти API не предоставляют BC1 RGB. Транскодированные блоки, созданные эталонным транскодером, в любом случае будут правильно оцифрованы.

#### BC3 (S3TC RGBA)

Транскодированные данные занимают 16 байт на каждый блок 4x4.

| API | Определение поддержки | Формат sRGB | Линейный формат |
|-|-|-|-|
| Vulkan | Функция устройства `textureCompressionBC` | `VK_FORMAT_BC3_SRGB_BLOCK` | `VK_FORMAT_BC3_UNORM_BLOCK` |
| WebGL | Расширения `WEBGL_compressed_texture_s3tc` и `WEBGL_compressed_texture_s3tc_srgb` | `COMPRESSED_SRGB_ALPHA_S3TC_DXT5_EXT` | `COMPRESSED_RGBA_S3TC_DXT5_EXT` |
| OpenGL | Расширения `GL_EXT_texture_compression_s3tc` и `GL_EXT_texture_sRGB` | `GL_COMPRESSED_SRGB_ALPHA_S3TC_DXT5_EXT` | `GL_COMPRESSED_RGBA_S3TC_DXT5_EXT` |
| OpenGL ES | Расширения `GL_EXT_texture_compression_s3tc` и `GL_EXT_texture_compression_s3tc_srgb` | `GL_COMPRESSED_SRGB_ALPHA_S3TC_DXT5_EXT` | `GL_COMPRESSED_RGBA_S3TC_DXT5_EXT` |
| Direct3D | Уровень `9_1` и выше | `DXGI_FORMAT_BC3_UNORM_SRGB` | `DXGI_FORMAT_BC3_UNORM` |
| Metal | GPU с `MTLGPUFamilyMac1` или `MTLGPUFamilyMacCatalyst1` | `MTLPixelFormatBC3_RGBA_sRGB` | `MTLPixelFormatBC3_RGBA` |

#### BC4

Транскодированные данные занимают 8 байт на каждый блок 4x4.

| API | Определение поддержки | Линейный формат |
|-|-|-|
| Vulkan | Функция устройства `textureCompressionBC` | `VK_FORMAT_BC4_UNORM_BLOCK` |
| WebGL | Расширение `EXT_texture_compression_rgtc` | `COMPRESSED_RED_RGTC1_EXT` |
| OpenGL | Расширение `ARB_texture_compression_rgtc` | `GL_COMPRESSED_RED_RGTC1_EXT` |
| OpenGL ES | Расширение `GL_EXT_texture_compression_rgtc` | `GL_COMPRESSED_RED_RGTC1_EXT` |
| Direct3D | Уровень `10_0` и выше | `DXGI_FORMAT_BC4_UNORM` |
| Metal | GPU с `MTLGPUFamilyMac1` или `MTLGPUFamilyMacCatalyst1` | `MTLPixelFormatBC4_RUnorm` |

#### BC5

Транскодированные данные занимают 16 байт на каждый блок 4x4.

| API | Определение поддержки | Линейный формат |
|-|-|-|
| Vulkan | Функция устройства `textureCompressionBC` | `VK_FORMAT_BC5_UNORM_BLOCK` |
| WebGL | Расширение `EXT_texture_compression_rgtc` | `COMPRESSED_RED_GREEN_RGTC2_EXT` |
| OpenGL | Расширение `ARB_texture_compression_rgtc` | `GL_COMPRESSED_RED_GREEN_RGTC2_EXT` |
| OpenGL ES | Расширение `GL_EXT_texture_compression_rgtc` | `GL_COMPRESSED_RED_GREEN_RGTC2_EXT` |
| Direct3D | Уровень `10_0` и выше | `DXGI_FORMAT_BC5_UNORM` |
| Metal | GPU с `MTLGPUFamilyMac1` или `MTLGPUFamilyMacCatalyst1` | `MTLPixelFormatBC5_RGUnorm` |

#### BC7

Транскодированные данные занимают 16 байт на каждый блок 4x4.

| API | Определение поддержки | Формат sRGB | Линейный формат |
|-|-|-|-|
| Vulkan | Функция устройства `textureCompressionBC` | `VK_FORMAT_BC7_SRGB_BLOCK` | `VK_FORMAT_BC7_UNORM_BLOCK` |
| WebGL | Расширение `EXT_texture_compression_bptc` | `COMPRESSED_SRGB_ALPHA_BPTC_UNORM_EXT` | `COMPRESSED_RGBA_BPTC_UNORM_EXT` |
| OpenGL | Расширение `GL_ARB_texture_compression_bptc` | `GL_COMPRESSED_SRGB_ALPHA_BPTC_UNORM_ARB` | `GL_COMPRESSED_RGBA_BPTC_UNORM_ARB` |
| OpenGL ES | Расширение `GL_EXT_texture_compression_bptc` | `GL_COMPRESSED_SRGB_ALPHA_BPTC_UNORM_EXT` | `GL_COMPRESSED_RGBA_BPTC_UNORM_EXT` |
| Direct3D | Уровень `11_0` | `DXGI_FORMAT_BC7_UNORM_SRGB` | `DXGI_FORMAT_BC7_UNORM` |
| Metal | GPU с `MTLGPUFamilyMac1` или `MTLGPUFamilyMacCatalyst1` | `MTLPixelFormatBC7_RGBAUnorm_sRGB` | `MTLPixelFormatBC7_RGBAUnorm` |

#### ETC1 RGB

Транскодированные данные занимают 8 байт на каждый блок 4x4.

| API | Определение поддержки | Формат sRGB | Линейный формат |
|-|-|-|-|
| Vulkan | Функция устройства `textureCompressionETC2` | `VK_FORMAT_ETC2_R8G8B8_SRGB_BLOCK` | `VK_FORMAT_ETC2_R8G8B8_UNORM_BLOCK` |
| WebGL | Расширение `WEBGL_compressed_texture_etc` | `COMPRESSED_SRGB8_ETC2` | `COMPRESSED_RGB8_ETC2` |
| OpenGL | Расширение `GL_ARB_ES3_compatibility` | `GL_COMPRESSED_SRGB8_ETC2` | `GL_COMPRESSED_RGB8_ETC2` |
| OpenGL ES | Версия 3.0 и выше | `GL_COMPRESSED_SRGB8_ETC2` | `GL_COMPRESSED_RGB8_ETC2` |
| Direct3D | N/A | N/A | N/A |
| Metal | GPU с `MTLGPUFamilyApple1` | `MTLPixelFormatETC2_RGB8_sRGB` | `MTLPixelFormatETC2_RGB8` |

> **Примечание.** В WebGL контекстах на базе OpenGL ES 2.0 может быть доступно расширение `WEBGL_compressed_texture_etc1`, которое предоставляет только линейный формат ETC1 (`ETC1_RGB8_OES`). Приложениям потребуется декодировать значения sRGB с помощью фрагментного шейдера.

> **Примечание.** В контекстах OpenGL ES 2.0 может быть доступно расширение `GL_OES_compressed_ETC1_RGB8_texture`, которое предоставляет только линейный формат ETC1 (`GL_ETC1_RGB8_OES`). Приложениям потребуется декодировать значения sRGB с помощью фрагментного шейдера.

> **Примечание.** Эталонный транскодер выдаёт блоки, которые не используют специфические для ETC2 функции, что позволяет использовать транскодированные данные на оборудовании ETC1.

> **Примечание.** Многие десктопные GPU предоставляют расширение OpenGL `GL_ARB_ES3_compatibility`, но аппаратной поддержки формата ETC1 RGB у большинства нет — распаковка выполняется в драйвере. На момент написания нативно этот формат поддерживают только десктопные GPU Intel новее «Haswell».

#### ETC2 RGBA

Транскодированные данные занимают 16 байт на каждый блок 4x4.

| API | Определение поддержки | Формат sRGB | Линейный формат |
|-|-|-|-|
| Vulkan | Функция устройства `textureCompressionETC2` | `VK_FORMAT_ETC2_R8G8B8A8_SRGB_BLOCK` | `VK_FORMAT_ETC2_R8G8B8A8_UNORM_BLOCK` |
| WebGL | Расширение `WEBGL_compressed_texture_etc` | `COMPRESSED_SRGB8_ALPHA8_ETC2_EAC` | `COMPRESSED_RGBA8_ETC2_EAC` |
| OpenGL | Расширение `GL_ARB_ES3_compatibility` | `GL_COMPRESSED_SRGB8_ALPHA8_ETC2_EAC` | `GL_COMPRESSED_RGBA8_ETC2_EAC` |
| OpenGL ES | Версия 3.0 и выше | `GL_COMPRESSED_SRGB8_ALPHA8_ETC2_EAC` | `GL_COMPRESSED_RGBA8_ETC2_EAC` |
| Direct3D | N/A | N/A | N/A |
| Metal | GPU с `MTLGPUFamilyApple1` | `MTLPixelFormatEAC_RGBA8_sRGB` | `MTLPixelFormatEAC_RGBA8` |

> **Примечание.** В контекстах OpenGL ES 2.0 или WebGL на их базе данные можно транскодировать в две текстуры ETC1: одну для RGB, другую для альфы. Подробнее об использовании аппаратуры ETC1 — в предыдущем разделе.

> **Примечание.** Многие десктопные GPU предоставляют расширение OpenGL `GL_ARB_ES3_compatibility`, но аппаратной поддержки формата ETC2 RGBA у большинства нет — распаковка выполняется в драйвере. На момент написания нативно этот формат поддерживают только десктопные GPU Intel новее «Haswell».

#### EAC R11

Транскодированные данные занимают 8 байт на каждый блок 4x4.

| API | Определение поддержки | Линейный формат |
|-|-|-|
| Vulkan | Функция устройства `textureCompressionETC2` | `VK_FORMAT_EAC_R11_UNORM_BLOCK` |
| WebGL | Расширение `WEBGL_compressed_texture_etc` | `COMPRESSED_R11_EAC` |
| OpenGL | Расширение `GL_ARB_ES3_compatibility` | `GL_COMPRESSED_R11_EAC` |
| OpenGL ES | Версия 3.0 и выше | `GL_COMPRESSED_R11_EAC` |
| Direct3D | N/A | N/A |
| Metal | GPU с `MTLGPUFamilyApple1` | `MTLPixelFormatEAC_R11Unorm` |

> **Примечание.** Многие десктопные GPU предоставляют расширение OpenGL `GL_ARB_ES3_compatibility`, но аппаратной поддержки формата EAC R11 у большинства нет — распаковка выполняется в драйвере. На момент написания нативно этот формат поддерживают только десктопные GPU Intel новее «Haswell».

#### EAC RG11

Транскодированные данные занимают 16 байт на каждый блок 4x4.

| API | Определение поддержки | Линейный формат |
|-|-|-|
| Vulkan | Функция устройства `textureCompressionETC2` | `VK_FORMAT_EAC_R11G11_UNORM_BLOCK` |
| WebGL | Расширение `WEBGL_compressed_texture_etc` | `COMPRESSED_RG11_EAC` |
| OpenGL | Расширение `GL_ARB_ES3_compatibility` | `GL_COMPRESSED_RG11_EAC` |
| OpenGL ES | Версия 3.0 и выше | `GL_COMPRESSED_RG11_EAC` |
| Direct3D | N/A | N/A |
| Metal | GPU с `MTLGPUFamilyApple1` | `MTLPixelFormatEAC_RG11Unorm` |

> **Примечание.** Многие десктопные GPU предоставляют расширение OpenGL `GL_ARB_ES3_compatibility`, но аппаратной поддержки формата EAC RG11 у большинства нет — распаковка выполняется в драйвере. На момент написания нативно этот формат поддерживают только десктопные GPU Intel новее «Haswell».

#### PVRTC1

Транскодированные данные занимают 8 байт на каждый блок 4x4.

| API | Определение поддержки | Формат sRGB | Линейный формат |
|-|-|-|-|
| Vulkan | Расширение `VK_IMG_format_pvrtc` | `VK_FORMAT_PVRTC1_4BPP_SRGB_BLOCK_IMG` | `VK_FORMAT_PVRTC1_4BPP_UNORM_BLOCK_IMG` |
| WebGL | Расширение `WEBGL_compressed_texture_pvrtc` | N/A | `COMPRESSED_RGBA_PVRTC_4BPPV1_IMG` |
| OpenGL | N/A | N/A | N/A |
| OpenGL ES | Расширения `GL_IMG_texture_compression_pvrtc` и `GL_EXT_pvrtc_sRGB` | `GL_COMPRESSED_SRGB_ALPHA_PVRTC_4BPPV1_EXT` | `GL_COMPRESSED_RGBA_PVRTC_4BPPV1_IMG` |
| Direct3D | N/A | N/A | N/A |
| Metal | GPU с `MTLGPUFamilyApple1` | `MTLPixelFormatPVRTC_RGBA_4BPP_sRGB` | `MTLPixelFormatPVRTC_RGBA_4BPP` |

> **Примечание.** WebGL контексты не поддерживают форматы PVRTC1 sRGB. Декодирование sRGB придётся выполнять во фрагментном шейдере.

### Несжатые форматы

#### RGBA8

Размер декодированных данных вычисляется по размерам изображения в пикселях (не в блоках):

```
width * height * 4
```

| API | Формат sRGB | Линейный формат |
|-|-|-|
| Vulkan | `VK_FORMAT_R8G8B8A8_SRGB` | `VK_FORMAT_R8G8B8A8_UNORM` |
| WebGL | `SRGB8_ALPHA8` | `RGBA8` |
| OpenGL (ES) | `GL_SRGB8_ALPHA8` | `GL_RGBA8` |
| Direct3D | `DXGI_FORMAT_R8G8B8A8_UNORM_SRGB` | `DXGI_FORMAT_R8G8B8A8_UNORM` |
| Metal | `MTLPixelFormatRGBA8Unorm_sRGB` | `MTLPixelFormatRGBA8Unorm` |

> **Примечание.** WebGL 1.0 контексты требуют включения расширения `EXT_sRGB` для sRGB-фильтрации.

#### 16-битные упакованные форматы

Размер декодированных данных вычисляется по размерам изображения в пикселях (не в блоках):

```
width * height * 2
```

| API | Определение поддержки | RGB | RGBA |
|-|-|-|-|
| Vulkan | Всегда поддерживается | `VK_FORMAT_R5G6B5_UNORM_PACK16` | `VK_FORMAT_R4G4B4A4_UNORM_PACK16` |
| WebGL | Всегда поддерживается | `RGB565` | `RGBA4` |
| OpenGL (ES) | Всегда поддерживается | `GL_RGB565` | `GL_RGBA4` |
| Direct3D | WDDM 1.2 и новее | `DXGI_FORMAT_B5G6R5_UNORM` | N/A |
| Metal | GPU с `MTLGPUFamilyApple1` | `MTLPixelFormatB5G6R5Unorm` | `MTLPixelFormatABGR4Unorm` |

> **Примечание.** Приложениям WebGL следует проявлять осторожность при использовании этих форматов, поскольку они будут эмулироваться как RGBA8, если базовая платформа не поддерживает упакованные 16-битные форматы изначально.

> **Примечание.** Аппаратного декодирования sRGB для упакованных форматов нет. Декодирование sRGB придётся выполнять во фрагментном шейдере.

#### R8

Размер декодированных данных вычисляется по размерам изображения в пикселях (не в блоках):

```
width * height * 1
```

| API | Линейный формат |
|-|-|
| Vulkan | `VK_FORMAT_R8_UNORM` |
| WebGL 2.0 | `R8` |
| OpenGL (ES) | `GL_R8` |
| Direct3D | `DXGI_FORMAT_R8_UNORM` |
| Metal | `MTLPixelFormatR8Unorm` |

#### RG8

Размер декодированных данных вычисляется по размерам изображения в пикселях (не в блоках):

```
width * height * 2
```

| API | Линейный формат |
|-|-|
| Vulkan | `VK_FORMAT_R8G8_UNORM` |
| WebGL 2.0 | `RG8` |
| OpenGL (ES) | `GL_RG8` |
| Direct3D | `DXGI_FORMAT_R8G8_UNORM` |
| Metal | `MTLPixelFormatRG8Unorm` |
