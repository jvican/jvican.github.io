+++
title = "Pipelining your Scala compiles"
description = "Learn how pipelining speeds up your build"
date = "2017-10-19T23:29:12+02:00"
draft = true
+++

Last year, at Scalasphere 2017, Rory Graves gave a great presentation about
[improving compilation performance on Scalac][rorytalk].

In the talk, Rory goes through some of the changes he made to the compiler,
explains how impactful they were and shows how hard it is to make a difference in compilation performance.

My favorite part of the talk is at the end, when he pitches in a new idea to
get faster compilation times called *pipelined compilation*. Unlike other ideas
to speed up the compiler, pipelined compilation doesn't require fancy
profile-based optimizations, but mostly a change in how build tools compile
Scala projects.

To explain the idea, I first need to quickly introduce some high-level
concepts for those unfamiliar on how Scalac works.

## The Scala pickle information

The Scala compiler has different backends, but it has traditionally targeted
the Java Virtual Machine. The primary input of the Java Virtual Machine is
class files. Class files contain the bytecode (executable code that is
afterwards interpreted and compiled by the virtual machine) and some metadata
about the code.

These class files are also an input to the compiler and they are accessible
through the classpath. The Scala compiler takes some Scala source files and a classpath, and then outputs class files.

However, Scala is a richer language than Java --- and so class files cannot
encode rich, high-level type information that only the Scala compiler
understands.

As a result, the Scala compiler stores this high-level information as binary
data inside Scala-generated class files. This data is accessible via the
`ScalaSignature` annotation defined by the Scala compiler and so, every time the
compiler detects Scala-generated class files in its compilation classpath, it
reads this information and uses it to populate its symbol table.

The scala signature information is commonly called "Scala pickles", and the
process of reading and writing the data is referred to as "unpickling" and
"pickling".

### Example

Let's say we have the following projects:

=> **A**: `object Foo { type Bar = Int }`

=> **B**: `object Baz { val t: Foo.Bar = 2 }`

Note that `B` depends on `A`.

When you tell your build tool to compile `B`, the following happens:

1. Scalac compiles `A` with a classpath that only contains the Scala standard
   library and reflect. It then typechecks the code and generates a class file
   `Foo` with a scala pickle inside that represents the object `Foo` and all its
   inner members.
2. Scalac compiles `B` with `A`'s class files on its classpath. Before
   typechecking the code, it reads the Scala pickles from `A`'s class files and
   populates the symbol table. Now, the Scala compiler knows everything about
   `Foo` and can proceed with compilation and generate class files for `B`.


<hr>

One year later, I eventually put some time together to make a prototype that
makes pipelined compilation work in [Zinc][zinc] and exposes it to users via
[Bloop][bloop].

## Pipelined compilation

[zinc]: https://github.com/scalacenter/zinc
[bloop]: https://github.com/scalacenter/bloop
[rorytalk]: https://www.youtube.com/watch?v=QO1Hi8vwbCY
