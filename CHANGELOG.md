# Changelog

## 0.7.0 (2026-05-17)

Project adopted and moved to https://github.com/janosrusiczki/jekyll-asset-pipeline.

**Breaking changes**

* Bundle filenames now use an MD5 hash of the compiled output content instead of
  the pipeline parameters. On first build after upgrading, all existing bundle
  filenames will change (one-time). Previously, the hash was derived from file
  mtimes, which meant every CI build produced new filenames — `git checkout`
  resets mtimes to the current time regardless of whether content changed. Now
  the hash reflects actual content, so filenames are stable across CI builds and
  local rebuilds alike. Non-manifest dependencies such as Sass `@use` partials
  that affect output are also correctly reflected in the hash. [#55]

**Improvements**

* Log output is now aligned with Jekyll's column formatting (`Asset Pipeline:`
  right-justified to column 20, matching `Generating...`, `Jekyll Feed:`, etc.)
* Raised minimum Ruby version to 2.7.0 (aligns with Jekyll's CI matrix)
* Updated CI from Travis to GitHub Actions (Ruby 2.7, 3.3, 3.4 matrix)
* Switched coverage reporting from Coveralls to Codecov
* Replaced `rake` 12 with 13 in dev dependencies

**Documentation**

* Modernized README: updated converter examples to `sass-embedded` (Dart Sass)
  and `Open3`/`lessc` for LESS; replaced YUI Compressor example with Terser;
  removed CoffeeScript and Octopress sections (both effectively abandoned)
* Fixed all dead links, HTTP → HTTPS, and stale repo references

## 0.6.2 (2019-10-16)

* Support Jekyll 4.0 [#53]

## 0.6.1 (2019-06-27)

* Drop support of Ruby 2.2

## 0.6.0 (2017-12-20)

* Merged JAPR into Jekyll Asset Pipeline

## 0.5.0, 0.5.1

* Test releases

## 0.4.1 (2017-12-08)

* [#6]  __Test coverage increased to 100%__
* [#35] __Updated rake dependency to 12.0__
* [#34] __Fixed or mitigated all Rubocop offenses__
* [#31] __Documented modules and classes__
* [#29] Various README updates
* [#28] Gemspec file updates (version dependencies and typos)
* [#31] Fix random coverage jumps
* [#33] Rescue StandardError instead of Exception
* Removed CodeClimate integration

## 0.4 (2017-12-03)

* [#20] Support Jekyll 3.5, Liquid 4.0
* [#25] Permit root level output of asset files
* Fix and refactor to eliminate Rubocop offenses
