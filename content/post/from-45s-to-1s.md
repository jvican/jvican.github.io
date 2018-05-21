+++
title = "From 45s to 1s compile times"
description = "A tour on profiling of compilation times to understand the cost of automatic generic derivation."
date = "2018-05-20T10:00:00+01:00"
+++

Today I explain how I've reduced compilation times dramatically
in one of the projects I've been working for the past months.

My goal is to explain how I:

1. identified the bottleneck of compilation;
1. profiled the compilation time of my application; and,
1. changed a few lines of code to get *much* better compile times.

A major part of this post goes to discussing **the cost of implicit search
and macro expansions**, describe what automatic type derivation is and why
both slow down compilation times.

After reading the blog post, you should understand:

* Why Shapeless-based code is prone to slow compilation times.
* How you can replicate a similar analysis of compilation times on code that
  abuses implicit searches and macros.
* How implicit search and macros interact in unexpected ways that hurt
  productivity and how you can optimize their interaction.
* Why semi-automatic type derivation is preferred over automatic type
  derivation, and how the latter should only be used with extreme care.

The most important take-away from this guide is that **you should not take
slow Scala compilation times for granted**.

In most of the cases, slow compilations originate from either an
unintentional misuse of a macro-based library, or an inefficient
implementation of a macro. You better catch them early so that they don't
kill the productivity of your team.

Put on your profiling hat and let's get our hands dirty.

## The codebase

