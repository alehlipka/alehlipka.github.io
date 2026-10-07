---
title: Гайд по матрицам в OpenTK
date: 2026-10-07 10:48:11 +0300
author: me
categories: [Переводы, NogginBops OpenTK Blog]
tags: [Перевод, NogginBops, OpenTK, C#, OpenGL, Matrix, GLSL]
image: /assets/img/opentk.png
original:
    author:
        name: NogginBops
        url: https://nogginbops.github.io/
    post:
        title: The OpenTK matrix guide
        url: https://nogginbops.github.io/opentk-blog/support-tips/2026/02/17/matrix-guide.html
---

> TL;DR: [Как добиться согласованности при использовании OpenTK](#как-добиться-согласованности-при-использовании-opentk)
{: .prompt-tip }

Вокруг матриц в OpenTK и того, как они соотносятся с GLSL, существует много путаницы. В этом посте я постараюсь её развеять и показать, что всё не так сложно, как многие думают.

У матриц есть два независимых свойства: порядок хранения элементов и соглашение об умножении. Их часто смешивают, хотя на удивление мало что их связывает.

## Порядок хранения элементов матрицы

Матрица — это двумерная сетка чисел, и у неё нет "очевидного" способа хранения в памяти, которая линейна.
Превратить двумерную сетку в одномерный массив можно множеством способов, но для матриц популярны два: построчный порядок (row-major order) и постолбцовый порядок (column-major order).

При построчном порядке строки матрицы хранятся одна за другой, вот так:

![Построчный порядок хранения матрицы](/assets/img/the-opentk-matrix-guide/row-layout.svg){: width="500" }

В памяти это будет выглядеть так:

![Построчный порядок хранения матрицы в памяти](/assets/img/the-opentk-matrix-guide/row-linear-layout.svg){: width="1000" }

В коде это можно записать так:

``` csharp
public struct Matrix4
{
    public Vector4 Row0;
    public Vector4 Row1;
    public Vector4 Row2;
    public Vector4 Row3;
}
```

Аналогично, при постолбцовом порядке столбцы хранятся один за другим, вот так:

![Постолбцовый порядок хранения матрицы](/assets/img/the-opentk-matrix-guide/column-layout.svg){: width="500" }

В памяти это будет выглядеть так:

![Постолбцовый порядок хранения матрицы в памяти](/assets/img/the-opentk-matrix-guide/column-linear-layout.svg){: width="1000" }

В коде это можно записать так:

``` csharp
public struct Matrix4
{
    public Vector4 Column0;
    public Vector4 Column1;
    public Vector4 Column2;
    public Vector4 Column3;
}
```

Знать порядок хранения матрицы важно при передаче матриц между библиотеками, так как обе стороны должны договориться, какое число в какую позицию матрицы попадает.

Особенно это важно при взаимодействии между языками программирования, где компилятор не может проверить типы на стыке языков.
Представьте, что вы получили `float[16]`, представляющий матрицу: ничто не подскажет нам, какой позиции в матрице соответствует каждый элемент. Мы должны сами выбрать порядок хранения и придерживаться его.
Если кто-то другой использует другой порядок, нам нужно преобразовать нашу матрицу в его порядок, прежде чем передавать ему массив.

Что произойдёт, если прочитать матрицу с построчным порядком так, будто у неё постолбцовый порядок?
Другими словами, что если передать матрицу с постолбцовым порядком в функцию, которая читает матрицу построчно?
Взгляните ещё раз на иллюстрации выше и попробуйте догадаться сами.

Ответ: строки матрицы с построчным порядком будут прочитаны как столбцы матрицы с постолбцовым порядком.
Это значит, что столбец 0 матрицы теперь будет считаться строкой 0.
В математике замена строк матрицы на столбцы называется "транспонированием" матрицы.
Таким образом, передача матрицы с постолбцовым порядком в функцию, ожидающую матрицу с построчным порядком, означает, что функция прочитает транспонированную версию матрицы.
А значит, чтобы корректно вызвать функцию, нам нужно преобразовать нашу матрицу с построчным порядком в матрицу с постолбцовым порядком, что можно сделать, транспонировав её.
В обратную сторону это тоже работает.

## Соглашение об умножении

Второе важное свойство матриц — соглашение об умножении. Упрощённо, оно говорит нам, с какой стороны — слева или справа — нужно умножать вектор на матрицу, чтобы получить правильный результат. В качестве примера рассмотрим простую матрицу переноса 4x4. Есть два способа задать матрицу, которая при умножении на вектор даст перенос. Первый — создать матрицу переноса, в которой смещение находится в последнем столбце:

![Матрица переноса со смещением в последнем столбце](/assets/img/the-opentk-matrix-guide/column-translation.svg){: width="500" }

Чтобы перенести вектор с помощью этой матрицы, нужно умножить её на вектор справа:

![Умножение матрицы на вектор-столбец справа](/assets/img/the-opentk-matrix-guide/column-multiplication.svg){: width="500" }

Как видим, в результате получается вектор, смещённый на значения из матрицы. Но на самом деле матрицу переноса можно было построить и по-другому. Мы могли бы поместить смещение в последнюю строку матрицы и умножать на неё вектор-строку слева, вот так:

![Умножение вектора-строки на матрицу слева](/assets/img/the-opentk-matrix-guide/row-multiplication.svg){: width="1000" }

Эти два варианта дают одинаковый результат, но сами матрицы не равны. Поэтому, чтобы знать, как умножать векторы на матрицы, нам нужно знать, умножать ли вектор справа или слева. В математической нотации всегда явно видно, умножается ли вектор как столбец или как строка, но в языках программирования библиотеки зачастую используют один и тот же тип для всех векторов, и форма вектора (столбец или строка) не записывается явно, как в математической нотации.
Например, если в OpenTK у нас есть переменная `Vector4 v`, OpenTK позволит написать как `v * M` (умножение слева, как вектор-строка), так и `M * v` (умножение справа, как вектор-столбец), что может сбивать с толку.

Важный факт об умножении матриц: `vM = Mᵀvᵀ`. То есть если матрица ожидает умножения на вектор-строку слева, мы можем транспонировать её и умножить на вектор-столбец справа. В коде это выглядело бы примерно так:

``` csharp
Matrix4 M = ...;
Vector4 v = ...;

// Это всегда будет верно (с поправкой на точность float).
Debug.Assert(v * M == Matrix4.Transpose(M) * v);
```

## Почему их путают?

На [Discord-сервер OpenTK](https://discord.gg/eFXkNsrB3V) приходит много людей с вопросами, почему ничего не рендерится или почему все их трансформации ведут себя странно.
Ответ почти всегда один: пользователь ошибся либо с порядком хранения, либо с соглашением об умножении — то ли потому что не знает, что это такое, то ли потому что смешивает одно с другим.

Причин, по которым эти два свойства матриц смешивают и путают, много, но я подозреваю, что главная из них в том, что оба соглашения можно поменять транспонированием матрицы — случайно или намеренно.

Транспонировать матрицу могут, потому что она будет передана в функцию, ожидающую матрицу с противоположным порядком хранения, а могут — чтобы сменить соглашение об умножении со слева-направо на справа-налево или наоборот. Кроме того, транспонирование — полезная математическая операция, которая встречается в некоторых формулах безо всякой прямой связи с порядком хранения или соглашением об умножении.

Ещё одна путаница связана с GLSL и OpenGL. Исторически OpenGL использовал матрицы с постолбцовым порядком хранения и соглашением об умножении справа-налево, однако в современных версиях OpenGL это уже не так. Современный OpenGL почти полностью безразличен к порядку хранения[^majorness] и соглашению об умножении[^multiplication], как мы увидим в следующем разделе.

## Как добиться согласованности при использовании OpenTK

OpenTK использует построчный порядок хранения и порядок умножения слева-направо. Это значит, что в коде на C# векторы умножаются на матрицы слева. В следующих разделах мы разберём, как добиться согласованного порядка умножения матриц и в C#, и в GLSL.

### C#

В C# OpenTK использует матрицы с построчным порядком хранения и порядком умножения слева-направо, то есть операции применяются слева направо. Самая левая матрица будет применена первой. В этом примере у нас простая настройка модель-вид-проекция, где мы передаём матрицу в шейдер как uniform-переменную:

``` csharp
Matrix4 M = Matrix4.CreateScale(2); // модель
Matrix4 V = Matrix4.CreateTranslation(0, 0, -2).Inverted(); // вид
Matrix4 P = Matrix4.CreatePerspectiveFieldOfView(90f/180f * MathF.PI, Width / Height, 0.1f, 100f); // проекция

Matrix4 MVP = M * V * P; // умножение слева направо

// Передаём transpose=true, чтобы сообщить OpenGL, что мы отправляем матрицу с построчным порядком хранения
GL.UniformMatrix4(0, true, ref MVP);
```

Здесь интересен вызов `GL.UniformMatrix4`, в котором мы передаём `true` в аргументе `transpose`. Это нужно потому, что по умолчанию OpenGL читает матрицы в постолбцовом порядке, а транспонирование превращает нашу матрицу с построчным порядком в матрицу с постолбцовым. Лично я мысленно переименовал этот аргумент во что-то вроде `is_row_major`, потому что транспонирование для меня — операция, относящаяся к соглашению об умножении и не имеющая ничего общего с порядком хранения.

### Uniform-переменные в GLSL

Если передавать матрицы в GLSL так, как показано выше, там действует то же соглашение об умножении слева-направо. То есть векторы стоят слева от матриц, и операции применяются слева направо.

``` glsl
// Небольшой шейдер, преобразующий позиции вершин с помощью матриц модели, вида и проекции.

in vec3 v;

uniform mat4 M; // модель
uniform mat4 VP; // вид * проекция

void main() {
    // Используем принятое в OpenTK соглашение об умножении матриц слева-направо.
    gl_Position = vec4(v, 1.0) * M * VP;
}
```

### UBO/SSBO в GLSL

При использовании Uniform Buffer Objects (UBO) или Shader Storage Buffer Objects (SSBO) можно указать квалификатор раскладки `row_major`, чтобы сообщить OpenGL, что наши матрицы хранятся построчно.

``` glsl
// Небольшой шейдер для инстансинга, использующий матрицы модели для каждого экземпляра, загруженные через SSBO.

in vec3 v;

// Сообщаем OpenGL, что буфер содержит матрицы с построчным порядком хранения.
layout(row_major, binding = 0) readonly buffer InstanceTransforms {
    mat4 instance_M[];
}

uniform mat4 VP; // вид * проекция

void main() {
    // Используем принятое в OpenTK соглашение об умножении матриц слева-направо.
    gl_Position = vec4(v, 1.0) * instance_M[gl_InstanceID] * VP;
}
```

### Вершинные атрибуты в GLSL

Это единственный API в OpenGL, который не безразличен к порядку хранения. Дело в том, что матричные вершинные атрибуты задаются четырьмя отдельными вершинными атрибутами типа `vec4`, где каждый `vec4` становится столбцом матрицы. Невозможно задать атрибут `vec4`, отдельные числа которого идут с шагом (stride), а значит, невозможно подать на вход вершинного шейдера матрицу с построчным порядком хранения. Это не значит, что их нельзя использовать в OpenTK, — просто матрица, которую вы получите в GLSL, будет транспонирована.

``` glsl
// Небольшой шейдер для инстансинга, использующий матрицы модели в вершинных атрибутах
// и glVertexAttribDivisor для инстансинга

in vec3 v;
in mat4 instance_M_T; // транспонированная матрица модели из-за ограничения вершинных атрибутов

uniform mat4 VP; // вид * проекция

void main()
{
    mat4 instance_M = transpose(instance_M_T); // Транспонируем транспонированную матрицу
    gl_Position = vec4(v, 1.0) * instance_M * VP;
}
```

Лично я для инстансинга предпочитаю подход с SSBO, так как он проще, намного гибче и в целом не должен быть медленнее вершинных атрибутов[^ssbo].

### TBN-матрица для normal mapping в GLSL

При реализации normal mapping обычно строят матрицу TBN (Tangent Bitangent Normal — касательная, бикасательная, нормаль).
Конструкторы матриц — единственная часть GLSL, которая не безразлична к соглашению об умножении.
Соглашение об умножении определяется тем, где расположены элементы матрицы, а конструкторы матриц в GLSL принимают на вход векторы-столбцы.
Поэтому если построить TBN-матрицу с помощью конструктора вот так: `mat3(fTangent, fBitangent, fNormal)`, получится матрица с соглашением об умножении справа-налево.
Простое решение — транспонировать построенную матрицу: `transpose(mat3(fTangent, fBitangent, fNormal))`, что вернёт соглашение об умножении слева-направо.

``` glsl
// Часть фрагментного шейдера, реализующего normal mapping,
// показывающая, как конструкторы матриц строят матрицы из векторов-столбцов.

in vec3 fNormal;
in vec4 fTangentW; // xyz: касательная, w: знак бикасательной
in vec2 fUV;

uniform sampler2D texNormal;

out vec3 oNormal;

void main()
{
    vec3 fTangent = fTangentW.xyz;
    vec3 fBitangent = cross(fNormal, fTangent) * fTangentW.w;

    // Входные векторы рассматриваются как столбцы,
    // что даёт матрицу с соглашением об умножении справа-налево.
    mat3 TBN = transpose(mat3(fTangent, fBitangent, fNormal));

    vec3 tangentSpaceNormal = texture(texNormal, fUV) * 2.0 - 1.0;

    oNormal = tangentSpaceNormal * TBN;
}
```

А если вы переживаете, что лишнее транспонирование снизит производительность, могу вас заверить: [компилятор разберётся и уберёт транспонирование при оптимизации](https://godbolt.org/#z:OYLghAFBqd5TKALEBjA9gEwKYFFMCWALugE4A0BIEAZgQDbYB2AhgLbYgDkAjF%2BTXRMiAZVQtGIHgBYBQogFUAztgAKAD24AGfgCsp5eiyagk9JfXIrGqIgSHVmmAMLp6AVzZMQADllOAGQImbAA5TwAjbFIQACYtcgAHdCVieyZXDy9fWWTUuyEgkPC2KJj4q2wbAqYRIhZSIkzPbz9K6vS6hqIisMjouISlesbm7Lbh7t6SssGASit0d1JUTi4AenWAagAVJGwt5iJSAE8t5OCiLeNMLZHgbCvE0nQ6RmvSA5DsHFuSLYwbESDAORCQBCUh3U7ESkgApFoAIKbLYAWh25yUAH0AGy4tG4LaqEQAWRYwQRiMpw1I7lsWwAkkxEu4iJS4QB2ABClK2fK2NHo6BYRAAzFsmGQ2BI4aKeUj%2BQKhSLpHdjA9hFiIgB3WXyxGKwXCsVbTAilg8PXsjkAEStSMpACUAOp1Wm2ZY/LnuGg0aKy5xMlls0WE72%2B6JaLYgLafYAQojRCDuLRze1Uh0AVi5TE8YM%2BLEwSggPHIW1L5bTmbtSIAbugCLdnKTyUxk5dxTado3o1sRAA1LE2iGJEWoJB7AuYBk2tMO7m8/lGkXiyWkaX0Laym1bcN%2B0haOHZw/VgB0a436cNypN9RMRy3op3e8jR65J5tp7vGqIWu1p/UE4AC8ryXG9xQiYh1QfbcAReJRiwvCQy2/I45i2AAqXcfX3E93yPT9UM1HVT11OV2QVfkXwPN8P1PM16h4R8dzYdx6FocD1FFCAiKIMtIN4sskPoBZsIjGjjwI%2BjzR4NNyPnGtES4BZ6G4TN%2BG8LgdHIdBuAACQCEQAi2JQlhWA44ViUU%2BHIIhtGUhYAGs4gATlPFyOVFHFRS0DkfB4FytBc0VYkMbhpH4NgQGkaRTw5DkeFiaQeB8HytBxTMvNkTTtN0rh%2BCUEAEjsrTlPIOBYBQDAcHwYgyEoag3mYdg1hswRhDECROBkORhGUNRNFK8h9FCowTBAMwLHabBbHSRwmBcNwWhAFzM3IQJgj6UoBhSpIUjSIQxm8Va9vydJpn6GJdusGaai6UYluyE6btmoR7p6TaZh2nwrBGJpHuOtbJkaC7tqunwFlM5ZVm4aljjpK4g1Za19WvY1VylGV5INMDjVVXi/1AvllxNBiLXTTk7Wxp1XXhj1PkwaiAyRkMwxwyNezjBMkxTOT9XZbNczYfNsELYsKwlqtFPrHtmzJYJ22ETtu1uGMByHEcxwnJApxnOcqQXSjifAiVMc3WDqLwujhKJpV0bVe9hGYsTcNoqSCZIwCQOxtGVy2AToKd2DUHgxCzZQwOiHQrDLbds8Pf/Mj%2BaNl3X0ks8yaY2DWPY2P08/TOUNIYwlDybAOPRrieMj/ioMdvjTfXCQ5hbinbUpMrVK4dTyBy/g8oMoyTLM1Ytys2J%2BBKnQW/IfZCwGCAVPCyKQEzTNT1iWIfA5TN/JxFzgukbycV7%2BydO4Aqits%2ByZ%2Bc6QtDi1LpFWnwcX8oLpFG7hRQ0s%2B8snm%2B5VEAQCqugIEIIKBUAgICYEjAYikGACwLEsQsQ8FFAIBgiZSCFQgBEM%2BkFWCnG4DZAhDQTgAHkIi6FusQ/ggIODCHIUwegJwz44AiO4YAzgJDmFoeQHA0oTCSCGoQT4s1azYEKkNbA6gZqslavwS4VQz70AIBEYupxXA4DPscAgUVeD8AkaQCIKRsA2mwII4AqjxqlQWIKFgwAlD9gINgbU5DEjMD4e1UQ4hJA9W8f1DQZ99CljGqYcwlhVEREKpABY6BEg1CkaiSEmB1CJTRKgLYwAaBpPiExVEqJUBKFRGwLAVQATYjxDiNEhTilHFOFsOWrZ%2B5GNII2SR8BIZVFunNCATgjoGA2sUS6Bg8gHQyADUZ%2B0aig1mKWF6d0/oDPmd016tQ/qzJ2r9boyztkg0%2BiM2SixobdSXt3X%2BQ08pbERCSHcjoADiBpYinjQVsCAtUSCkDHtZOYADbELDnjgGIi9yDOViBydysQeBaC0NvIKHItCZjfmFLgEVyBRWhQkPu598pWCvlPMqFVkBoDAbA6IDVoGkogSABBSCUFoIwfQLBOC8FDVIUQgx5B2UUKoTQzl9CjhMJYWw7AHCuE8KkTZAR6phHaVET0iRUjtIyLkYmPhSiu7aSiRok4Wi1jaV0fomyRiTEqHMZY6xoBbECCMI45xrj3GeM5d4zqfjZABJUEEoaI1DDqgmhEwwaiYkgviYk7gyTTS5IyVknJiUtD5NqSUspm4im4nxAUopqJ6lnCacEFp0Q2k4GDV0joDg%2BkLV2UMraczTrjN2WMmZBywYGAWZ0JZkyVmlvWVMJtNbgb/SyN4eZGze07UhiPTgsQzk92xVcm5dzHlbGea895hBPnfKnX86eALRZAuoE5EA1kN6rWfpmT%2BUK/AuS/qii5uUL54uKjfM5E9T6XPvQSmeRjUgOGkEAA%3D%3D). Так что не беспокойтесь: согласованность соглашения об умножении можно получить без потерь в производительности.

## Что делают другие библиотеки?

У других библиотек, помимо OpenTK, свои соглашения. Вот неполный список библиотек с их порядком хранения и соглашением об умножении:

| Библиотека                                                                       | Порядок хранения | Соглашение об умножении |
|:---------------------------------------------------------------------------------|:-----------------|:------------------------|
| [`OpenTK`](https://opentk.net)                                                   | Построчный       | `v * M`                 |
| [`System.Numerics`](https://learn.microsoft.com/en-us/dotnet/api/system.numerics) | Построчный       | `v * M`                 |
| [GLM](https://github.com/g-truc/glm)                                             | Постолбцовый     | `M * v`                 |
| [DirectXMath](https://github.com/microsoft/DirectXMath)                          | Построчный       | `v * M`                 |
| [Unity](https://unity.com/)                                                      | Постолбцовый     | `M * v`                 |
| [Unreal](https://www.unrealengine.com)                                           | Построчный       | `v * M`                 |
| [Godot](https://godotengine.org/)                                                | Постолбцовый     | `M * v`                 |

Как видим, порядок хранения и соглашение об умножении сильно коррелируют. Почему так? Оказывается, когда матрица хранится построчно, умножать на неё вектор слева действительно быстрее, поскольку все компоненты результирующего вектора можно вычислять параллельно. Поэтому библиотеку, в которой порядок хранения и соглашение об умножении не коррелируют, встретить довольно сложно, но это не значит, что таких не может быть. Создавая собственные матрицы в OpenTK, вы вполне можете построить матрицы с соглашением об умножении справа-налево, используя структуру `Matrix4` из OpenTK.

[^majorness]: Матрицы в вершинных атрибутах, к сожалению, можно задавать только в постолбцовом порядке.
[^multiplication]: Конструкторы матричных типов принимают в качестве аргументов векторы-столбцы; конструктора, строящего матрицу из строк, не существует.
[^ssbo]: [В этой статье](https://www.yosoygames.com.ar/wp/2018/03/vertex-formats-part-2-fetch-vs-pull/) сравниваются SSBO и вершинные атрибуты для повершинных данных. Разумно ожидать похожих результатов и для данных экземпляров, но с меньшей разницей в производительности.
