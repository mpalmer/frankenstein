require 'bundler'
Bundler.setup(:default, :development)
require 'rspec/core'
require 'rspec/mocks'

require 'simplecov'
SimpleCov.start

RSpec.configure do |config|
  config.fail_fast = true
  #config.full_backtrace = true

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

Thread.abort_on_exception = true
