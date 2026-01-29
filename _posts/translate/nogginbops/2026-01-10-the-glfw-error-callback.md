---
title: Функция обратного вызова для обработки ошибок GLFW
description: Перевод поста NogginBops "The GLFW error callback"
date: 2026-01-10 11:11:11 +0300
author: me
categories: [Переводы, NogginBops OpenTK Blog]
tags: [перевод, nogginbops, opentk, c#, opengl]
image:
  path: https://repository-images.githubusercontent.com/14318990/43286d80-888d-11e9-9cab-284d7197615b
---

**Пост не является авторским и/или официальным**  
**Ссылка на оригинал:** [The GLFW error callback](https://nogginbops.github.io/opentk-blog/support-tips/2025/12/16/the-glfw-error-callback.html)  
**Автор оригинала:** [NogginBops](https://nogginbops.github.io/)  

В этом посте я расскажу об обратном вызове ошибок GLFW и о том, зачем вам может понадобиться установить свой собственный.

Поскольку GLFW — это C API, он не использует исключения для передачи ошибок. Вместо этого в нём применяется обратный вызов ошибок (error callback), который вызывается при возникновении ошибки. Важно помнить, что в GLFW ошибки не являются фатальными до тех пор, пока успешно выполнена функция [`glfwInit()`](https://www.glfw.org/docs/3.3/group__init.html#ga317aac130a235ab08c6db0834907d85e). Вещи могут работать некорректно, но они не приведут к падению процесса или потока.

Вот выдержка из [документации GLFW](https://www.glfw.org/docs/3.3/intro_guide.html#error_handling):

> **Reported errors are never fatal**. As long as GLFW was successfully initialized, it will remain initialized and in a safe state until terminated regardless of how many errors occur. If an error occurs during initialization that causes glfwInit to fail, any part of the library that was initialized will be safely terminated.

> **Сообщаемые ошибки никогда не являются фатальными**. Если инициализация GLFW прошла успешно, библиотека останется в рабочем и безопасном состоянии до момента её завершения, независимо от количества возникших ошибок. Если же ошибка происходит во время инициализации и приводит к неудаче вызова glfwInit, все успешно инициализированные части библиотеки будут безопасно завершены.

Однако, взглянув на [стандартную функцию обратного вызова в OpenTK](https://github.com/opentk/opentk/blob/eab65e5c34abec4673b4672256e0e6c86018e3ad/src/OpenTK.Windowing.Desktop/GLFWProvider.cs#L27-L30), мы видим следующее:

``` csharp
private static void DefaultErrorCallback(ErrorCode errorCode, string description)
{
    throw new GLFWException($"{description} (this is thrown from OpenTKs default GLFW error handler, if you find this exception inconvenient set your own error callback using GLFWProvider.SetErrorCallback)", errorCode);
}
```

Она просто выбрасывает исключение `GLFWException` при каждой ошибке. Но если ошибки GLFW не фатальны, зачем вообще выбрасывать исключение? Для наглядности. Большинство ошибок GLFW означают, что пользователь делает с API что-то, чего делать не следует, и часто имеет смысл как можно быстрее показать эти ошибки пользователю.

Однако это не так актуально в случае с Wayland. Поскольку некоторые возможности GLFW невозможно реализовать на Wayland (например, [`glfwGetWindowPos`](https://www.glfw.org/docs/latest/group__window.html#ga73cb526c000876fd8ddf571570fdb634)), GLFW будет выдавать ошибку [`ErrorCode.FeatureUnavailable`](https://opentk.net/api/OpenTK.Windowing.GraphicsLibraryFramework.ErrorCode.html) при попытке использовать такие возможности. Это означает, что программы, которые обычно не вызывают ошибок на других платформах, внезапно могут вызвать множество ошибок (error callback) в Wayland.

Это одна из причин, по которой может быть полезен пользовательский обработчик ошибок. Как для целей логирования (поскольку он предоставляет приложению достаточно информации для самостоятельного ведения логов), так и из-за особенностей Wayland, из-за которых GLFW сообщает об ошибках там, где обычно их нет.

"Так как же установить свой собственный обработчик ошибок?" — спросите вы. Это очень просто: используйте [`GLFWProvider.SetErrorCallback`](https://opentk.net/api/OpenTK.Windowing.Desktop.GLFWProvider.html#OpenTK_Windowing_Desktop_GLFWProvider_SetErrorCallback_OpenTK_Windowing_GraphicsLibraryFramework_GLFWCallbacks_ErrorCallback_):

``` csharp
// Определяем собственную функцию обратного вызова ошибок.
private static void MyErrorCallback(ErrorCode errorCode, string description)
{
    if (errorCode == ErrorCode.FeatureUnavailable)
    {
        Console.WriteLine($"GLFW feature unavailable: {description}");
    }
    else
    {
        throw new GLFWException($"{description} (this is thrown from OpenTKs default GLFW error handler, if you find this exception inconvenient set your own error callback using GLFWProvider.SetErrorCallback)", errorCode);
    }
}

// Устанавливаем нашу функцию обратного вызова ошибок.
GLFWProvider.SetErrorCallback(MyErrorCallback);
```
