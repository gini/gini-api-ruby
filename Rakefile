require 'bundler/gem_tasks'
require 'rake/clean'

ENV["gem_push"] = "false"

CLEAN << FileList['pkg', '*.gem']

task :test => :'spec:unit'
task :default => :'spec:unit'

## Documentation
require 'yard'

YARD::Rake::YardocTask.new do |task|
  task.files   = ['README.md', 'lib/**/*.rb']
  task.options = ['--output-dir', 'doc',
                  '--markup', 'markdown',
                  '--template-path', './yard',
                  '--readme', 'README.md', '-']
end

## Rspec testing
require 'ci/reporter/rake/rspec'
require "rspec/core/rake_task"

namespace :spec do
  desc "Run RSpec unit tests"
  RSpec::Core::RakeTask.new(:unit) do |t|
    t.pattern = Dir['spec/**/*_spec.rb'].reject{ |f| f['/integration'] }
  end

  desc "Run RSpec integration tests"
  RSpec::Core::RakeTask.new(:integration) do |t|
    t.pattern = "spec/integration/**/*_spec.rb"
  end

  desc "Run all RSpec tests"
  RSpec::Core::RakeTask.new(:all) do |t|
    t.pattern = Dir['spec/**/*_spec.rb']
  end
end

## Debug console
desc 'Run pry with gini-api already loaded'
task :console do
  require 'pry'
  require 'gini-api'
  ARGV.clear
  Pry.start
end
