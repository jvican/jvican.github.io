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
why the compilation takes 30 seconds.

Waiting 30 seconds for a change to take effect (even under incremental
compilation) is a no-go. It may not seem much, but such a long waits kill my
productivity and get me out of the zone, which affects my decision-making
process a big deal.

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

#### Warm up the compiler

```bash
for i in {1..10}; do
  echo "Warming up the compiler; iteration $i"
  bloop compile frontend -w
done
```

## The analysis

The first step to analyze your compilation times is that you set your
intuitions aside. We're going to look at the raw compiler data with fresh
eyes and see where that leads us.

If you try to validate previously-formed assumptions, it's likely you'll be
misleaded by the data. I've been there, so don't fall into the same trap.

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

Compiler statistics have both timers and counters that record data about
expensive compiler operations like subtype checks, finding members, implicit
searches, macro expansion, class file loading, et cetera. This data is the
perfect starting point to have a high-level idea of what's going on.

#### Setting statistics up

Enable compiler statistics by adding the `-Ystatistics` compiler flag to the
project you want to benchmark. *Note that you need to use Scala 2.12.5 or
above*. I **highly** recommend using the latest version. At the moment of
this writing, that's `2.12.6`.

Add the compiler flag to the field `options` inside the
`.bloop/frontend.json` json configuration file. When you save, Bloop will
automatically pick up your changes and add the compiler option without the
need of a `reload`.

Run `bloop compile frontend -w --reporter scalac` (we use the default scalac
reporter for clarity) and have a look at the data. The output of the
compilation will be [similar to this log](/data/bloop-compile-stats-0.txt).
Check the end of it. You should see a report of compilation time spent per
phase.

```
*** Cumulative timers for phases
#total compile time      : 1 spans, ()32545.975ms
  parser                 : 1 spans, ()65.017ms (0.2%)
  namer                  : 1 spans, ()42.827ms (0.1%)
  packageobjects         : 1 spans, ()0.187ms (0.0%)
  typer                  : 1 spans, ()27432.596ms (84.3%)
  patmat                 : 1 spans, ()1169.028ms (3.6%)
  superaccessors         : 1 spans, ()36.02ms (0.1%)
  extmethods             : 1 spans, ()3.548ms (0.0%)
  pickler                : 1 spans, ()9.449ms (0.0%)
  xsbt-api               : 1 spans, ()159.278ms (0.5%)
  xsbt-dependency        : 1 spans, ()94.846ms (0.3%)
  refchecks              : 1 spans, ()627.633ms (1.9%)
  uncurry                : 1 spans, ()408.305ms (1.3%)
  fields                 : 1 spans, ()414.151ms (1.3%)
  tailcalls              : 1 spans, ()38.455ms (0.1%)
  specialize             : 1 spans, ()184.562ms (0.6%)
  explicitouter          : 1 spans, ()80.488ms (0.2%)
  erasure                : 1 spans, ()624.472ms (1.9%)
  posterasure            : 1 spans, ()63.249ms (0.2%)
  lambdalift             : 1 spans, ()125.944ms (0.4%)
  constructors           : 1 spans, ()47.109ms (0.1%)
  flatten                : 1 spans, ()46.527ms (0.1%)
  mixin                  : 1 spans, ()59.808ms (0.2%)
  cleanup                : 1 spans, ()42.336ms (0.1%)
  delambdafy             : 1 spans, ()47.771ms (0.1%)
  jvm                    : 1 spans, ()714.008ms (2.2%)
  xsbt-analyzer          : 1 spans, ()5.175ms (0.0%)
```

The report suggests that about **84.3% of the compilation time** is spent on
typer. This is an unusual high value. Typechecking a normal project is
expected to take around 50-60% of the whole compilation time.

If you have a higher number than the average, then it most likely means
you're pushing the typechecker hard in some unexpected way, and you should
keep on the exploration.

### Walking into the lion's den

Now that the data signals a bottleneck in typer, let's keep our statistics
log short and enable `-Ystatistics:typer`. That will report only statistics
produced during typing.

We then run compilation again. The logs contain information about timers and
counters of several places in the typechecker. These timers and counters help
you know how you're stressing the compiler.

If the compilation of your program requires an unusual amount of subtype
checks, `time spent in <:<` will be high. There are no normal values for
subtype checks --the time spent here depends on a lot of factors-- but an
abnormal value would be anything above to 15% of the whole typechecking time.

The first thing we notice when studying the logs is that typechecking
`frontend` takes 28 seconds. We also see some unusual values for the
following counters:

```json
#class symbols             : 1842246
#typechecked identifiers   : 134734
#typechecked selections    : 225020
#typechecked applications  : 82421
```

