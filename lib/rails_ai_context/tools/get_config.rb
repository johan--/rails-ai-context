# frozen_string_literal: true

module RailsAiContext
  module Tools
    class GetConfig < BaseTool
      tool_name "rails_get_config"
      description "Get Rails application configuration including cache store, session store, timezone, middleware stack, and initializers."

      # Default Rails middleware — suppress to only show app-specific middleware
      DEFAULT_MIDDLEWARE = %w[
        Rack::Sendfile ActionDispatch::Static ActionDispatch::Executor
        ActionDispatch::ServerTiming Rack::Runtime
        ActionDispatch::RequestId ActionDispatch::RemoteIp
        Rails::Rack::Logger ActionDispatch::ShowExceptions
        ActionDispatch::DebugExceptions ActionDispatch::Callbacks
        ActionDispatch::Cookies ActionDispatch::Session::CookieStore
        ActionDispatch::Flash ActionDispatch::ContentSecurityPolicy::Middleware
        ActionDispatch::PermissionsPolicy::Middleware ActionDispatch::ActionableExceptions
        Rack::Head Rack::ConditionalGet Rack::ETag Rack::TempfileReaper
        ActiveRecord::Migration::CheckPending ActionDispatch::HostAuthorization
        Rack::MethodOverride ActionDispatch::Session::AbstractSecureStore
      ].freeze

      input_schema(properties: {})

      annotations(read_only_hint: true, destructive_hint: false, idempotent_hint: true, open_world_hint: false)

      def self.call(server_context: nil)
        data = cached_context[:config]
        return text_response("Config introspection not available. Add :config to introspectors or use `config.preset = :full`.") unless data
        return text_response("Config introspection failed: #{data[:error]}") if data[:error]

        lines = [ "# Application Configuration", "" ]
        lines << "- **Cache store:** #{data[:cache_store]}" if data[:cache_store]
        lines << "- **Session store:** #{data[:session_store]}" if data[:session_store]
        lines << "- **Timezone:** #{data[:timezone]}" if data[:timezone]
        lines << "- **Queue adapter:** #{data[:queue_adapter]}" if data[:queue_adapter]
        if data[:mailer].is_a?(Hash) && data[:mailer].any?
          lines << "- **Mailer:** #{data[:mailer].map { |k, v| "#{k}: #{v}" }.join(', ')}"
        end

        if data[:middleware_stack]&.any?
          # Filter default Rails middleware AND dev-only middleware
          dev_middleware = %w[
            Propshaft::Server WebConsole::Middleware ActionDispatch::Reloader
            Bullet::Rack ActiveSupport::Cache::Strategy::LocalCache
          ]
          custom = data[:middleware_stack].reject { |m| DEFAULT_MIDDLEWARE.include?(m) || dev_middleware.include?(m) }
          if custom.any?
            lines << "" << "## Custom Middleware"
            custom.each { |m| lines << "- #{m}" }
          end
        end

        if data[:initializers]&.any?
          # Filter out standard Rails initializers that every app has
          standard_inits = %w[
            content_security_policy.rb filter_parameter_logging.rb
            inflections.rb permissions_policy.rb assets.rb
            new_framework_defaults.rb cors.rb wrap_parameters.rb
          ]
          notable = data[:initializers].reject { |i| standard_inits.include?(i) }
          if notable.any?
            lines << "" << "## Initializers"
            notable.each { |i| lines << "- `#{i}`" }
          end
        end

        if data[:current_attributes]&.any?
          lines << "" << "## CurrentAttributes"
          data[:current_attributes].each { |c| lines << "- `#{c}`" }
        end

        text_response(lines.join("\n"))
      end
    end
  end
end
