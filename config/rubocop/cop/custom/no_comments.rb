# frozen_string_literal: true

return if defined?(RuboCop::Cop::Custom::NoComments)

require_relative 'ratchet'

module RuboCop
  module Cop
    module Custom
      class NoComments < Base
        include Ratchet

        MSG = 'Comment in code: name the variable, the method or the constant after what the comment says, ' \
              'and put the why in the commit message.'

        TOOL_DIRECTIVE = /\A#\s*:nocov:\s*\z/
        SHEBANG = /\A#!/

        private

        def ratchet_offenses
          processed_source.comments.reject { |comment| allowed?(comment) }.map { |comment| [comment, MSG] }
        end

        def allowed?(comment)
          comment.text.match?(SHEBANG) ||
            comment.text.match?(TOOL_DIRECTIVE) ||
            MagicComment.parse(comment.text).any? ||
            DirectiveComment.new(comment).start_with_marker?
        end
      end
    end
  end
end
