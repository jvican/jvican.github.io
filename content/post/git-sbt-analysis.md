+++
title = "How often do we change our sbt builds"
description = "An analysis across many Scala projects."
date = "2017-10-19T23:29:12+02:00"
+++

I spend a lot of time thinking about build tools and popular setups, and what
changes are more likely to impact developers positively. In one of these
ramblings, one question popped up: "How often do we change our builds?"

It's not easier to answer this question, data on the topic is scarce. So I
challenged myself to come up with some data to satisfy my curiosity.

Next I show some of the data I collected from Scala projects using sbt, the
most popular Scala build tool. I would love to see how these numbers change
across build tools --- I'm sure they do.

## Methodology

1. Clone the repo and follow installation instructions if required.
2. Run a script that detects changes to all `*.sbt` files across all commits.
3. Get three data points: total commits, commits that modified the build and percentage of commits that changed the build.

The script I've run is the following:

```bash
#!/bin/bash - 
#===============================================================================
#
#          FILE: build-stats-git.sh
# 
#         USAGE: ./build-stats-git.sh 
# 
#   DESCRIPTION: Script that outputs what's the percentage of commits in a codebase
#                that modified the sbt build files. It can be modified to support
#                statistics in other files.
# 
#       OPTIONS: ---
#  REQUIREMENTS: ---
#          BUGS: ---
#         NOTES: ---
#        AUTHOR: Jorge Vicente Cantero
#  ORGANIZATION: Scala Center
#       CREATED: 05/03/2018 09:32:45 PM CEST
#      REVISION:  1.0
#===============================================================================

set -o nounset                              # Treat unset variables as an error

BRANCH=${1:-master}
ALL_COMMITS_BUT_FIRST=$(git rev-list --min-parents=1 "$BRANCH")
ALL_COMMITS_BUT_FIRST_COUNT=$(echo "$ALL_COMMITS_BUT_FIRST" | wc -l)
TOTAL_COMMITS=$((ALL_COMMITS_BUT_FIRST_COUNT + 1))

count=0
for commit in $ALL_COMMITS_BUT_FIRST; do
  if git diff --name-only "$commit" "$commit"~1 | grep '.*\.sbt$' > /dev/null 2>&1; then
    count=$((count + 1))
  fi
done

PERCENTAGE=$(echo "scale=2; $count * 100 / $TOTAL_COMMITS" | bc -l)
echo "Total commits in the branch $BRANCH is $TOTAL_COMMITS"
echo "Detected changes in branch $BRANCH is $count"
echo "The percentage of commits that modify sbt build files is $PERCENTAGE"
```

You can check or download the script in
[Gist](https://gist.github.com/jvican/b163ce76d8d6c3da4e6b8bc3036ca18e) too.

### Disclaimer

This script ignores changes to Scala files in sbt meta-projects, it only
detects changes in any file that matches `.*\.sbt` (that is, any sbt build
file).

Keep in mind that if a project defines an sbt plugin (as it's the case of
Bloop or lagom), the data will also show changes that have happened to the
scripted tests.

## Results

I collected the data in [Airtable](https://airtable.com/). It's sorted in
descending order. The results vary between ~37% and 0.43%.

<iframe class="airtable-embed" src="https://airtable.com/embed/shrJ0COoCFGbxSLEL?backgroundColor=gray&layout=card&viewControls=on" frameborder="0" onmousewheel="" width="100%" height="533" style="background: transparent; border: 1px solid #ccc;"></iframe>

<br>

## Analysis

The projects seemed to be clustered in two groups, in almost a harmonious way.
The first group contains 16 projects and covers the range 15-37%. The second
group contains also 16 projects and covers the range 0.43-8.7%.

If your project belongs to the second group, changes in the build files are
scarce and therefore unlikely to affect your developer workflow. If you are
in the first group, especifically if you work on a codebase like `circe`,
you have a good reason at being mad at your build tool if it's not fast enough.

The builds of these projects are all complex and sbt is not quite good yet at
providing fast reload times (not even speaking of compilation times), so I
think it's fair to say that modification to a build slow down developers
significantly. Personally, what I find most disturbing is my break of focus
when I reload my build to pick up changes.

I don't have any particular advice for maintainers of such projects except
for identifying why so many changes to the build are required and trying to
outsource them to external tools. Most of the build-related problems can be
solved outside of sbt.

Note that the data only shows *committed* changes to sbt build files. I don't
know how many changes were required before the commit got merged. In my
experience, I think a good approximation is a multiplier of 2 or 3 per
change. However, this is an hypothesis based on my personal intuition, so
don't pay too much attention to it.

### A note on the variety of projects

As these projects are all medium to large scale sampled from the Scala
community and my hard drive. I'd grant any observation about a bias towards
tooling-related projects (though I've tried hard to add many libraries and
applications too, like `guardian/frontend` and `ornicar/lila`).