+++
date = "2017-03-27T23:29:12+02:00"
title = "Informal introduction"
draft = true

+++

Hello, I am Jorge.

The idea is simple: your code is compiled many times (e.g. during CI builds) and results are usually trashed. Instead, it's better to distribute classfiles (together with the cached compilation metadata) and don't repeat this work again and again.

Using caches will not make your local workspace read-only. Once a cache is imported, it will work exactly as locally compiled one (all following compilations will be normal, incremental ones).
