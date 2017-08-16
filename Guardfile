guard 'rspec', cmd: "rspec", all_on_start: true, all_after_pass: true do
  watch(%r{^spec/.+_spec\.rb$})
  watch(%r{^Gemfile})              { "spec" }
  watch(%r{^spec/.+_methods\.rb$}) { "spec" }
  watch("spec/spec_helper.rb")     { "spec" }
  watch(%r{^lib/})                 { "spec" }
end

guard :rubocop do
  watch(%r{.+\.rb$})
  watch(%r{(?:.+/)?\.rubocop(?:_todo)?\.yml$}) { |m| File.dirname(m[0]) }
end