[Bloop](https://github.com/scalacenter/bloop) is a *build-tool-agnostic*
compilation server with a focus on developer productivity that I develop at
the Scala Center together with [Martin Duhem](https://github.com/Duhemm). It
gives you about ~20-25% faster compilation times than sbt, and we plan on
further improving the performance of both batch and incremental compilation
in the next month.

Bloop is a small codebase with 10000 lines of Scala code.

```bash
jvican in /data/rw/code/scala/loop                                                                                                                                                                   [22:53:34] 
> $ loc --exclude zinc/* --exclude benchmark-bridge/*
-----------------------------------------------------------
 Language    Files     Lines     Blank   Comment    Code
-----------------------------------------------------------
 Scala         129     12383      1597      1210      9576
 JavaScript     30     12264      1643      1519      9102
 Markdown       72      9132      1079         0      8053
 CSS            10      5117       750        47      4320
 JSON           49      3028        10         0      3018
 Java           46      5576       825      1998      2753
 Python          4      1407       212        71      1124
 HTML           34      1223        74        47      1102
 C               1       899       133       184       582
 XML             5       285        26         2       257
 Bourne Shell    8       249        43        19       187
 Plain Text      1       203        33         0       170
 Protobuf        1       151        32        20        99
 Toml            3        83         5         2        76
 Makefile        2        39         7         8        24
 YAML            1        24         6         1        17
-----------------------------------------------------------
 Total         396     52063      6475      5128     40460
-----------------------------------------------------------
```

It has three main submodules:

1. `jsonConfig`: the module that defines the JSON schema of the configuration files.
1. `backend`: the module that defines the compiler-specific data structures and integrations.
1. `frontend`: the high level code that defines the internal task engine and nailgun integration.

The two first modules are lightweight and fast to compile. In a hot compiler,
their batch compilations take 2 or 3 seconds. However, compiling `frontend`
is more than 20x slower. This slowness is surprising given that `frontend` is
only about 6000 LOC, so [in
theory](https://developer.lightbend.com/blog/2017-06-12-faster-scala-compiler/)
it should be compiled in about 4 seconds.

`frontend` depends on
[`case-app`](https://github.com/alexarchambault/case-app/), a command-line
parsing library for Scala that uses
[Shapeless](https://github.com/milessabin/shapeless). In our case, the reason
why the compilation takes 60 seconds.

Waiting 60 seconds for a change to take effect (even under incremental
compilation) is a no-go. Long waits kill my productivity and get me out of
the zone, which affects my decision-making process a big deal.

In the past, I've also noticed that a slow workflow discourages me from
adding complete test suites (the more tests I add the more I need to wait to
compile) or making experiments in the code. That has rendered my experience
as an Scala developer less pleasant.

But this time I decided to fight Bloop compilation times, and documented my
experience so that you can too.

## The setup and workflow

To profile Bloop compilation times, we use Bloop itself to make sure that we
preserve hot compilers across all runs. You should be able to replicate the results
with sbt too, but make sure that every time you `reload` the build you warm
up the compiler at least 10 times.

To set up Bloop as a user, follow the installation instructions in [our
website](https://scalacenter.github.io/bloop/). You only need to install
Bloop and start the server. You then clone the Bloop codebase and generate
the configuration files.

```bash
git clone https://github.com/scalacenter/bloop
git submodule update --init
git checkout v1.0.0-M10
sbt bloopInstall
```

After that, running `bloop about` in the base directory of the Bloop codebase should work.

```bash
jvican in /data/rw/code/scala/loop
> $ bloop about
  _____            __         ______           __
 / ___/_________ _/ /___ _   / ____/__  ____  / /____  _____
 \__ \/ ___/ __ `/ / __ `/  / /   / _ \/ __ \/ __/ _ \/ ___/
___/ / /__/ /_/ / / /_/ /  / /___/ /__/ / / / /_/ /__/ /
____/\___/\__,_/_/\__,_/   \____/\___/_/ /_/\__/\___/_/

Bloop-frontend is made with love at the Scala Center <3

Bloop-frontend version    `1.0.0-M10`
Zinc version              `1.1.7+62-0f4ad9d5`
Scala version             `2.12.4`

It is maintained by Martin Duhem, Jorge Vicente Cantero.
```

### Compiling the codebase

All we'll do in the next sections is to compile the codebase several times
and see how the compilation times behave after applying our changes.

I recommend cleaning and compiling `frontend` sequentially at least 10 times
to get a stable hot compiler. After that, we'll do incremental compilation in
the files we change. I've done this for convenience; you should be able to
replicate the results with full compilation.

#### Start compilation on file change

```bash
bloop compile frontend -w
```

Now, let's get back to the theory.

## The analysis

The first step to analyze your compilation times is that you set your
intuitions aside. Before validating them, we're going to look at the raw
compiler data and let ourselves take decisions from there.

Profiling compilation times requires dedicated tools. There isn't much we can
get from using profilers like Yourkit or Java Flight Recorder because they show
the result of the inefficiencies, not the cause.

There are cases when knowing the hot methods, inspecting the heap or studying
GC statistics is useful. I've used this data in the past to find and fix
inefficiencies in the compiler. However, this guide is only concerned about
the misuse of language features, and so we need to take a higher-level
profiling approach.

### Compiler statistics

The compiler has built-in support for statistics *from 2.12.5 on*. This work
resulted from [a Scala Center Advisory Board
proposal](https://github.com/scalacenter/advisoryboard/blob/master/proposals/010-compiler-profiling.md)
about compiler profiling. Morgan Stanley, the creator of the document,
proposed the Scala Center to develop tools to help diagnose compilation
bottlenecks.

---

(For those that don't know how we work, Advisory Board members can make
project recommendations to the Scala Center. Every member encourages action
on the problems that are most important to them, and we take those
recommendations into account when deciding how to allocate our resources.
Donating to the Scala Center has its perks; your voice as a Scala shop can be
heard and we can work to fix the things that upset you and the Scala
community.)

Back then, I was interested in this topic and so the proposal was assigned to me.
My work on the compiler revolved around fixing the broken
implementation of statistics in 2.11.x and reducing the instrumentation
overhead. Afterwards, I created the tooling I use in this guide to profile
Scala programs.

---

Compiler statistics have both timers and counters that record data about the
most expensive compiler operations like subtype checks, finding members,
implicit searches, macro expansion, class file loading, et cetera. This data
is the perfect starting point to have a high-level idea of what's going on.

#### Setting statistics up

Enable compiler statistics by adding the `-Ystatistics` compiler flag to the
project you want to benchmark. *Note that you need to use 2.12.5 or above*.

Add the compiler flag to the field `options` inside the
`.bloop/frontend.json` json configuration file. When you save, Bloop will
automatically pick up your changes.

Let's now compile `frontend` with `bloop compile frontend -w` and have a look
at the data.

{{< figure src="/data/bloop-profile-0.svg" title="Initial flamegraph" >}}
{{< figure src="/data/bloop-profile-1.svg" title="Flamegraph after cached implicits" >}}
{{< figure src="/data/bloop-profile-2.svg" title="Final flamegraph" >}}