---
title: Что такое OPENTK4_USE_WAYLAND и для чего он нужен?
description: Перевод поста NogginBops "What is OPENTK4_USE_WAYLAND and what does it do?"
date: 2026-01-09 10:11:12 +0300
author: me
categories: [Переводы, NogginBops OpenTK Blog]
tags: [перевод, nogginbops, opentk, c#, opengl]
---

**Пост не является авторским и/или официальным**  
**Ссылка на оригинал:** [`What is OPENTK4_USE_WAYLAND and what does it do?`](https://nogginbops.github.io/opentk-blog/support-tips/2025/12/15/what-is-opentk4-use-wayland.html)  
**Автор оригинала:** [`NogginBops`](https://github.com/NogginBops)  

Для первого поста в этом блоге я хочу разобраться с малоизвестной переменной окружения `OPENTK4_USE_WAYLAND` и тем, как она взаимодействует с OpenTK.

OpenTK 4.x использует GLFW для создания окон и работы с ними.
Изначально GLFW не имела поддержки Wayland и полагалась на XWayland для совместимости с этой средой.

Ситуация изменилась с выходом GLFW 3.3, где появилась возможность собрать библиотеку либо для X11, либо для Wayland, что приводило к созданию двух разных файлов `.so`.
Поддержка Wayland в GLFW 3.3 была «сырой», и многие API GLFW невозможно реализовать под Wayland из-за ограничений, накладываемых этим протоколом.
Это означало, что автоматический выбор Wayland по умолчанию в OpenTK привёл бы к множеству проблем, поскольку GLFW выдавала бы ошибки даже на простых операциях, например, при создании `NativeWindow`.

Наличие двух разных файлов `.so` означало, что решение об использовании Wayland или XWayland нужно было принимать в момент загрузки библиотеки GLFW.
Чтобы принять это решение, OpenTK 4 использует переменную `XDG_SESSION_TYPE` для определения запуска под Wayland, а затем учитывает `OPENTK4_USE_WAYLAND`, чтобы решить, следует ли загружать Wayland-версию GLFW. Таким образом, начиная с OpenTK `4.8.0+`, использование Wayland стало опциональным и включается установкой `OPENTK4_USE_WAYLAND=1`.

GLFW 3.4 всё изменила, добавив нативную поддержку Wayland. Теперь GLFW можно было собрать с поддержкой и X11, и Wayland в одном файле `.so`.
Это добавило в GLFW новый API для выбора бэкенда. На платформах с Wayland GLFW теперь по умолчанию использует Wayland-бэкенд, и чтобы отключить его, нужно явно вызвать новый API GLFW. Поэтому в OpenTK `4.9.1` поведение переменной `OPENTK4_USE_WAYLAND` было изменено: теперь `OPENTK4_USE_WAYLAND=0` отказывается от использования Wayland при запуске в этой среде. Одновременно было введено свойство [`GLFWProvider.HonorOpenTK4UseWayland`](https://opentk.net/api/OpenTK.Windowing.Desktop.GLFWProvider.html#OpenTK_Windowing_Desktop_GLFWProvider_HonorOpenTK4UseWayland), которое позволяет пользователям указать OpenTK игнорировать переменную окружения `OPENTK4_USE_WAYLAND` полностью, ведя себя так, будто она не установлена.

Эта таблица описывает поведение переменной `OPENTK4_USE_WAYLAND` для разных версий OpenTK:

| Версия OpenTK | Не установлена                                    | `OPENTK4_USE_WAYLAND=0`                       | `OPENTK4_USE_WAYLAND=1`                        |
|:--------------|:--------------------------------------------------|:----------------------------------------------|:-----------------------------------------------|
| `< 4.8.0`     | Игнорируется<br/>GLFW не поддерживает Wayland     | Игнорируется<br/>GLFW не поддерживает Wayland | Игнорируется<br/>GLFW не поддерживает Wayland  |
| `>= 4.8.0`    | Всегда X11                                        | Всегда X11                                    | Wayland<br/>если `XDG_SESSION_TYPE=wayland`    |
| `>= 4.9.1`    | X11 или Wayland<br/>в зависимости от платформы    | Всегда X11                                    | X11 или Wayland<br/>в зависимости от платформы |
