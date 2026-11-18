# frozen_string_literal: true

require_relative '../../config/rubocop/custom'
require 'rubocop/rspec/support'

RSpec.configure do |config|
  config.include RuboCop::RSpec::ExpectOffense
end
