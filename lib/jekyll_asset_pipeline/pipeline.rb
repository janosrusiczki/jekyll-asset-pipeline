# frozen_string_literal: true

module JekyllAssetPipeline
  # The pipeline itself, the run method is where it all happens
  # rubocop:disable Metrics/ClassLength
  class Pipeline
    # rubocop:enable Metrics/ClassLength
    class << self
      # Generate hash based on manifest
      def hash(source, manifest, options = {})
        options = DEFAULTS.merge(options)
        begin
          Digest::MD5.hexdigest(YAML.safe_load(manifest).map! do |path|
            "#{path}#{File.mtime(File.join(source, path)).to_i}"
          end.join.concat(options.to_s))
        rescue StandardError => e
          puts "Failed to generate hash from provided manifest: #{e.message}"
          raise e
        end
      end

      # Run the pipeline
      # This is called from JekyllAssetPipeline::LiquidBlockExtensions.render
      # or, to be more precise, from JekyllAssetPipeline::CssAssetTag.render and
      # JekyllAssetPipeline::JavaScriptAssetTag.render
      # rubocop:disable Metrics/ParameterLists
      def run(manifest, prefix, source, destination, tag, type, config)
        # rubocop:enable Metrics/ParameterLists
        # Get hash for pipeline
        hash = hash(source, manifest, config)

        # Check if pipeline has been cached
        return cache[hash], true if cache.key?(hash)

        begin
          puts "Processing '#{tag}' manifest '#{prefix}'"
          pipeline = new(manifest, prefix, source, destination, type, config)
          process_pipeline(hash, pipeline)
        rescue StandardError => e
          # Add exception to cache
          cache[hash] = e

          # Re-raise the exception
          raise e
        end
      end

      # Cache processed pipelines
      def cache
        @cache ||= {}
      end

      # Empty cache
      def clear_cache
        @cache = {}
      end

      # Remove staged assets
      def remove_staged_assets(source, config)
        config = DEFAULTS.merge(config)
        FileUtils.rm_rf(resolve_staging_path(source, config['staging_path']))
      end

      # Resolve staging path: absolute paths used as-is, relative paths
      # joined with the Jekyll source directory.
      def resolve_staging_path(source, path)
        Pathname.new(path).absolute? ? path : File.join(source, path)
      end

      def puts(message)
        Jekyll.logger.info('Asset Pipeline:', message)
      end

      private

      def process_pipeline(hash, pipeline)
        pipeline.assets.each do |asset|
          puts "Saved '#{asset.filename}' to " \
            "'#{pipeline.destination}/#{asset.output_path}'"
        end

        # Add processed pipeline to cache
        cache[hash] = pipeline

        # Return newly processed pipeline and cached status
        [pipeline, false]
      end
    end

    # Initialize new pipeline
    # rubocop:disable Metrics/ParameterLists
    def initialize(manifest, prefix, source, destination, type, options = {})
      # rubocop:enable Metrics/ParameterLists
      @manifest = manifest
      @prefix = prefix
      @source = source
      @destination = destination
      @type = type
      @options = ::JekyllAssetPipeline::DEFAULTS.merge(options)

      process
    end

    attr_reader :assets, :html, :destination

    private

    # Process the pipeline
    def process
      collect
      convert
      bundle if @options['bundle']
      compress if @options['compress']
      finalize_bundle_filename if @options['bundle']
      gzip if @options['gzip']
      save
      markup
    end

    def log_error(message)
      Jekyll.logger.error('Asset Pipeline:', message)
    end

    # Collect assets based on manifest
    def collect
      @assets = YAML.safe_load(@manifest).map! do |path|
        full_path = File.join(@source, path)
        File.open(File.join(@source, path)) do |file|
          ::JekyllAssetPipeline::Asset.new(file.read, File.basename(path),
                                           File.dirname(full_path))
        end
      end
    rescue StandardError => e
      log_error "Failed to load assets from provided manifest: #{e.message}"
      raise e
    end

    # Convert assets based on the file extension if converter is defined
    def convert
      @assets.each do |asset|
        # Convert asset multiple times if more than one converter is found
        finished = false
        while finished == false
          # Find a converter to use
          klass = ::JekyllAssetPipeline::Converter.klass(asset.filename)

          # Convert asset if converter is found
          if klass.nil?
            finished = true
          else
            convert_asset(klass, asset)
          end
        end
      end
    end

    # Convert an asset with a given converter class
    def convert_asset(klass, asset)
      # Convert asset content
      converter = klass.new(asset)

      # Replace asset content and filename
      asset.content = converter.converted
      asset.filename = File.basename(asset.filename, '.*')

      # Add back the output extension if no extension left
      asset.filename = "#{asset.filename}#{@type}" if File.extname(asset.filename) == ''
    rescue StandardError => e
      log_error "Failed to convert '#{asset.filename}' with '#{klass}': #{e.message}"
      raise e
    end

    # Bundle multiple assets into a single asset
    def bundle
      content = @assets.map(&:content).join("\n")
      @assets = [::JekyllAssetPipeline::Asset.new(content, "#{@prefix}#{@type}")]
    end

    # Set final bundle filename from MD5 of post-compression content
    def finalize_bundle_filename
      @assets.each do |asset|
        hash = Digest::MD5.hexdigest(asset.content)
        asset.filename = "#{@prefix}-#{hash}#{@type}"
      end
    end

    # Compress assets if compressor is defined
    def compress
      @assets.each do |asset|
        # Find a compressor to use
        klass = ::JekyllAssetPipeline::Compressor.subclasses.select do |c|
          c.filetype == @type
        end.last

        break unless klass

        begin
          asset.content = klass.new(asset.content).compressed
        rescue StandardError => e
          log_error "Failed to compress '#{asset.filename}' with '#{klass}': #{e.message}"
          raise e
        end
      end
    end

    # Create Gzip versions of assets
    def gzip
      @assets.map! do |asset|
        gzip_content = Zlib::Deflate.deflate(asset.content)
        [
          asset,
          ::JekyllAssetPipeline::Asset
            .new(gzip_content, "#{asset.filename}.gz", asset.dirname)
        ]
      end.flatten!
    end

    # Save assets to file
    def save
      output_path = @options['output_path']
      base = ::JekyllAssetPipeline::Pipeline.resolve_staging_path(@source, @options['staging_path'])

      @assets.each do |asset|
        write_asset_file(File.join(base, output_path), asset)

        # Store output path of saved file
        asset.output_path = output_path
      end
    end

    # Write asset file to disk
    def write_asset_file(directory, asset)
      FileUtils.mkpath(directory) unless File.directory?(directory)
      begin
        # Save file to disk
        File.open(File.join(directory, asset.filename), 'w') do |file|
          file.write(asset.content)
        end
      rescue StandardError => e
        log_error "Failed to save '#{asset.filename}' to disk: #{e.message}"
        raise e
      end
    end

    # Generate html markup pointing to assets
    def markup
      output_path  = @options['output_path']
      display_path = @options['display_path']

      url_path = if display_path
                   [display_path.chomp('/'), output_path].reject(&:empty?).join('/')
                 else
                   output_path
                 end

      @html = @assets.map do |asset|
        klass = ::JekyllAssetPipeline::Template.klass(asset.filename)
        html = klass.new(url_path, asset.filename).html unless klass.nil?

        html
      end.join
    end
  end
end
