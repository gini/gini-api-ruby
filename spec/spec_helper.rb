require 'rspec'
require 'rspec/mocks'
require 'webmock/rspec'

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

require 'simplecov'
require 'simplecov-rcov'

SimpleCov.start do
  add_filter "/spec"
  add_filter "/vendor"
end

if ENV['TRAVIS']
  require 'coveralls'

  SimpleCov.formatter = Coveralls::SimpleCov::Formatter
  Coveralls.wear!
else
  class SimpleCov::Formatter::MergedFormatter
    def format(result)
       SimpleCov::Formatter::HTMLFormatter.new.format(result)
      SimpleCov::Formatter::RcovFormatter.new.format(result)
    end
  end

  SimpleCov.formatter = SimpleCov::Formatter::MergedFormatter
end

require 'gini-api'
