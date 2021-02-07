# jorge.vican.me

This is the website for my blog post. It's written in Github-formatted Mardown
and built with Pandoc. 

## Workflow

1. Change Markdown file.
2. pandoc $FILE.md -f gfm -o $FILE.html

Use `entr` to rerun pandoc on file changes, for example `ls |
entr -s 'pandoc *.md -f gfm -o *.html'`.
