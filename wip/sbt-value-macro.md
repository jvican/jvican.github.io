+++
description = ""
title = "The semantics of value in sbt"
date = "2017-03-29T19:05:17+02:00"

+++

The sbt `value` macro is one of the most misleading features of sbt. In the
surface, it's a great invention. But once you realize how it works it can bite
you more often than expected.

Sbt users are usually not familiar with the semantics of `value` even though
they are nicely explained [in the official
documentation](http://www.scala-sbt.org/0.13/docs/Task-Graph.html).  What the
documentation skips, though, is why it is the way it is and what we can do to we
face its limitations. Below I dive into these aspects, I illustrate why you
should be weary of its use and give you some tips to avoid surprises.

## What does `value` do?

The `value` macro is the main component of the sbt DSL. It allows you to get the
value of any task and setting of your build. It provides to users:

1. A way to abstract over the internal sbt API.
2. An easy-to-use construct for a common operation.

  
  
For example, let's define a task in our `build.sbt`:

```scala
lazy val myCompileTask = taskKey[Unit]("Compile.")
```

And let's *implement* it:

```scala
myCompileTask := {
  compile.value
}
```

As you see, `myCompileTask` is an alias for `compile`. The interesting bit of
this code is how `compile.value` is expanded by the macro:

```scala
myCompileTask := {
  compile.map { compilationResult =>
    // Nothing here, we do nothing with the result
    ()
  }
}
```

At a first glance, the `value` macro takes care of:
  
1. Getting all the identifiers wrapped by `value`s in a block and
   registering them as dependencies of `myCompileTask`.
2. Mapping this dependency to the internal sbt API, which is monadic.
  
  
One may expect this transformation to be powerful. So you may be bold and
implement a fancier compile task that is only run by the CI.

```scala
lazy val runOnCI = taskKey[Unit]("Compile on the CI")
runOnCI := {
  val logger = streams.value.log
  val ci = sys.env.get("DRONE")
  if (ci.map(_.toBoolean).isDefined) {
    logger.info("Running compile on CI.")
    compile.value
  }
}
```

However, when you run `runOnCI` locally, you will be surprised to see that
`compile` is being called even if you guarded its execution with an if
expression and its condition predicate is not met.

What's happened? We've forgotten we're writing sbt, not Scala code.

## A closer look to the semantics

Some may argue that this is a feature of sbt. If you think about sbt being a
graph, it makes sense that dependent nodes are visited before the node (task)
you have defined.

However, I don't think it's a feature. I think that the current semantics are
just a leak of the underlying implementation.

The `value` macro has fundamental limitations to imitate Scala semantics because
providing generic code transformations that respect them is difficult and not
trivial. What `value` essentially does is to lift sbt code into Scala code, but
it does not promise a one-to-one mapping between the two.

Let's have a closer look at the expanded code. The previous task implementation
is equivalent to:

```scala
runOnCI := {
  (streams, compile).map { (st, compilationResult) =>
    val logger = st.log
    val ci = sys.env.get("DRONE")
    if (ci.map(_.toBoolean).isDefined) {
      logger.info("Running compile on CI.")
      compilationResult
    }
  }
}
```

While what we actually want is:

```scala
runOnCI := {
  streams.map { st =>
    val logger = st.log
    val ci = sys.env.get("DRONE")
    if (ci.map(_.toBoolean).isDefined) {
      logger.info("Running compile on CI.")
      compile.map { compilationResult =>
        ()
      }
    }
  }
}
```

Why can't sbt be smarter enough to expand the initial task into that code?

I can think of three reasons:

1. The macro code to handle all the corner cases (if and while expressions,
   pattern matching, by-name parameters, lazy vals, closures, top-level
   expressions in classes, etc) grows larger and more complex.
2. Providing a correct implementation is hard and likely to have bugs.
3. Macros were a young project when sbt started to use them. Back in the day,
   the macro API and the infrastructure around it were not as *mature* as they are
   now.
  
  

I cannot blame sbt maintainers by constraining the semantics of the sbt DSL.
This is not an easy problem.  Shipping complex, *untested* macro code into a
production-ready build tool doesn't seem a good idea.
  
However, I think the current implementation creates confusion for sbt users and
makes learning sbt one of the hardest things when starting in Scala.
  
To work around the described problem, sbt started to build in artificial
constructs that allow users to emulate Scala semantics manually. For example,
dynamic tasks are supposed to be the right way to work around this problem in
idiomatic sbt. This was all done in the spirit of simplifying sbt, but I believe
it ended up backfiring the original purpose of the sbt DSL.
