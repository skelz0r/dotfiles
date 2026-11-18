# frozen_string_literal: true

require_relative 'spec_helper'

RSpec.describe RuboCop::Cop::Custom::NoComments, :config do
  let(:message) { described_class::MSG }

  it 'registers an offense for a prose comment' do
    expect_offense(<<~RUBY, 'app/models/contact.rb')
      # Archived contacts are kept for the legal retention period
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{message}
      RETENTION = 5
    RUBY
  end

  it 'registers an offense for a trailing comment' do
    expect_offense(<<~RUBY, 'app/models/contact.rb')
      RETENTION = 5 # legal
                    ^^^^^^^ #{message}
    RUBY
  end

  it 'accepts magic comments' do
    expect_no_offenses(<<~RUBY, 'app/models/contact.rb')
      # frozen_string_literal: true
      # encoding: utf-8
    RUBY
  end

  it 'accepts rubocop directives' do
    expect_no_offenses(<<~RUBY, 'app/models/contact.rb')
      # rubocop:disable Style/GlobalVars
      $redis = nil
      # rubocop:enable Style/GlobalVars
    RUBY
  end

  it 'accepts coverage directives' do
    expect_no_offenses(<<~RUBY, 'app/models/contact.rb')
      # :nocov:
      def debug; end
      # :nocov:
    RUBY
  end

  it 'accepts a shebang' do
    expect_no_offenses(<<~RUBY, 'bin/setup')
      #!/usr/bin/env ruby
    RUBY
  end
end
