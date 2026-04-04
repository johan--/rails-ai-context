# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAiContext::MarkdownEscape do
  describe ".escape" do
    it "escapes asterisks" do
      expect(described_class.escape("*bold*")).to eq("\\*bold\\*")
    end

    it "escapes underscores" do
      expect(described_class.escape("_italic_")).to eq("\\_italic\\_")
    end

    it "escapes backticks" do
      expect(described_class.escape("`code`")).to eq("\\`code\\`")
    end

    it "escapes brackets and parens" do
      expect(described_class.escape("[link](url)")).to eq("\\[link\\]\\(url\\)")
    end

    it "escapes hash signs" do
      expect(described_class.escape("# heading")).to eq("\\# heading")
    end

    it "escapes pipes" do
      expect(described_class.escape("a|b")).to eq("a\\|b")
    end

    it "escapes tildes" do
      expect(described_class.escape("~strike~")).to eq("\\~strike\\~")
    end

    it "returns empty string for nil" do
      expect(described_class.escape(nil)).to eq("")
    end

    it "passes through normal text unchanged" do
      expect(described_class.escape("UserModel")).to eq("UserModel")
    end

    it "handles mixed content" do
      expect(described_class.escape("my_*special*_gem")).to eq("my\\_\\*special\\*\\_gem")
    end

    it "converts non-strings to string first" do
      expect(described_class.escape(42)).to eq("42")
    end
  end
end
