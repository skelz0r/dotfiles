# frozen_string_literal: true

return if defined?(RuboCop::Cop::Custom::Ratchet)

require 'pathname'

module RuboCop
  module Cop
    module Custom
      module Ratchet
        COUNT_ONLY_ENV = 'RUBOCOP_RATCHET_COUNT_ONLY'
        QUOTA_FILE = '.rubocop_ratchet.yml'
        LOWER_MSG = '%<count>d offense(s) left in this file, under its quota of %<quota>d: ' \
                    'lower it with `rubocop-ratchet` (%<file>s).'

        def on_new_investigation
          super
          offenses = ratchet_offenses
          quota = ratchet_quota

          if offenses.size > quota
            offenses.each { |range, message| add_offense(range, message: message) }
          elsif offenses.size < quota
            add_global_offense(format(LOWER_MSG, count: offenses.size, quota: quota, file: QUOTA_FILE))
          end
        end

        private

        def ratchet_offenses
          return [] unless processed_source.ast

          processed_source.ast.each_node(:send).select { |node| ratchet_send?(node) }.map { |node| [node, self.class::MSG] }
        end

        def ratchet_quota
          return 0 if ENV.key?(COUNT_ONLY_ENV)

          quotas = cop_config.fetch('Allow', nil).to_h
          return 0 if quotas.empty?

          quotas.fetch(ratchet_path, 0)
        end

        def ratchet_path
          file = Pathname(File.expand_path(processed_source.file_path))
          file.relative_path_from(ratchet_base(file)).to_s
        end

        def ratchet_base(file)
          file.dirname.ascend do |dir|
            return dir if dir.join(QUOTA_FILE).file?
            break if dir.join('.git').exist?
          end
          Pathname(File.expand_path(config.base_dir_for_path_parameters))
        end
      end
    end
  end
end
