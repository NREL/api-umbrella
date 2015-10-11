---
title: Customizing public website content - Documentation - API Umbrella
header: Documentation
---

Public website content
=======================
The public website content comes from the [api-umbrella-static-site](https://github.com/NREL/api-umbrella-static-site) repo. In the development setup this will be checked out in the *workspace/static-site* directory.

Static site generator
---------------------
API Umbrella uses [middleman](http://middlemanapp.com/) as a static site generator. The general idea is that you can host the site on [GitHub Pages](https://pages.github.com), or any other static HTML hosting location (S3 bucket, etc). The website content is inside the *source* directory, and [Middleman's docs](http://middlemanapp.com/basics/templates/) go into more detail about how the layouts and templates work.

Static site proxy
----------------
If you'd like to use something besides Middleman for your website content, you would modify the **static_site** configuration inside */etc/api-umbrella/api-umbrella.yml* to point to the **host** and **port** of your public website. 
For example, let's say you wanted to use WordPress and it was running on the same server on port 8080, you could proxy to that like:

```yaml
static_site:
  host: 127.0.0.1
  port: 8080
```

This same proxying configuration would also be used if you wanted to host things on Github pages.

Common hurdles
=============
The one major caveat with either approach (using Middleman or some other CMS of your choosing), is that you'll currently face some hurdles in customizing the site if you want to introduce new webpage content. 

Hardcoded url prefixes
------------------
One of the first things the stack does when accepting an incoming request is determine where to send the request (is the request for an API, or for the admin tool, or for the website?). Right now, we have a hard-coded list of URL prefixes that we route to this public website content. This consists of paths like the home page or /docs* (you can see the [full list](https://github.com/NREL/api-umbrella-router/blob/6b15ceb05584fee2001cabdf6f8b7f1120ebaa59/templates/etc/nginx/router.conf.hbs#L150)). This hard-coded list becomes problematic, if you want to add new website content at a new URL paths. We are working to [improve URL routing of webpage content](https://github.com/18F/api.data.gov/issues/146).

In the meantime, there's a couple quick and dirty options:

* Edit this line in [templates/etc/nginx/router.conf.hbs](https://github.com/NREL/api-umbrella-router/blob/6b15ceb05584fee2001cabdf6f8b7f1120ebaa59/templates/etc/nginx/router.conf.hbs#L150) to adjust path prefixes you're matching (this will work fine, but just be careful if you're doing this and using the binary package installers, since your changes will likely be wiped out the next time you upgrade the api-umbrella package).
* Stick new content under subdirectories of the paths we're already routing. So for example, if you want to add a terms & conditions page, try putting that content under */signup/terms* (since we are routing */signup/**).

Neither approach is really ideal, but they might allow you start customizing pages in the near-term.
