# frozen_string_literal: true

require 'rails_helper'

RSpec.describe [:VIM_EVAL:]substitute(substitute(substitute(expand('%:t'), '_spec.rb', '', ''), '_\(\l\)', '\u\1', 'gc'), '\<.', '\u&', '')[:END_EVAL:], type: :FEEDME do

end
