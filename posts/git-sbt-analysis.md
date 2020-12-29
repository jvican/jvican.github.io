<!--*-markdown-*-->
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
<meta http-equiv="X-UA-Compatible" content="IE=edge,chrome=1">
<meta name="author" content="Jorge Vicente Cantero">

<!-- Change this whenever a new blog post is done -->
<meta property="og:title" content="How often do we change our sbt builds?" />
<meta property="og:description" content="A non-scientific analysis across many Scala projects" />
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
<script async defer data-domain="jorge.vican.me" src="https://stats.vican.me/js/index.js"></script>

<title>How often do we change our sbt builds?</title>
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

# How often do we change our sbt builds

<!-- This document is in Pandoc Markdown format.
     http://daringfireball.net/projects/markdown/
     $ pandoc value-type-hygiene.md -o value-type-hygiene.html
     H/T practicaltypography.com
 -->


I spend a lot of time thinking about build tools and popular setups, and what
changes are more likely to impact developers positively.

In one of these ramblings, one question popped up: "How often do we change
our builds?"

It's not easier to answer this question, data on the topic is scarce. So I
challenged myself to come up with some data to satisfy my curiosity.

Next I show some of the data I collected from Scala projects using sbt, the
most popular Scala build tool. I would love to see how these numbers change
across build tools --- I'm sure they do.

## Methodology

1. Clone the repo and follow installation instructions if required.
2. Run a script that detects changes to all `*.sbt` files across all commits.
3. Get three data points: total commits, commits that modified the build and percentage of commits that changed the build.

The source code of the script is available in [the following
Gist](https://gist.github.com/jvican/b163ce76d8d6c3da4e6b8bc3036ca18e). Feel
free to run it in your project.

### Disclaimer

There are two limitations with this approach:

* Our analysis ignores changes to Scala files in sbt meta-projects, it only
detects changes in any file that matches `.*\.sbt` (that is, any sbt build
file). This means we under-approximate.

* If a project defines an sbt plugin (as it's the case of
Bloop or lagom), the data will also show changes that have happened to the
scripted tests.

## Results

I collected the data in [Airtable](https://airtable.com/). It's sorted in
descending order. The results vary between ~37% and 0.43%.

<iframe class="airtable-embed" src="https://airtable.com/embed/shrJ0COoCFGbxSLEL?backgroundColor=gray&layout=card&viewControls=on" frameborder="0" onmousewheel="" width="100%" height="533" style="background: transparent; border: 1px solid #ccc;"></iframe>

<br>

## Conclusions

To my suprise, the projects seemed to be clustered in two groups in a
homonogenous way:

1. A group of 16 projects covering the range of 15-37% of modifications to the build.
2. A second group of 16 projects covering the range 0.43-8.7% modifications to the build.

It's surprising that the division is so perfect... After all, I picked the
projects randomly[^p]. It seems that there's no clear-cut percentage of build
modifications in a project.

The data points analyzed are not enough to draw meaningful conclusions.
However, we can safely assert that the developers (on average) of 50% of
popular open-source Scala projects change their build at least 15%.

If your project belongs to the second group, changes in the build files are
scarce and therefore unlikely to affect your developer workflow. If you are
in the first group, especifically if you are working on a codebase like
`circe`, your developer workflow is slown down by `reload`ing the build after
every change.

The builds of these projects are all complex and, therefore, 15% of changes
in the build are bottle-necked by sbt which does not provide fast reload
times (let alone fast compilation times aside). Modifications to these builds
slow down developers significantly if every change to the build takes at
least 15s [^h].

I don't have any particular advice for maintainers of such projects except
for identifying why so many build changes are required and trying to
outsource them to external tools. Most of the build-related problems can be
solved outside of sbt.

[^h]: Note that the data only shows *committed* changes to sbt build files. I
don't know how many changes were required before the commit got merged. Maybe
a good approximation would be two or three local changes per one committed
change, on average?

[^p]: The analyzed projects have medium-to-large size and they have been sampled from the local Scala
community build in my computer (they contain both libraries and
applications). It's likely there's still a bias.
