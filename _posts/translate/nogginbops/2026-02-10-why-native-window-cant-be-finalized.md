---
title: Почему NativeWindow не может быть финализирован
date: 2026-02-10 11:11:11 +0300
author: me
categories: [Переводы, NogginBops OpenTK Blog]
tags: [перевод, nogginbops, opentk, c#, opengl]
image: /assets/img/opentk.png
original:
    author:
        name: NogginBops
        url: https://nogginbops.github.io/
    post:
        title: Why NativeWindow can't be finalized
        url: https://nogginbops.github.io/opentk-blog/support-tips/2026/02/05/why-nativewindow-cant-be-finalized.html
---

> Пост может вводить в заблуждение, поскольку может создаться впечатление, что финализация окна это то, что вы _будете_ делать. Но, по факту, это Плохая Идея™. Врядли вам нужны окна, которые будут существовать какое-то неопределенное время, пока сборщик мусора не решит их финализировать - это был бы очень странный пользовательский опыт. Вместо этого мы можем рассматривать исключение в финализаторе [`NativeWindow`](https://opentk.net/api/OpenTK.Windowing.Desktop.NativeWindow.html) как своего рода механизм обнаружения утечек памяти, указывающий на то, что вы забыли должным образом освободить ресурсы. Таким образом, следует рассматривать ситуацию с другой точки зрения: почему [`NativeWindow`](https://opentk.net/api/OpenTK.Windowing.Desktop.NativeWindow.html) выбрасывает исключение, если вы не освобождаете ресурсы должным образом до его финализации?
{: .prompt-info }

В [предыдущей статье](https://nogginbops.github.io/opentk-blog/support-tips/2025/12/28/why-does-glfwprovider-checkformainthread-exist.html) мы рассмотрели `GLFWProvider.CheckForMainThread`. Там мы пришли к выводу, что большинство функций GLFW необходимо вызывать из основного потока. В этой статье мы рассмотрим еще одно следствие этого: [`NativeWindow`](https://opentk.net/api/OpenTK.Windowing.Desktop.NativeWindow.html) не может быть финализирован.

Если вы попытаетесь сделать это, позволив сборщику мусора удалить [`NativeWindow`](https://opentk.net/api/OpenTK.Windowing.Desktop.NativeWindow.html), вы столкнетесь с исключением `GLFWException`, содержащим следующее сообщение:

> You can only dispose windows on the main thread. The window needs to be disposed as it cannot safely be disposed in the finalizer.

> Окно может быть освобождено только в основном потоке. Окно должно быть освобождено, поскольку его нельзя безопасно освободить в финализаторе.

Так почему же это так? Ну, простой ответ лежит в [предыдущем посте](https://nogginbops.github.io/opentk-blog/support-tips/2025/12/28/why-does-glfwprovider-checkformainthread-exist.html): Большинство функций GLFW необходимо вызывать из основного потока. А финализаторы в C# запускаются не из основного потока, они запускаются в своем специальном [потоке финализации](https://devblogs.microsoft.com/dotnet/finalization-implementation-details/). Это означает, что мы не можем вызывать функции GLFW в финализаторе, а следовательно — не можем уничтожить окно GLFW. Вместо этого мы выбрасываем исключение, чтобы, как мы надеемся, уведомить программиста о его ошибке.

Но теперь вы можете спросить: Я не освобождаю [`NativeWindow`](https://opentk.net/api/OpenTK.Windowing.Desktop.NativeWindow.html), и у меня не происходит никаких сбоев, в чем же дело?

Что ж, dotnet не гарантирует, что сборщик мусора действительно выполнит финализатор объекта до завершения программы. Из [документации по финализаторам](https://learn.microsoft.com/en-us/dotnet/csharp/programming-guide/classes-and-structs/finalizers):

> … you can’t guarantee the garbage collector calls all finalizers before exit, you must use Dispose or DisposeAsync to ensure resources are freed.

> … вы не можете гарантировать, что сборщик мусора вызовет все финализаторы до завершения, вы должны использовать Dispose или DisposeAsync, чтобы гарантировать освобождение ресурсов.

Поэтому убедитесь, что вы освобождаете ресурсы вашего [`NativeWindow`](https://opentk.net/api/OpenTK.Windowing.Desktop.NativeWindow.html) либо с помощью `using`, либо вручную вызывая `.Dispose()`.
