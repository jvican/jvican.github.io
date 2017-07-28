+++
title = "The sbt model"
date = "2017-06-23T12:59:29+02:00"
description = "A quick introduction to sbt"

+++

The sbt model represents the core principles that inspired the design of sbt and
explains why writing sbt code is not *just* Scala. There's something else to it.

The **goal** of this post is to address the following questions:

* What is the reason why people perceive sbt as a difficult build tool?
* What are the essential concepts to fully understand sbt?
* Is essential complexity a key factor in its steep learning curve?
  
**Targeted audience**:
  
* Developers that copy-paste builds to get things done.
* Developers that have used sbt but don't understand how it works.
* Developers that want to learn sbt and start off on the right foot.
* Developers that want to get the gist of sbt without reading the docs.

If you find yourself on one or more of the previous groups, I recommend you to
keep reading. It will be short.

## Quick walkthrough

Why is it so fundamental to understand the sbt model to use it?

This is a common question in the sbt community. Developers in our community have
complained using the tool is difficult. Why cannot it behave like Scala?

Sbt builds upon the Scala language to allow you to express the semantics of your
builds.  Builds can have different needs, and some of them are conflicting. How
can a tool allow us to build the simplest and the most complex of the builds?
How can it be maintainable while being extensible?

Build tools need a language<a rel='footnote' href="#lg">1</a> to accommodate all
these use cases. Languages make different trade-offs, depending on the problems
that their designers set on to address. What's this sbt language and how does it
help us write our diverse builds?

### The sbt language

The sbt language is a set of directives that the programmer uses to interact
with the build tool. The build tool then interprets them to.
Writing code in normal Scala can be either comfortable or frustrating. The
context does alter the experience
on your context. At first, writing Scala code

<hr>

<a name='lg'>1.</a> [Language](language) here means a set of strings of symbols
together with a set of rules that are specific to it. It can either be a DSL or
an API.

[language]: https://en.wikipedia.org/wiki/Formal_language
