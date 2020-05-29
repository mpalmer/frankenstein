require 'bundler'
Bundler.setup(:default, :development)
require 'rspec/core'
require 'rspec/mocks'

require 'simplecov'
SimpleCov.start

RSpec.configure do |config|
	config.fail_fast = ENV.key?("RSPEC_CONFIG_FAIL_FAST")
	config.full_backtrace = ENV.key?("RSPEC_CONFIG_FULL_BACKTRACE")
	config.order = :random

	config.expect_with :rspec do |c|
		c.syntax = :expect
	end
end

Thread.abort_on_exception = true
