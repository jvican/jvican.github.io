<!--*-markdown-*-->
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
<meta http-equiv="X-UA-Compatible" content="IE=edge,chrome=1">
<meta name="author" content="Jorge Vicente Cantero">

<!-- Change this whenever a new blog post is done -->
<meta property="og:title" content="Integrate Bloop with Bazel/Pants" />
<meta property="og:description" content= "" />
<meta property="og:type" content="article" />
<meta property="og:url" content="https://jvican.github.io/" />

<meta name="twitter:card" content="summary"/>
<meta name="twitter:title" content="jvican"/>
<meta name="twitter:description" content=""/>
<meta name="twitter:site" content="@https://www.twitter.com/jvican"/>

<link rel="stylesheet" href="../css/monosocialiconsfont.css">
<link rel="shortcut icon" href="../images/favicon.ico">
<link rel="stylesheet" type="text/css" media="all" href="../css/styles.css">
<link rel="stylesheet" type="text/css" media="all" href="../css/syntax-highlighting.css">
<link rel="stylesheet" type="text/css" media="all" href="../css/et-book.css">
<link href="//cloud.typenetwork.com/projects/3124/fontface.css/" rel="stylesheet" type="text/css">
<script async defer data-domain="jorge.vican.me" src="https://plausible.io/js/plausible.js"></script>

<title>
Integrate Bloop with Bazel/Pants
</title>
</head>
<body>
<div id="top-stripe"></div>
<div> <!-- required as a simple wrapper for position:absolute to work -->
<div class="home-arrow">
<a href="../index.html">
<span>←</span>
Back
</a>
</div>
</div>

<div id="content">
<div id="doc">

# Integrate Bloop with Pants/Bazel

What is the future of build tools such as Pants and Bazel in the Scala community?
Can we accelerate the adoption rate by integrating these tools with the existing tooling ecosystem?

## Tools 101

Bloop is a Scala build server that compiles, tests and runs Scala fast.

Pants and Bazel are scalable language-agnostic build systems. They support
Scala and also need to compile, test and run Scala fast.

Why would we want Bazel and Pants to integrate with Bloop? How could such an
integration work given the seemingly competing goals of both tools?

This article answers these questions and summarizes my excellent discussions
with [Natan][] (contributor to the Bazel Scala rules @ Wix) and [Stu][],
[Danny][] and [Win][] (core maintainers of Pants @ Twitter) during [Scala
Days 2019][scaladays].

## Motivation

There are **three** main arguments to motivate the integration.

### #1: Straight-forward integration with editors

Adoption of build tools is limited by how well they integrate with existing
developer tools. For example, how well you can use them from an
editor.

Currently, Pants and Bazel only support [IntelliJ IDEA][idea] via their
custom IDEA plugins. These integrations are difficult to build, test and
maintain.

