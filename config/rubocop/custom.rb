# frozen_string_literal: true

require 'rubocop'

RuboCop::ConfigLoader.inject_defaults!(File.expand_path('default.yml', __dir__))

require_relative 'cop/custom/duck_typing'
require_relative 'cop/custom/no_comments'
require_relative 'cop/custom/no_fixed_sleep'
