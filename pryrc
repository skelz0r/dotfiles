# ~/.pryrc - Modern Pry configuration for Rails 6+

# Editor configuration
Pry.config.editor = "vim --nofork"

# Session hooks with better messaging
Pry.config.hooks.add_hook(:before_session, :greeting) do |output, binding, pry|
  output.puts "♦️ #{RUBY_VERSION}"
  if defined?(Rails)
    output.puts "🛤️ #{Rails.version}"
  end
end

Pry.config.hooks.add_hook(:after_session, :farewell) do |output, binding, pry|
  output.puts "👋 See you later!"
end

# Modern prompt configuration with enhanced info
Pry.config.prompt = Pry::Prompt.new(
  "enhanced",
  "Enhanced prompt with Ruby/Rails version and environment info",
  [
    # Main prompt
    proc do |context, nest_level, pry_instance|
      git_branch = `git rev-parse --abbrev-ref HEAD 2>/dev/null`.chomp rescue ""
      git_info = git_branch.empty? ? "" : " (#{git_branch})"

      "#{git_info} #{context}:#{nest_level}> "
    end,
    # Continuation prompt
    proc do |context, nest_level, pry_instance|
      env_info = defined?(Rails) ? "[#{Rails.env}]" : ""
      "#{RUBY_VERSION}#{env_info} #{context}:#{nest_level}* "
    end
  ]
)

# Enhanced gem loading with better error handling
def load_gem(gem_name, &block)
  require gem_name
  yield if block_given?
  puts "✅ Loaded #{gem_name}"
rescue LoadError => e
end

load_gem 'amazing_print' do
  AmazingPrint.pry!
end

load_gem 'hirb' do
  Hirb.enable
end

if File.exist?('config/environment.rb') && ENV['SKIP_RAILS'].nil?
  require './config/environment'


  # Modern Rails console helpers (Rails 6+)
  if defined?(Rails::Console)
    extend Rails::ConsoleMethods if defined?(Rails::ConsoleMethods)
  end

  # ActiveRecord logging configuration
  if defined?(ActiveRecord::Base)
    # Show SQL queries in console
    ActiveRecord::Base.logger = Logger.new(STDOUT)
    ActiveRecord::Base.logger.level = Logger::DEBUG

    # Colorize SQL output if available
    if defined?(ActiveRecord::LogSubscriber)
      ActiveRecord::LogSubscriber.colorize_logging = true
    end
  end

  # Load custom Rails console methods if file exists
  railsrc_path = File.expand_path('.railsrc', __dir__)
  load railsrc_path if File.exist?(railsrc_path)

  # Quick model inspection
  def models
    Rails.application.eager_load!
    ApplicationRecord.descendants.map(&:name).sort
  end if defined?(ApplicationRecord)

  # Route helpers
  def routes
    Rails.application.routes.routes.map do |route|
      { method: route.verb, path: route.path.spec.to_s, controller: route.defaults[:controller], action: route.defaults[:action] }
    end
  end

  # Environment shortcuts
  def prod?; Rails.env.production?; end
  def dev?; Rails.env.development?; end
  def test?; Rails.env.test?; end
end

# Custom commands
Pry::Commands.create_command "reload!" do
  description "Reload the current Rails application"

  def process
    if defined?(Rails)
      puts "🔄 Reloading Rails application..."
      ActionDispatch::Reloader.cleanup!
      ActionDispatch::Reloader.prepare!
      puts "✅ Rails application reloaded!"
    else
      puts "❌ Not in a Rails application"
    end
  end
end

Pry::Commands.create_command "sql", "Execute raw SQL" do
  def process(query)
    if defined?(ActiveRecord::Base)
      result = ActiveRecord::Base.connection.execute(query)
      if result.respond_to?(:to_a)
        ap result.to_a
      else
        puts result
      end
    else
      puts "❌ ActiveRecord not available"
    end
  end
end

# Benchmarking helper
def benchmark(times = 1, &block)
  require 'benchmark'
  result = nil
  timing = Benchmark.measure do
    times.times { result = block.call }
  end
  puts "⏱️  #{timing}"
  result
end

# Memory usage helper
def memory_usage
  `ps -o pid,rss,command -p #{Process.pid}`.chomp
end

# History configuration
Pry.config.history_save = true
Pry.config.history_load = true

# Color configuration
Pry.config.color = true
