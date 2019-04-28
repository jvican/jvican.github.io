pandoc -s index.md -o index.html --metadata pagetitle="@jvican's blog"
pandoc -s posts/overload-methods-with-more-parameter-lists.md -o posts/overload-methods-with-more-parameter-lists.html --metadata pagetitle="Overload methods with more parameters lists"
pandoc -s posts/scalac-profiling.md -o posts/scalac-profiling.html --metadata pagetitle="Profiling and reducing compilation times"
pandoc -s posts/git-sbt-analysis.md -o posts/git-sbt-analysis.html --metadata pagetitle="How often do we change our sbt builds?"