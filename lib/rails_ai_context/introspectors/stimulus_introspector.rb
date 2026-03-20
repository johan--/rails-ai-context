# frozen_string_literal: true

module RailsAiContext
  module Introspectors
    # Scans Stimulus controllers and extracts targets, values, and actions.
    class StimulusIntrospector
      attr_reader :app

      def initialize(app)
        @app = app
      end

      def call
        root = app.root.to_s
        controllers_dir = File.join(root, "app/javascript/controllers")
        return { controllers: [] } unless Dir.exist?(controllers_dir)

        controllers = Dir.glob(File.join(controllers_dir, "**/*_controller.{js,ts}")).sort.filter_map do |path|
          parse_controller(path, controllers_dir)
        end

        { controllers: controllers }
      rescue => e
        { error: e.message }
      end

      private

      def parse_controller(path, base_dir)
        relative = path.sub("#{base_dir}/", "")
        name = relative.sub(/_controller\.(js|ts)\z/, "").tr("/", "--")
        content = File.read(path)

        {
          name: name,
          file: relative,
          targets: extract_targets(content),
          values: extract_values(content),
          actions: extract_actions(content),
          outlets: extract_outlets(content),
          classes: extract_classes(content)
        }
      rescue => e
        { name: File.basename(path), error: e.message }
      end

      def extract_targets(content)
        match = content.match(/static\s+targets\s*=\s*\[([^\]]*)\]/)
        return [] unless match

        match[1].scan(/["'](\w+)["']/).flatten
      end

      def extract_values(content)
        match = content.match(/static\s+values\s*=\s*\{(.*?)\}/m)
        return {} unless match

        body = match[1]
        values = {}

        # Handle complex format: name: { type: Type, default: val }
        body.scan(/(\w+)\s*:\s*\{([^}]+)\}/).each do |name, inner|
          type = inner.match(/type:\s*(\w+)/)&.send(:[], 1) || "Object"
          default = inner.match(/default:\s*(\S+)/)&.send(:[], 1)&.chomp(",")
          values[name] = default ? "#{type} (default: #{default})" : type
        end

        # Handle simple format: name: Type (single line or multi-line)
        body.scan(/(\w+)\s*:\s*([A-Z]\w+)/).each do |name, type|
          values[name] ||= type
        end

        values
      end

      def extract_actions(content)
        content.scan(/^\s+(?:async\s+)?(\w+)\s*\([^)]*\)\s*\{/).flatten
               .reject { |m| %w[constructor connect disconnect initialize if else for while switch catch function].include?(m) }
      end

      def extract_outlets(content)
        match = content.match(/static\s+outlets\s*=\s*\[([^\]]*)\]/)
        return [] unless match

        match[1].scan(/["']([^"']+)["']/).flatten
      end

      def extract_classes(content)
        match = content.match(/static\s+classes\s*=\s*\[([^\]]*)\]/)
        return [] unless match

        match[1].scan(/["']([^"']+)["']/).flatten
      end
    end
  end
end
