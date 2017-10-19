+++
date = "2017-10-19T23:29:12+02:00"
title = "Hygiene in sbt"
description = "Keep your sbt workflow fast and simple."
draft = true
+++

Almost everyone I know enjoys clean places --- no smells, some order and lack of
dirt. In my experience, it is difficult to come across someone that claims
publicly its dislike for cleanliness.

But hygiene is a whim. In reality, most of people believe it has too high of a
cost and sacrifice it. They prefer to spend their time and money on urgent
goals, not niceties. This seems to explain why they only clean common spaces
when the situation becomes unbearable rather than regularly, and why they prefer
to delegate it to others rather than creating cleaning habits.

At the end, hygiene is an extra people learn to live without.

<hr>

In the past months, I've read many, many sbt builds. I observed that no matter
how experienced and skilled the maintainers were, all the builds were
unreadable, complex and difficult to change.

I knew that people's understanding of sbt was limited, blurry at best. But I was
not prepared for the bad sbt practices and the complicated setups that I
encountered.

All the builds I hacked on were from popular projects in the Scala community.
If this is happening in projects that enjoy a steady flow of contributors and
are run by experienced Scala developers, how does the average sbt build look
like?

I didn't want to imagine, but I decided to look for answers. Why do people not
write readable and change-friendly builds, in the first place?

## The goal of our builds

**Most projects' builds fall short because there is no incentive to write good
builds.**
  
Writing builds is purely instrumental. We change the build *just enough* to get
our project compiling, running and passing tests. Builds are not a goal, they
are a means towards a real goal: writing software.
  
It makes sense that we prefer to invest our time on improving the quality of the
software we write rather than on the software that helps us write programs.
After all, that's what whomever judges our work will examine.
  
How can we expect developers to create excellent tools to improve their
productivity if nobody rewards them for doing so?
  
If we want people to keep their sbt builds clean (making a wise use of the build
tool and improving their developer workflows), we need to lower its costs.
Hygiene in sbt (and generally in all our tools) is important to make builds:
  
  * Easy to read for beginners.
  * Easy to change and to iterate on for contributors.
  
But most of developers 
Letting developers get used to lack of hygiene perpetuates our current situation.
This is not acceptable.
