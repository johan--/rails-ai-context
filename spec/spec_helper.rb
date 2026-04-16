# frozen_string_literal: true

require "combustion"

Combustion.initialize! :active_record, :action_controller do
  config.eager_load = false
end

require "rails_ai_context"

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = "spec/examples.txt"
  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand config.seed

  # Skip e2e specs unless explicitly requested via E2E=1.
  # E2E specs spawn fresh Rails apps per install path and take minutes
  # per run; they belong on a dedicated CI pipeline, not every push.
  # Run them with: E2E=1 bundle exec rspec spec/e2e
  config.filter_run_excluding(type: :e2e) unless ENV["E2E"] == "1"
end
