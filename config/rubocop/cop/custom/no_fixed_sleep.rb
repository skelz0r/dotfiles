# frozen_string_literal: true

return if defined?(RuboCop::Cop::Custom::NoFixedSleep)

require_relative 'ratchet'

module RuboCop
  module Cop
    module Custom
      class NoFixedSleep < Base
        include Ratchet

        MSG = 'Fixed `sleep` in a spec: too short on a loaded machine, wasted time otherwise. ' \
              'Wait for the expected effect instead: a Capybara matcher (`have_content`, `have_css`), ' \
              'or make the effect happen (expire the Redis key, travel in time).'

        def_node_matcher :ratchet_send?, '(send {nil? (const {nil? cbase} :Kernel)} :sleep ...)'
      end
    end
  end
end
