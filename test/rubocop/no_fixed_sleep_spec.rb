# frozen_string_literal: true

require_relative 'spec_helper'

RSpec.describe RuboCop::Cop::Custom::NoFixedSleep, :config do
  let(:message) { described_class::MSG }
  let(:cop_config) { { 'Allow' => { 'spec/features/legacy_spec.rb' => 2 } } }

  it 'registers an offense for a fixed sleep in a spec' do
    expect_offense(<<~RUBY, 'spec/features/new_spec.rb')
      sleep 1
      ^^^^^^^ #{message}
    RUBY
  end

  it 'registers an offense for Kernel.sleep' do
    expect_offense(<<~RUBY, 'spec/features/new_spec.rb')
      Kernel.sleep(0.5)
      ^^^^^^^^^^^^^^^^^ #{message}
    RUBY
  end

  it 'only applies to specs' do
    cop = described_class.new(RuboCop::ConfigLoader.default_configuration)

    expect(cop.relevant_file?(File.expand_path('app/workers/poll_worker.rb'))).to be(false)
    expect(cop.relevant_file?(File.expand_path('spec/workers/poll_worker_spec.rb'))).to be(true)
  end

  describe 'per-file quota' do
    it 'accepts a file holding exactly its quota' do
      expect_no_offenses(<<~RUBY, 'spec/features/legacy_spec.rb')
        sleep 1
        sleep 2
      RUBY
    end

    it 'reports every offense of a file over its quota' do
      expect_offense(<<~RUBY, 'spec/features/legacy_spec.rb')
        sleep 1
        ^^^^^^^ #{message}
        sleep 2
        ^^^^^^^ #{message}
        sleep 3
        ^^^^^^^ #{message}
      RUBY
    end

    it 'asks to lower the quota of a file under it' do
      expect_offense(<<~RUBY, 'spec/features/legacy_spec.rb')
        sleep 1
        ^{} 1 offense(s) left in this file, under its quota of 2: lower it with `rubocop-ratchet` (.rubocop_ratchet.yml).
      RUBY
    end

    it 'reports every offense of a file absent from the quota' do
      expect_offense(<<~RUBY, 'spec/features/other_spec.rb')
        sleep 1
        ^^^^^^^ #{message}
      RUBY
    end
  end
end