Bloop provides Bazel and Pants a quick way to integrate with the vast
majority of editors used in the Scala community: [IntelliJ IDEA][idea] via
the built-in BSP support in `intellij-scala` and VS Code, Vim, Emacs, Sublime
Text 2, and Atom via
[Metals](https://www.scala-lang.org/2019/04/16/metals.html).

The integration is easy to build, test and maintain, it relieves build tool
maintainers from implementing specific editor support for users and allows
sharing improvements in editors support across build tools.

### #2: Faster local developer workflows

Bazel and Pants promise reproducible builds. Reproducibility is a key
property of builds. It gives developers confidence to deploy their code and
reason about errors and bugs.

To make compilation reproducible, incremental compilation is disabled and
build requests trigger a full compilation of a target `foo` every time:

1. One of the build inputs of `foo` is modified (such as a source)
2. Users ask for build tool diagnostics or a compilation of `foo`

A best practice in Bazel and Pants is to create fine-grained build targets of
a handful of sources. Fine-grained build targets help reduce the overhead of
full compiles: they compile faster, increase parallel compilations and enable
incremental compilation at the build target level.

However, even under ideal compilation times of 1 or 2 seconds per compiled
build target, there are scenarios where instant feedback cannot be achieved:

1. Language servers such as Metals that forward diagnostics from Bazel and
   Pants will take 1 or 2 seconds at best to act on diagnostics, making the
   slowdown noticeable to users.
   * Metals also needs class files/semanticdb files to provide a rich editing
     experience (go to definition, find all references).
1. Common scenarios such as changing a binary API can trigger many
   compilations downstream that take a long time to finish, slowing down even
   more the build diagnostics in the editor.

An integration with Bloop speeds up local developer workflows by allowing
local build clients (such as editors) to trigger incremental compiles while
isolating these compiles completely from Bazel or Pants.

In practice, this means build clients such as Metals can use Bloop to receive
build diagnostics fast (in the order of 50-100ms) and collect class files in
around 400-500ms, meaning developers feel instant feedback from the build
tool.

And Bloop guarantees compilation requests from Bazel and Pants will:

* Trigger a full compile per build target (same output for same input)
* Never conflict with other client actions
* Can be reused by clients that want fast, incremental compiles

(These guarantees are unlocked by the latest [Bloop v1.3.2 release](tweet-1.3.2).)

Integrating with Bloop brings Bazel/Pants users the best of both "worlds":

1. Bazel and Pants can still offer *reproducible builds* to users with *no cache
   pollution*. The cache engine in Bazel and Pants only gets to "see" class
   files produced by full compilations.
2. Developers sensitive to slow feedback in the editor can opt-in for
   incremental compiles from their editor in a local machine. In case of rare
   incremental errors, they can trigger a compilation from the build tool
   manually to restore a clean state.
3. Developers that don't want to compromise build reproducibility to get
   faster workflows can enable a Bloop configuration setting to keep using full
   compiles from their editor, while still getting faster compiles than they
   would if they used the compilation engine from Pants or Bazel.

### #3: State-of-the-art compilation engine

Currently, the Scala rules in Bazel and Pants implement their own compilation
engine, interface directly with internal Scala compiler APIs and have a high
memory and resource usage footprint because they spawn a JVM server that
cannot be reused by external build clients.

The advantages of using Bloop to compile Scala code are the following:

1. **Speed**. Bloop implements a compilation engine that:
   1. is the fastest to this date
   1. has been tweaked to have the best performance defaults
   1. uses build pipelining to speed up full build graph compilations
   1. is benchmarked in 20 of the biggest Scala open source projects
   1. is continuosly improved and maintained by compiler engineers
1. **Supports pure compilation**. Bloop can recompile build targets
   from scratch if it's told to do so by the build tools.
1. **Minimal use of resources**. Bloop can be reused by any local build
   client, including those from other build tools and workspaces.
1. **Lack of maintenance**. The compilation engine doesn't need to be
   maintained by neither the Bazel nor the Pants team.
1. **Simple integration**. The integration is done via the Build Server
   Protocol, which requires only a few hundred lines of code and is decoupled
   from any change in the compiler binary APIs.

## How to integrate with Bloop

There are several ways to integrate Bloop and Pants/Bazel with varying
degrees of functionality.

Which integration is the best ultimately depends on what clients want/don't
want to give up and what are the key motivations behind the integration. The
move from one integration oto another one can be done gradually.

### Barebone integration: only generating `.bloop/`

Bloop loads a build by reading [Bloop configuration
files][configuration-file] from a `.bloop/` directory placed in the root
workspace directory.

A configuration file is a JSON file that aggregates all of the build inputs
Bloop needs to compile, test and run. It is written to a directory in the
file system to simplify access and caching when the build tool is not running
but other clients are. Every time a configuration file in this directory
changes, the Bloop server automatically reloads its build state.

A barebone integration is the simplest Bloop integration: Pants or Bazel
generate Bloop configuration files to a `.bloop` directory. Whenever there is
a change in a build target, Bazel or Pants regenerate its configuration file
again.

Here's a diagram illustrating the barebone integration.

![](../images/bazel-pants-first-integration.svg)

Note that:

1. There are several clients talking to Bloop manned by developers
1. The build tool and Bloop use different compilers/state
1. Bazel/Pants write configuration files, Bloop only reads them
1. `.bloop` is the workspace directory where files are persisted

#### Pros

1. Easy to prototype ([Danny] and I implemented it in Pants in 4 hours)
1. Out-of-the-box integration with Metals and CLI (motivation #1)

#### Cons

1. Requires writing all configurations to a `.bloop/` in the workspace.
1. The Bloop compiles are not integrated with those of the build tool. This
   implies that this solution doesn't satisfy users that want:
   * A faster developer workflow (motivation #2)
   * A state-of-the-art compilation engine (motivation #3)
   <p>
   because the build tool and Bloop use their own compilers.

### BSP integration: generating `.bloop/` and talking BSP

To enable a solution that not only provides the possibility of using
Bazel/Pants from any editor but also has a faster developer workflow than the
status quo, we need to look at ways we can enable Bloop to do the
heavy-lifting of compilation.

In a way, Bazel and Pants become build clients to the BSP build server in Bloop:

1. A compile in Bazel or Pants maps to a compile request to Bloop
1. Bazel and Pants receive compilation logs and class files from Bloop

The following diagram illustrates how the architecture looks like:

![](../images/bazel-pants-bsp-integration.svg)

We can see that Bazel / Pants no longer own compilers and that they instead
communicate with the Bloop server via [BSP][bsp]. To implement that, the
build tools can use `bsp4j`, a tiny Java library that implements the protocol
and allows the client to listen to all results/notifications from the build
tool.

There are, however, different ways Bazel or Pants can offload compilation to
Bloop. Let's illustrate both of them with a simple build.

![](../images/build-graph-example.svg)

The straight-forward mechanism to offload compilation is to let the
Bazel/Pants build tool drive the compilation itself.

Upon the *first* compilation of a target `C`, the build tool would:

1. Make sure there is an open BSP connection with the Bloop server.
   * If not, the [Bloop Launcher][launcher] will start it
1. Visit `C`, find dependency `B` is not compiled.
1. Visit `B`, find dependency `A` is not compiled.
1. Visit `A`, no more dependencies, then:
   1. Generate configuration file for `A`
   1. Send Bloop compile request for `A` to write class files
1. Come back to `B`, no more uncompiled dependencies, then:
   1. Generate configuration file for `B`
   1. Send Bloop compile request for `B` to write class files
1. Come back to `C`, no more uncompiled dependencies, then:
   1. Generate configuration file for `C`
   1. Send Bloop compile request for `C` to write class files

(The build tool can safely visit a build graph in parallel.)

This mechanism works if one wants the build tool to own and control the way
compilations are run, but it's slower than letting Bloop compile a subset of
the build graph on its own, where Bloop can (among other actions):

* Start the compilation of a project before its dependencies are finished
  (e.g. start compiling `B` right after `A` is typechecked). This is the
  so-called build pipelining.
* Compile faster by populating symbols from in-memory stores instead of
  reading class files from the file system.
* Amortize the cost of starting a compilation by compiling a list of build
  targets at the same time.

The build tool could benefit from all of these actions by just changing how
it maps compilation requests to the Bloop BSP server:

1. Make sure there is an open BSP connection with the Bloop server.
   * If not, the [Bloop Launcher][launcher] will start it
1. Visit `C`, find dependency `B` has no config.
1. Visit `B`, find dependency `A` has no config.
1. Visit `A`, no more dependencies, then generate config for `A`
1. Come back to `B`, no more dependencies, generate config for `B`
1. Come back to `C`, no more dependencies, generate config for `C`
1. Send a Bloop compile request from `C`.
   * Bloop will start compiling the build graph *in the background*.
   * After building a target, Bloop sends a notification to client.
1. Visit `B`, find dependency `A` is not compiled.
1. Visit `A`, wait for Bloop's end notification for `A`.
1. Come back to `B`, wait for Bloop's end notification for `B`.
1. Come back to `C`, wait for Bloop's end notification for `C`.

Right after receiving the notifications from the server, the build tool will
find all the compilation products written in the classes directory specified
in the configuration file. Meaning the build tool can immediately start
evaluating tasks that depend on compilation products for that project.

(Sbt will offload compilation to Bloop by following this strategy in the next
Bloop release.)

#### Pros

1. Out-of-the-box integration with Metals and CLI (motivation #1)
1. A faster local developer workflow (motivation #2)
1. A state-of-the-art compilation engine that compiles the build graph as
   fast as possible for the build tool, with a simple protocol that decouples
   the build tools from compiler internals

#### Cons

1. Not as straight-forward to implement as the first shallow integration, but
   still doable and abstracted away from compiler internals.
1. Requires writing all configurations to a `.bloop/` in the workspace.

### Manual binary dependency

It is *possible* (but **discouraged**) to use Bloop's compilation engine via
a library dependency and interface directly with Bloop internal compiler
APIs. However, most of the nice performance advantages of using Bloop will be
lost as those are implemented in how the schedluling of build targets is
implemented.

#### Pros

1. Can yield some compile speedups if the internals are used correctly

#### Cons

1. No out-of-the-box integration with Metals and other clients (motivation #1)
1. Same local developer workflow as now (motivation #2)
1. Difficult to implement and maintain (similar situation as the status quo)
   * Bloop compiler APIs change frequently
   * Bloop compiler APIs do not promise binary compatibility

## CI compatibility

The CI doesn't pose any integration problems for Bloop. When Bazel runs
compilation in the build farm, the [Bloop Launcher][launcher] will open a
connection with a Bloop server and start compiling, in a similar way to how
the current rules Scala in Bazel or Pants work.

## Conclusion

This document motivates an integration with Bloop, explains why build tools
such as Pants and Bazel would like to integrate with it and what are the
consequences to their users.

This document intentionally goes into not only ideas but also implementation
details to show how a full end-to-end integration from Bazel or Pants to
Bloop is possible and can be implemented. Despite a few minor improvements
missing in the latest Bloop release, build tool engineers could implement an
integration that works tomorrow while solving fundamental problems present
today.

[scaladays]: https://www.scaladays.org
[Natan]: https://github.com/natansil
[Stu]: https://github.com/stuhood
[Win]: https://github.com/wiwa
[Danny]: https://github.com/cosmicexplorer
[survey-ides]: https://insights.stackoverflow.com/survey/2019#development-environments-and-tools
[idea]: https://www.jetbrains.com/idea/
[tweet-1.3.2]: https://twitter.com/jvican/status/1136995079917383680
[configuration-file]: https://scalacenter.github.io/bloop/docs/configuration-format
[bsp]: https://github.com/scalacenter/bsp
[launcher]: https://scalacenter.github.io/bloop/docs/launcher-reference
