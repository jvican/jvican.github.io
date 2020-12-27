<!--*-markdown-*-->
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
<meta http-equiv="X-UA-Compatible" content="IE=edge,chrome=1">
<meta name="author" content="Jorge Vicente Cantero">

<!-- Change this whenever a new blog post is done -->
<meta property="og:title" content="Profiling and reducing compilation times" />
<meta property="og:description" content= "A tour on profiling compile times with `scalac-profiling` to understand and reduce the cost of automatic typeclass derivation." />
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
Profiling and reducing compile times of typeclass derivation
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

# Profiling and reducing compilation times of typeclass derivation

I have recently published a blog post in the official Scala website about my
recent work on [`scalac-profiling`][scalac-profiling].

`scalac-profiling` is a new compiler plugin to complement my recent work on
the compiler statistics/sampling infrastructure merged in Scala 2.12.5 and
available from then on.

In the blog post I talk about compilation performance, typeclass derivation,
the expensive price of derivation via implicits and how to `scalac-profiling`
to speed up the compile times of a Bloop module by **8x**.

<div class="omission"></div>

Read more in [`scala-lang`](https://www.scala-lang.org/blog/2018/06/04/scalac-profiling.html).


[scalac-profiling]: https://github.com/scalacenter/scalac-profiling
