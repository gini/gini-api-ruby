# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'gini-api/version'

Gem::Specification.new do |spec|
  spec.name          = 'gini-api'
  spec.version       = Gini::Api::VERSION
  spec.authors       = ['Daniel Kerwin']
  spec.email         = ['tech@gini.net']
  spec.description   = %q{Ruby client to interact with the Gini API.}
  spec.summary       = spec.description
  spec.homepage      = 'https://www.gini.net'
  spec.license       = 'MIT'

  spec.files         = `git ls-files`.split($/)
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'oauth2'
  spec.add_runtime_dependency 'logger'
  spec.add_runtime_dependency 'eventmachine'

  spec.add_development_dependency 'pry'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'redcarpet'
  spec.add_development_dependency 'yard'
  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'guard-rspec'
  spec.add_development_dependency 'simplecov'
  spec.add_development_dependency 'simplecov-rcov'
  spec.add_development_dependency 'ci_reporter'
  spec.add_development_dependency 'webmock'
  spec.add_development_dependency 'coveralls'
end
