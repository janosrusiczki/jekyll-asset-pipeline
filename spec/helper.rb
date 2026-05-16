# frozen_string_literal: true

require 'simplecov'
require 'simplecov-cobertura'
SimpleCov.formatter = SimpleCov::Formatter::CoberturaFormatter
SimpleCov.start

require 'rubygems'
gem 'minitest' # Ensures we are using the gem and not the stdlib
require 'minitest/autorun'
require 'minitest/pride'
require './spec/helpers/extensions/ruby/module'
require 'jekyll_asset_pipeline'

module Minitest
  class Spec
    def source_path
      File.join(__dir__, 'resources', 'source')
    end

    def temp_path
      File.join(__dir__, 'resources', 'temp')
    end

    def clear_temp_path
      FileUtils.remove_dir(temp_path, force: true)
    end

    def capture_output(level = :debug)
      buffer = StringIO.new
      Jekyll.logger = Logger.new(buffer)
      Jekyll.logger.log_level = level
      yield
      buffer.rewind
      buffer.string
    ensure
      Jekyll.logger = Logger.new(StringIO.new, :error)
    end

    # Let us use 'context' in specs
    class << self
      alias context describe
    end
  end
end
