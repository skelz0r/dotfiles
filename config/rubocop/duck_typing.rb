# frozen_string_literal: true

module RuboCop
  module Cop
    module Custom
      class DuckTyping < Base
        TYPE_CHECK_MSG = 'Avoid `%<method>s`: rely on duck typing, e.g. ' \
                         '`[*values] == values` instead of `values.is_a?(Array)`, ' \
                         'or convert with `Array(value)`, `String(value)`, `Integer(value)`.'
        CAPABILITY_CHECK_MSG = 'Avoid `respond_to?`: call the method and let NoMethodError ' \
                               'surface, or give every object the same interface ' \
                               '(a null object, a default method in a shared module).'
        RESTRICT_ON_SEND = %i[is_a? kind_of? respond_to?].freeze

        def on_send(node)
          message = if node.method?(:respond_to?)
                      CAPABILITY_CHECK_MSG
                    else
                      format(TYPE_CHECK_MSG, method: node.method_name)
                    end
          add_offense(node.loc.selector, message: message)
        end
        alias on_csend on_send
      end
    end
  end
end
