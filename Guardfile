guard :rspec, run_all: { cmd: 'rspec -P "spec/gini-api/**/*_spec.rb"' }, all_after_pass: true do
  watch(%r{^spec/.+_spec\.rb$})
  watch(%r{^lib/(.+)\.rb$})     { |m| "spec/#{m[1]}_spec.rb" }
end
