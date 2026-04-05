# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAiContext::Introspectors::ViewTemplateIntrospector do
  let(:introspector) { described_class.new(Rails.application) }

  describe "#call" do
    subject(:result) { introspector.call }

    it "does not return an error" do
      expect(result).not_to have_key(:error)
    end

    it "returns templates hash" do
      expect(result[:templates]).to be_a(Hash)
    end

    it "returns partials hash" do
      expect(result[:partials]).to be_a(Hash)
    end

    it "discovers templates in posts directory" do
      expect(result[:templates].keys).to include("posts/index.html.erb")
      expect(result[:templates].keys).to include("posts/show.html.erb")
    end

    it "excludes partials from templates" do
      template_names = result[:templates].keys
      expect(template_names.none? { |n| File.basename(n).start_with?("_") }).to be true
    end

    it "discovers partials" do
      expect(result[:partials].keys).to include("posts/_post.html.erb")
    end

    it "counts lines for templates" do
      index = result[:templates]["posts/index.html.erb"]
      expect(index[:lines]).to be > 0
    end

    it "extracts partial references from templates" do
      index = result[:templates]["posts/index.html.erb"]
      expect(index[:partials]).to be_an(Array)
    end

    it "extracts stimulus references from templates" do
      show = result[:templates]["posts/show.html.erb"]
      expect(show[:stimulus]).to be_an(Array)
    end

    it "excludes layouts from templates" do
      template_names = result[:templates].keys
      expect(template_names.none? { |n| n.include?("layouts/") }).to be true
    end

    describe "phlex views" do
      it "discovers Phlex view templates" do
        expect(result[:templates].keys).to include("articles/show.rb")
      end

      it "marks Phlex views with phlex: true" do
        phlex_template = result[:templates]["articles/show.rb"]
        expect(phlex_template[:phlex]).to be true
      end

      it "extracts component renders from Phlex views" do
        phlex_template = result[:templates]["articles/show.rb"]
        expect(phlex_template[:components]).to include("Components::Articles::ArticleUser")
        expect(phlex_template[:components]).to include("Components::Likes::Button")
        expect(phlex_template[:components]).to include("Components::Comments::CommentHeader")
        expect(phlex_template[:components]).to include("Components::Comments::CommentForm")
        expect(phlex_template[:components]).to include("Components::Comments::Comment")
        expect(phlex_template[:components]).to include("RubyUI::Heading")
      end

      it "extracts helper calls from Phlex views" do
        phlex_template = result[:templates]["articles/show.rb"]
        expect(phlex_template[:helpers]).to include("link_to")
        expect(phlex_template[:helpers]).to include("image_tag")
        expect(phlex_template[:helpers]).to include("content_for")
        expect(phlex_template[:helpers]).to include("dom_id")
      end

      it "extracts stimulus controllers from Phlex views" do
        phlex_template = result[:templates]["articles/show.rb"]
        expect(phlex_template[:stimulus]).to include("infinite_scroll")
        expect(phlex_template[:stimulus]).to include("clipboard")
        expect(phlex_template[:stimulus]).to include("reply_form")
      end

      it "does not mark ERB templates as phlex" do
        erb_template = result[:templates]["posts/index.html.erb"]
        expect(erb_template[:phlex]).to be_nil
      end

      it "counts lines for Phlex views" do
        phlex_template = result[:templates]["articles/show.rb"]
        expect(phlex_template[:lines]).to be > 0
      end
    end

    describe "ui_patterns removal (v5.0.0)" do
      it "does not expose a ui_patterns key" do
        expect(result).not_to have_key(:ui_patterns)
      end
    end
  end
end
