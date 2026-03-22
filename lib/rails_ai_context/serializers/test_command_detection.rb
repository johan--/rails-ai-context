# frozen_string_literal: true

module RailsAiContext
  module Serializers
    # Shared helper for detecting the correct test command from introspection data.
    # Include in any serializer that needs to output a test command.
    module TestCommandDetection
      private

      def detect_test_command
        tests = context[:tests]
        framework = tests.is_a?(Hash) ? tests[:framework] : nil
        case framework
        when "rspec" then "bundle exec rspec"
        when "minitest" then "rails test"
        else "rails test"
        end
      end
    end
  end
end
