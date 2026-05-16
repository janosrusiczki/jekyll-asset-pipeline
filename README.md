# Jekyll Asset Pipeline

[![Gem Version](https://img.shields.io/gem/v/jekyll_asset_pipeline.svg)](https://rubygems.org/gems/jekyll_asset_pipeline)
[![CI](https://github.com/janosrusiczki/jekyll-asset-pipeline/actions/workflows/ci.yml/badge.svg)](https://github.com/janosrusiczki/jekyll-asset-pipeline/actions/workflows/ci.yml)

Jekyll Asset Pipeline is a powerful asset pipeline that automatically collects, converts and compresses / minifies your site's JavaScript and CSS assets when you compile your [Jekyll](https://jekyllrb.com/) site.

## Table of Contents

- [Features](#features)
- [How It Works](#how-it-works)
- [Getting Started](#getting-started)
- [Asset Preprocessing](#asset-preprocessing)
  - [SASS / SCSS](#sass--scss)
  - [LESS](#less)
  - [Successive Preprocessing](#successive-preprocessing)
- [Asset Compression](#asset-compression)
  - [Terser](#terser)
  - [Google's Closure Compiler](#googles-closure-compiler)
- [Templates](#templates)
- [Configuration](#configuration)
- [Contribute](#contribute)
- [Community](#community)
- [Credits](#credits)
- [License](#license)

## Features

- Declarative dependency management via asset manifests
- Asset preprocessing/conversion (supports [CoffeeScript](https://coffeescript.org/), [Sass / Scss](https://sass-lang.com/), [Less](https://lesscss.org/), Erb, etc.)
- Asset compression (supports [Terser](https://rubygems.org/gems/terser), [Closure Compiler](https://developers.google.com/closure/compiler/), etc.)
- Fingerprints bundled asset filenames with MD5 hashes for better browser caching
- Automatic generation of HTML `link` and `script` tags that point to bundled assets
- Integrates seamlessly into Jekyll's workflow, including auto site regeneration

## How It Works

Jekyll Asset Pipeline's workflow can be summarized as follows:

1. Reviews site markup for instances of the `css_asset_tag` and `javascript_asset_tag` Liquid tags. Each occurrence of either of these tags identifies when a new bundle needs to be created and outlines (via a manifest) which assets to include in the bundle.
2. Collects raw assets based on the manifest and runs them through converters / preprocessors (if necessary) to convert them into valid CSS or JavaScript.
3. Combines the processed assets into a single bundle, compresses the bundled assets (if desired) and saves the compressed bundle to the `_site` output folder.
4. Replaces `css_asset_tag` and `javascript_asset_tag` Liquid tags with HTML `link` and `script` tags, respectively, that link to the finished bundles.

## Getting Started

Jekyll Asset Pipeline is extremely easy to add to your Jekyll project and has no incremental dependencies beyond those required by Jekyll. Once you have a basic Jekyll site up and running, follow the steps below to install and configure Jekyll Asset Pipeline.

1. Install the `jekyll_asset_pipeline` gem via [RubyGems](https://rubygems.org/).

  ``` bash
  $ gem install jekyll_asset_pipeline
  ```

  If you are using [Bundler](https://bundler.io/) to manage your project's gems, you can just add `jekyll_asset_pipeline` to your Gemfile and run `bundle install`.

2. Add a `_plugins` folder to your project if you do not already have one. Within the `_plugins` folder, add a file named `jekyll_asset_pipeline.rb` with the following require statement as its contents.

  ``` ruby
  require 'jekyll_asset_pipeline'
  ```

3. Move your assets into a Jekyll ignored folder (i.e. a folder that begins with an underscore `_`) so that Jekyll won't include these raw assets in the site output. It is recommended to use an `_assets` folder to hold your site's assets.

4. Add the following [Liquid](https://shopify.github.io/liquid/) blocks to your site's HTML `head` section. These blocks will be converted into HTML `link` and `script` tags that point to bundled assets. Within each block is a manifest of assets to include in the bundle. Assets are included in the same order that they are listed in the manifest. Replace the `foo` and `bar` assets with your site's assets. At this point we are just using plain old javascript and css files (hence the `.js` and `.css` extensions). See the [Asset Preprocessing](#asset-preprocessing) section to learn how to include files that must be preprocessed (e.g. Sass, Less, Erb, etc.). Name the bundle by including a string after the opening tag. We've named our bundles "global" in the below example.

  ``` html
  {% css_asset_tag global %}
  - /_assets/foo.css
  - /_assets/bar.css
  {% endcss_asset_tag %}

  {% javascript_asset_tag global %}
  - /_assets/foo.js
  - /_assets/bar.js
  {% endjavascript_asset_tag %}
  ```
  Asset manifests must be formatted as YAML arrays and include full paths to each asset from the root of the project. YAML [does not allow tabbed markup](https://yaml.org/faq.html), so you must use spaces when indenting your YAML manifest or you will get an error when you compile your site. If you are using assets that must be preprocessed, you should append the appropriate extension (e.g. '.js.coffee', '.css.less') as discussed in the [Asset Preprocessing](#asset-preprocessing) section.

5. Run the `jekyll build` command to compile your site. You should see an output that includes the following Jekyll Asset Pipeline status messages.

  ``` bash
  $ jekyll build
  Generating...
  Asset Pipeline: Processing 'css_asset_tag' manifest 'global'
  Asset Pipeline: Saved 'global-md5hash.css' to 'yoursitepath/assets'
  Asset Pipeline: Processing 'javascript_asset_tag' manifest 'global'
  Asset Pipeline: Saved 'global-md5hash.js' to 'yoursitepath/assets'
  ```

  If you do not see these messages, check that you have __not__ set Jekyll's `safe` option to `true` in your site's `_config.yml`. If the `safe` option is set to `true`, Jekyll will not run plugins.

That is it! You should now have bundled assets. Look in the `_site` folder of your project for an `assets` folder that contains the bundled assets. HTML tags that point to these assets have been placed in the HTML output where you included the Liquid blocks. *You may notice that your assets have not been converted or compressed-- we will add that functionality next.*

## Asset Preprocessing

Asset preprocessing (i.e. conversion) allows us to write our assets in languages such as [Sass](https://sass-lang.com/), [Less](https://lesscss.org/), Erb, or any other language. One of Jekyll Asset Pipeline's key strengths is that it works with __any__ preprocessing library that has a Ruby wrapper. Adding a preprocessor is straightforward, but requires a small amount of additional code.

### SASS / SCSS

Here's an example of a Sass converter using the actively-maintained [`sass-embedded`](https://rubygems.org/gems/sass-embedded) gem (the official Ruby binding for Dart Sass).

``` ruby
module JekyllAssetPipeline
  class SassConverter < JekyllAssetPipeline::Converter
    require 'sass-embedded'

    def self.filetype
      '.scss'
    end

    def convert
      Sass.compile_string(@content, syntax: :scss, load_paths: [@dirname]).css
    end
  end
end
```

Install the `sass-embedded` gem or add it to your Gemfile and run `bundle install`. The `load_paths: [@dirname]` option ensures that `@use` and `@import` rules resolve relative to the asset's directory.

### LESS

No actively-maintained pure-Ruby gem exists for LESS, but you can shell out to the [Node `lessc` binary](https://lesscss.org/) (install with `npm install -g less`) using Ruby's standard `Open3` library:

``` ruby
module JekyllAssetPipeline
  class LessConverter < JekyllAssetPipeline::Converter
    require 'open3'

    def self.filetype
      '.less'
    end

    def convert
      stdout, status = Open3.capture2("lessc --include-path=#{@dirname} -", stdin_data: @content)
      raise "lessc failed" unless status.success?
      stdout
    end
  end
end
```

This pattern — shelling out to any compiler that reads from stdin — works for any tool that has a command-line interface, not just LESS.

### Successive Preprocessing

If you would like to run an asset through multiple preprocessors successively, you can do so by naming your assets with nested file extensions. Nest the extensions in the order (right to left) that the asset should be processed. For example, `.css.scss.erb` would first be processed by an `erb` preprocessor then by a `scss` preprocessor before being rendered. This convention is very similar to the convention used by the [Ruby on Rails asset pipeline](https://guides.rubyonrails.org/asset_pipeline.html#preprocessing).

Don't forget to define preprocessors for the extensions you use in your filenames, otherwise Jekyll Asset Pipeline will not process your asset.

## Asset Compression

Asset compression allows us to decrease the size of our assets and increase the speed of our site. One of Jekyll Asset Pipeline's key strengths is that it works with __any__ compression library that has a ruby wrapper. Adding asset compression is straightforward, but requires a small amount of additional code.

In the following example, we will add a JavaScript compressor using the actively-maintained [`terser`](https://rubygems.org/gems/terser) gem. For CSS compression, the `sass-embedded` converter shown above supports compressed output natively via `style: :compressed`.

### Terser

1. In the `jekyll_asset_pipeline.rb` file that we created in the [Getting Started](#getting-started) section, add the following code to the end of the file (i.e. after the `require` statement).

  ``` ruby
  module JekyllAssetPipeline
    class JavaScriptCompressor < JekyllAssetPipeline::Compressor
      require 'terser'

      def self.filetype
        '.js'
      end

      def compress
        Terser.new.compile(@content)
      end
    end
  end
  ```

  You can name a compressor anything as long as it inherits from `JekyllAssetPipeline::Compressor`. The `self.filetype` method defines the type of asset a compressor will process (either `'.js'` or `'.css'`). The `compress` method is where the magic happens. A `@content` instance variable that contains the raw content of our bundle is made available within the compressor. The compressor should process this content and return the processed content (as a string) via a `compress` method.

2. If you haven't already, install the `terser` gem.

  ``` bash
  $ gem install terser
  ```

  If you are using [Bundler](https://bundler.io/) to manage your project's gems, you can just add `terser` to your Gemfile and run `bundle install`.

3. Run the `jekyll build` command to compile your site.

That is it! Your asset pipeline has compressed your JavaScript assets. You can verify that this is the case by looking at the contents of the bundles generated in the `_site/assets` folder of your project.

### Google's Closure Compiler

Here's an alternative example using the Google Closure Compiler.

``` ruby
class JavaScriptCompressor < JekyllAssetPipeline::Compressor
  require 'closure-compiler'

  def self.filetype
    '.js'
  end

  def compress
    Closure::Compiler.new.compile(@content)
  end
end
```

Don't forget to install the `closure-compiler` gem before you run the `jekyll build` command since the above compressor requires the `closure-compiler` library as a dependency.

## Templates

When Jekyll Asset Pipeline creates a bundle, it returns an HTML tag that points to the bundle. This tag is either a `link` tag for CSS or a `script` tag for JavaScript. Under most circumstances the default tags will suffice, but you may want to customize this output for special cases (e.g. if you want to add a CSS media attribute).

In the following example, we will override the default CSS link tag by adding a custom template that produces a link tag with a `media` attribute.

1. In the `jekyll_asset_pipeline.rb` file that we created in the [Getting Started](#getting-started) section, add the following code.

  ``` ruby
  module JekyllAssetPipeline
    class CssTagTemplate < JekyllAssetPipeline::Template
      def self.filetype
        '.css'
      end

      def html
        "<link href='#{output_path}/#{@filename}' rel='stylesheet' " \
          "type='text/css' media='screen' />\n"
      end
    end
  end
  ```

  If you already added a compressor and/or a converter, you can include your template class alongside your compressor and/or converter within the same Jekyll Asset Pipeline module.

  The “self.filetype” method defines the type of bundle a template will target (either `.js` or `.css`). The “html” method is where the magic happens. `output_path` is a helper method and `@filename` is an instance variable which are available within the class and contain the path and filename of the generated bundle, respectively. The template should return a string that contains an HTML tag pointing to the generated bundle via an `html` method.

2. Run the `jekyll` command to compile your site.

That is it! Your asset pipeline used your template to generate an HTML `link` tag that includes a media attribute with the value `screen`. You can verify that this is the case by viewing the generated source within your project's `_site` folder.

## Configuration

Jekyll Asset Pipeline provides the following configuration options that can be controlled by adding them to your project's `_config.yml` file. If you don't have a `_config.yml` file, consider reading the [configuration section](https://jekyllrb.com/docs/configuration/) of the Jekyll documentation.

``` yaml
asset_pipeline:
  bundle: true
  compress: true
  output_path: assets
  display_path: nil
  gzip: false
```

Setting        | Default  | Description
---------------|----------|-----------------------------------------------------
`bundle`       | `true`   | controls whether Jekyll Asset Pipeline bundles the assets defined in each manifest. If set to `false`, each asset will be saved individually and individual html tags pointing to each unbundled asset will be produced when you compile your site. It is useful to set this to `false` while you are debugging your site.
`compress`     | `true`   | tells Jekyll Asset Pipeline whether or not to compress the bundled assets. It is useful to set this setting to `false` while you are debugging your site.
`output_path`  | `assets` | defines where generated bundles should be saved within the `_site` folder of your project.
`display_path` | `nil`    | overrides the path to assets in generated html tags. This is useful if you are hosting your site at a path other than the root of your domain (e.g. `http://example.com/blog/`).
`gzip`         | `false`  | controls whether Jekyll Asset Pipeline saves gzipped versions of your assets alongside un-gzipped versions.


## Contribute

You can contribute to Jekyll Asset Pipeline by submitting a pull request [via GitHub](https://github.com/janosrusiczki/jekyll-asset-pipeline).

If you have any ideas or you would like to see anything else improved please use the [issues section](https://github.com/janosrusiczki/jekyll-asset-pipeline/issues).

## Changelog

See [the changelog](CHANGELOG.md).

## Community

- Here is [GitHub's list of projects that use the gem](https://github.com/janosrusiczki/jekyll-asset-pipeline/network/dependents).

## Credits

* [Moshen](https://github.com/moshen/) for creating the [Jekyll Asset Bundler](https://github.com/moshen/jekyll-asset_bundler).
* [Mojombo](https://github.com/mojombo) for creating [Jekyll](https://github.com/jekyll/jekyll) in the first place.

## License

Jekyll Asset Pipeline is released under the [MIT License](https://opensource.org/licenses/MIT).
