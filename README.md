Frankenstein, or the Modern Prometheus, is a collection of tools and
patterns to make instrumenting a Ruby application just a little bit simpler. 


# Installation

It's a gem:

    gem install frankenstein

There's also the wonders of [the Gemfile](http://bundler.io):

    gem 'frankenstein'

If you're the sturdy type that likes to run from git:

    rake install

Or, if you've eschewed the convenience of Rubygems entirely, then you
presumably know what to do already.


# Usage

The following classes are available; please see their documentation for more
details.

* **`Frankenstein::Server`**: a simple Webrick-based HTTP server you can
  easily embed in your application to serve metrics requests.

* **`Frankenstein::Request`**: collect [basic
  metrics](https://honeycomb.io/blog/2017/01/instrumentation-the-first-four-things-you-measure/)
  about the requests your service receives and makes.


# Contributing

See CONTRIBUTING.md.


# Licence

Unless otherwise stated, everything in this repo is covered by the following
copyright notice:

    Copyright (C) 2017  Civilized Discourse Contruction Kit Inc.

    This program is free software: you can redistribute it and/or modify it
    under the terms of the GNU General Public License version 3, as
    published by the Free Software Foundation.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
