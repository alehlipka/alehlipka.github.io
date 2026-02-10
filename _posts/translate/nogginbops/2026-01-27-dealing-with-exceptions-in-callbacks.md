---
title: Работа с исключениями в обратных вызовах (колбэках)
date: 2026-01-27 11:11:11 +0300
author: me
categories: [Переводы, NogginBops OpenTK Blog]
tags: [Перевод, NogginBops, OpenTK, C#, OpenGL, GLFW, NativeWindow]
image: /assets/img/opentk.png
original:
    author:
        name: NogginBops
        url: https://nogginbops.github.io/
    post:
        title: Dealing with exceptions in callbacks
        url: https://nogginbops.github.io/opentk-blog/support-tips/2025/12/20/dealing-with-exceptions-in-callbacks.html
---

В [предыдущем посте](https://nogginbops.github.io/opentk-blog/support-tips/2025/12/17/exceptions-and-pinvoke.html) мы остановились на том, что OpenTK в некоторой степени обрабатывает повторную генерацию исключений. В этом посте мы рассмотрим, что это означает.

В предыдущем посте мы пришли к выводу, что генерация исключений в коллбэках, вызываемых из нативного кода, — это плохая идея™, и что код должен гарантировать, что этого не произойдет. Я также предложил перехватывать любые исключения, генерируемые в коллбэке, а затем повторно генерировать их после возврата из нативного кода.

И это действительно то, что делает OpenTK, просто не для обработчика ошибок GLFW. Для всех событий, входящих в состав `NativeWindow`, используется такое поведение перехвата и повторного выбрасывания исключений. Мы можем убедиться в этом, посмотрев [код одного из этих обработчиков](https://github.com/opentk/opentk/blob/eab65e5c34abec4673b4672256e0e6c86018e3ad/src/OpenTK.Windowing.Desktop/NativeWindow.cs#L1220-L1230):

``` csharp
private unsafe void WindowPosCallback(Window* window, int x, int y)
{
    try
    {
        OnMove(new WindowPositionEventArgs(x, y));
    }
    catch (Exception e)
    {
        _callbackExceptions.Enqueue(ExceptionDispatchInfo.Capture(e));
    }
}
```
Ключевой API, который мы здесь используем, — это [`ExceptionDispatchInfo.Capture`](https://learn.microsoft.com/en-us/dotnet/api/system.runtime.exceptionservices.exceptiondispatchinfo.capture?view=net-10.0), позволяющий получить [`ExceptionDispatchInfo`](https://learn.microsoft.com/en-us/dotnet/api/system.exception?view=net-10.0), что даст нам возможность повторно сгенерировать это исключение с указанием исходного местоположения и трассировки стека, из которого оно было сгенерировано. Добавление этой информации о диспетчеризации в список позволит нам повторно сгенерировать эти исключения после возврата из нативного кода.

Это возможно для `NativeWindow`, но не для коллбэка ошибок GLFW, потому, что любая функция в GLFW может вызывать коллбэк ошибок GLFW. Это означает, что нам пришлось бы добавлять проверку на повторную генерацию исключения после каждого вызова функции GLFW, что добавило бы дополнительную нагрузку для обработки случаев, которые не могут произойти. Однако коллбэки событий `NativeWindow` срабатывают только в ответ на вызов `glfwPollEvents` и аналогичных функций (называемых [`ProcessWindowEvents`](https://opentk.net/api/OpenTK.Windowing.Desktop.NativeWindow.html#OpenTK_Windowing_Desktop_NativeWindow_ProcessWindowEvents_System_Boolean_) в `NativeWindow`). Таким образом, для этих коллбэков существует лишь несколько функций, в которых нам нужно проверять, нужно ли повторно генерировать исключения.

Однако есть одна сложность. Поскольку GLFW не может получать информацию об исключениях от OpenTK или C#, GLFW не будет знать о том, что было выброшено исключение, и продолжит обработку событий в обычном режиме, потенциально вызывая другие функции обратного вызова, прежде чем, наконец, вернуться к коду C#, который запустил обработку событий, и только тогда будет вызван обработчик исключения. Это делает ситуацию очень сложной для правильного решения, поскольку некоторые функции обратного вызова могут вызываться в "некорректном" состоянии.

Так что же делать? Простое решение — полностью избегать необработанных исключений в функциях обратного вызова. Таким образом, вы избежите всех этих тонкостей.
