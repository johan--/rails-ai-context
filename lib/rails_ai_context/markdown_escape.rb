# frozen_string_literal: true

module RailsAiContext
  # Escapes markdown special characters in dynamic content to prevent
  # formatting corruption when interpolating user-controlled names
  # (model names, gem names, etc.) into markdown prose and headings.
  module MarkdownEscape
    SPECIAL_CHARS = /([\\`*_{\}\[\]()+\-#.!~|])/

    def self.escape(text)
      return "" if text.nil?
      text.to_s.gsub(SPECIAL_CHARS, '\\\\\1')
    end
  end
end