The Scala compiler creates almost two million class symbols (!) and
typechecks 134734 identifiers, almost the double of selections and half of
applications. Those are pretty high values. That begs the question: why are
we creating so many classes?

Next, we check time spent in common typechecking operations:

```
time spent in lubs         : 67 spans, ()63.194ms (0.2%) aggregate, 16.29ms (0.1%) specific
time spent in <:<          : 1548620 spans, ()1791.068ms (6.5%) aggregate, 1583.94ms (5.8%) specific
time spent in findmember   : 873498 spans, ()638.792ms (2.3%) aggregate, 592.663ms (2.2%) specific
time spent in findmembers  : 0 spans, ()0.0ms (0.0%) aggregate, 0.0ms (0.0%) specific
time spent in asSeenFrom   : 2541823 spans, ()1299.199ms (4.7%) aggregate, 1238.814ms (4.5%) specific
```

`time spent in lubs` should be high whenever you use lots of pattern matching
or if expressions, and the compiler needs to lub (find the common type of a
sequence of types -- also called finding "least upper bound" among some
types). Eugene Yokota explains it well [in this well-aged blog
post](http://eed3si9n.com/stricter-scala-with-ynolub).

`time spent in findmember` and it's sister `time spent in findmembers` should
be up in the profiles whenever you have deep class hierarchies and lots of
overridden methods.

`time spent in asSeenFrom` is high whenever your code makes a heavy use of
dependent types, type projections or abstract types in a more general way.

In the case of `frontend`, the durations of all these operations are
reasonable, which hints us that the inefficiency is elsewhere.

(For most of the cases, these timers are unlikely to be high when typechecking
your program. If they are, try to figure out why and file a ticket in
`scala/bug` so that either I or the Scala team can look into it.)

### The troublemaker

Most of the projects that suffer from compilation times abuse or misuse
either macros (for example, inefficient macro implementations that do a lot
of `typecheck`/`untypecheck`), implicit searches (for example, misplaced
implicit instances that take too long to find) or a combination of both.

It's difficult to miss how long macro expansion and implicit searches take in
the compilation of `frontend`, and how the values seem to be highly
correlated.

```
time spent implicits   : 33609 spans, ()26808.491ms (97.7%)
  successful in scope  : 346 spans, ()71.931ms (0.3%)
  failed in scope      : 33263 spans, ()3195.452ms (11.6%)
  successful of type   : 18286 spans, ()26730.255ms (97.4%)
  failed of type       : 14977 spans, ()17370.235ms (63.3%)
  assembling parts     : 18647 spans, ()374.562ms (1.4%)
  matchesPT            : 136322 spans, ()505.763ms (1.8%)
time spent macroExpand : 44445 spans, ()26451.132ms (96.4%)
```

This is a red flag. We expand around 44500 macro expansions (!) and spend
almost the totality of the macro expansion time searching for implicits.
We have our troublemaker.

### Profiling implicit search

How do we know which implicit searches are the most expensive? What are the
macro expansions that dominate the compile time?

The data we get from `-Ystatistics` doesn't help us answer these questions,
even though they are fundamental to our analysis. As users, we treat macros
as blackboxes ---mere building blocks of our library or application--- and
now we need to unravel them.

#### A profiling plugin for `scalac`

To answer the previous questions, we're going to use
[scalac-profiling](https://github.com/scalacenter/scalac-profiling), a
compiler plugin that exposes more profiling data to Scala developers.

I wrote the plugin with three goals in mind:

* Expose a common file format that encapsulates all the compilation profiling
  data, called `profiledb`.
* Use visual tools to ease analysis of the data (e.g. flamegraphs).
* Allow third parties to develop tooling to integrate this data in IDEs and editors.
  There is a rough `vscode` prototype working.

The compiler plugin hooks into several parts of the compiler to extract
information related to implicit search and macro expansion. This data will
prove instrumental to understand the interaction between both features.

Install `scalac-profiling` by fetching the latest `6cac8b23` release.

```bash
$ coursier fetch ch.epfl.scala:scalac-profiling_2.12:6cac8b23 --intransitive
```

Then open the `frontend`'s bloop configuration file and add the following
compiler options in the `options` field. Note that `-Xplugin` contains the
`$PATH_TO_PLUGIN_JAR` variable which you must replace with the resolved
artifact from coursier. Replace `$BLOOP_CODEBASE_DIRECTORY` by the base
directory of the cloned bloop repository.

```json
  "-Xplugin:$PATH_TO_PLUGIN_JAR",
  "-P:scalac-profiling:no-profiledb",
  "-P:scalac-profiling:show-profiles",
  "-P:scalac-profiling:sourceroot:$BLOOP_CODEBASE_DIRECTORY"
```

The flag `no-profiledb` disables the generation of `profiledb`s and
`sourceroot` tells the plugin the base directory of the project. The
profiledb is only required when we process the data with other tools, so by
disabling it we keep the overhead of the plugin to the bare minimum.

The flag `show-profiles` displays the following data in the compilation logs:

* Implicit searches by position. Useful to know how many implicit searches were
  triggered per position.
* Implicit searches by type. Essential data to know how many implicit searches
  were performed for a given type and how much time they took.
* Repeated macro expansions. An optimistic counter that tells us how many of
  the macros returned the same stringified AST nodes and could therefore be
  cached across all use-sites (in the macro implementation).
* Macro data in total, per file and per call-site. The macro data contains how
  many invocations of a macro were performed, how many AST nodes were
  synthesized by the macro and how long it took to perform all the macro
  expansions.

The profiling logs will be large, so make sure the buffer of your terminal is
big enough so that you can browse through them.

When you've added all the compile options to the configuration file and
saved it, the next compilation will output a log [similar to this
one](bloop-compile-0.txt). This is the profiling data we're going to dive into.

#### The first visual

First thing you notice from the data: compilation time has gone up. Don't
worry, you haven't done anything wrong.

```
```

Using a compiler plugin has a compilation overhead, so this behaviour is
expected. The cost is due to [dynamic plugin
classloading](https://github.com/scala/scala/pull/6314) and the cost of the
profiling itself. There are some solutions to this, but let's leave that to
another blog post.

The first thing we need is to get a visual of the implicit searches. To do
that, we're going to create an implicit search flamegraph. Grep for the line
"Writing graph to" in the logs to find the `.flamegraph` file containing the
data.

---

##### Learn to generate a flamegraph

To generate a flamegraph, clone
[brendangregg/FlameGraph](https://github.com/brendangregg/FlameGraph), and
then run the following script in the repository:

```bash
./flamegraph.pl --countname="ms" \
                --colors=mem \
                $PATH_TO_FLAMEGRAPH_PLUGIN_DATA > bloop-profile-initial.svg
```

You can then visualize it with `$BROWSER bloop-profile-initial.svg`.

---

After we're all set up, we'll then get an `svg` file that looks like this:

{{< figure src="/data/bloop-profile-0.svg" title="Initial flamegraph of implicit search in `fronten`" >}}

(The flamegraph is shown as an image but it's an svg. Open the image in a new
tab to be able to hover on every stack, search through the stack entries and
check the compilation times of every box.)

What a beautiful graph. We finally have a visual of all the implicit searches
our program is doing, and how their dependencies look like.

Before we keep fiddling with the graph, let's learn about common implicit and
macro usage patterns and which kind of inefficiencies we're after.

#### Type derivation and its dangers

Type derivation is a process that synthesizes types (usually, typeclasses)
for other types. The process can be manual (you defined an `Encoder` for
every node of your GADT) or automatic (the `Encoder` derivation happens at
compile time via macros and implicits, i.e. the compiler generates the code
for you).

There are two families of automatic type derivation:

* Automatic: all the type dependencies of the type you derive will be
  materialized by the compiler.
* Semi-automatic: the type dependencies of the type you derive need to exist
  for the derivation to succeed.

Type derivation is popular in the Scala community. A few libraries (for
example, `scalatest`) define their own macros to synthesize type classes. All
the other libraries use Shapeless to guide the type derivation on the library
side, which removes the need for extra macros.

Shapeless is a Scala compile-time framework that defines the basic building
blocks to make computations at the typelevel. These computations are
inductive and happen during compilation time via implicit search. Shapeless
is popular for automatic type derivation, so when the implicit search needs
an instance that doesn't exist in the scope, macros materialize it.

The compilation of `frontend` requires type derivation via `case-app`, which
depends on Shapeless. `case-app` derives a `caseapp.core.Parser` for a GADT
defining the commands and parameters that your command line interface
accepts. This derivation relies on the `Lazy`, `Strict`, `Tagged` and
`LabelledGeneric` macros, as well as other foundation blocks like `Coproduct`
and `HList`.

These are normal dependencies of any library that uses Shapeless to guide
type derivation.

The most common inefficiency in this kind of program is repeated
materialization of implicit instances via macros. It usually happens in any
library that uses automatic type derivation. So if you're using Shapeless for
anything (and do check your classpath, you never know), there is some hope
you can make some cuts in your compile times.

{{< figure src="/data/bloop-profile-1.svg" title="Flamegraph after cached implicits" >}}
{{< figure src="/data/bloop-profile-2.svg" title="Final flamegraph" >}}