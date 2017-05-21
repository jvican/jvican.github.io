+++
date = "2017-05-19T20:59:57+02:00"
description = "Meet local settings and tasks in sbt."
title = "Hide your sbt tasks and settings away"

+++

The sbt model encourages plugin authors to write their plugins with a fine level
of granularity. This level of granularity often forces users to create settings
for internal, cached values and tasks for private functionality. As a result,
these settings and tasks end up exposed in the public API, visible for sbt users
and other plugin authors.

This post explains how to use local tasks and settings to hide the
implementation details of your plugins and builds. This helps you evolve them
much faster without the concern of breaking other people's builds.

## Decide the scope of your settings and task first

I find good practice to define the settings on different places depending on
their visibility and scope. My rule of thumb is to define internal settings and
tasks in a scope inaccessible from `autoImport`, either private outside of my
plugin package or protected.

This is how I usually define a "private" setting in plugin `foo`:

```scala
private[foo] object InternalSettings {
  private[foo] val commitId = settingKey[String](
    "The current commit id, only for internal use.")
}
```

Then, I import `InternalSettings` to whichever place defines its implementation
and add it to my project or build settings. Note that to make sure this setting
can never be referred outside of `foo`, I have defined both `commitId` and its
owner as `private[foo]`.

Anyone familiar with access modifiers and Scala's scoping rules will be sure
that `commitId` is inaccessible from sbt plugins defined in another namespace
until they...

## Meet direct setting and task references

For sbt, a setting or a task is just an id and its type signature. If two
settings have the same, then they *are* the same setting! You can use this trick
to prove our previous hypothesis wrong:

```scala
val hijackedCommitId = SettingKey[String]("commitId")
```

Note two things:
  
* We use `SettingKey` instead of `settingKey` because it allow us to pass in
    the name of the setting we require (likewise for `TaskKey` and `taskKey`).
* The parameter for `SettingKey` is the name of the identifier that we used to
    define our private key: `commitId` <a rel="footnote" name="#f1">1</a>.

We thought referring to `commitId` was impossible because `commitId` was
qualified as `private`.  However, the above declaration proves us wrong. What
did we miss? Let's step back and see the whole picture.

### What did we miss?

Sbt is a build tool with three main constructs. Two of these constructs,
settings and tasks, are known at compile-time but their relationships and scopes
are not.

The build tool, however, needs to understand and process them so that users can
access and manipulate this information (via `show`, `inspect`, `set`, et
cetera). If the knowledge at compile-time is not enough, where does sbt look for
the whole picture?

The answer is **runtime**!

Sbt lifts Scala code into its own runtime structure. This runtime structure can
be traversed and manipulated and holds all the information about a given build.

In fact, this runtime structure is somewhat equivalent to Java reflection and
addresses the same limitation that JVMs have: they don't know how programs will
be linked, so they delay linking and bytecode compilation to runtime. The same
holds for sbt -- missing pieces like global and local plugins are only known
when users run `sbt`.

## An unexpected leak to the users

So, you may argue that if someone is so desperate as to make runtime references
to your private settings, we should let them be! After all, it's clear that they
rely on implementation details that may not exist in a future version of your
plugin, right?

That's at least my stance and holds also for Java reflection. You usually don't
care if programs are accessing your private methods using reflection. Both the
API designer and the user know that's unsupported --- otherwise, we couldn't
evolve any API.

But there's a bigger disadvantage with our previous definition of `commitId`.
What happens when your plugin users type `'com' + TAB` and expect the sbt
autocomplete to do its job?

```
> com
commands                  commitId                  compile                   compile:                  compileAnalysisFilename   compileIncremental        
compilerCache             compilerReporter          compilers                 completions 
```

They will see your private key in their console.

This is an important leak of your private API -- those tasks and settings are
cluttering users' screens and giving them the impression that their use is
encouraged! The more you modularize your plugin, the more your users will have
access to these implementation details.  That's not a good incentive for solid
plugin development. So that's why I want you to...

## Meet local settings and tasks

Settings and tasks can be "local". Local settings and tasks have two properties:
  
* They are ignored by sbt autocompletion.
* They have no name (their name is freshly generated).

As a result, users cannot `show` or `inspect` them and plugin authors can only
use them via compile-time references (meaning access modifiers are the absolute
truth to control how these are accessed). This notion of local fixes our
previous problems at one stroke.

I recently discovered local settings and tasks while answering
[@imarios](https://github.com/imarios)'s [request for allowing keys to be
private at the plugin level](https://github.com/sbt/sbt/issues/3192). Though
they were initially created to address another problem, their properties are
ideal to address the limitations at hand.

Let's rewrite `commitId` to be a local setting:

```scala
private[foo] object InternalSettings {
  private[foo] val commitId = SettingKey.local[String]
}
```

To create local tasks, invoke `TaskKey.local[String]`.

It's worth pointing out that local settings and tasks have no descriptions, the
only thing they need is a manifest (a type signature, `String` in our case).

## Conclusion

All in all, local settings and tasks help you build robust plugins that hide
implementation details from other sbt plugins and users<a rel='footnote' href='#f2'>2</a>.
This keeps your plugins hygienic in several ways:

1. Sbt users will not see those implementation details while autocompleting or
   inspecting the settings.
2. Plugin authors will not be able to refer to those settings and tasks.

<hr>

<a name='f1'>1.</a> Remember that `settingKey` is a macro that gets the name of
the setting from the left hand side term that defines it.

<a name='f2'>2.</a> Depending on your code structure and access modifiers,
things could still be accessible via normal Java reflection. However, that
should not keep you up at night.
