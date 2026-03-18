# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAiContext::Fingerprinter do
  describe ".compute" do
    it "returns a hex digest string" do
      result = described_class.compute(Rails.application)
      expect(result).to match(/\A[a-f0-9]{64}\z/)
    end

    it "returns the same value on repeated calls with no changes" do
      a = described_class.compute(Rails.application)
      b = described_class.compute(Rails.application)
      expect(a).to eq(b)
    end
  end

  describe ".changed?" do
    it "returns false when fingerprint matches" do
      current = described_class.compute(Rails.application)
      expect(described_class.changed?(Rails.application, current)).to be false
    end

    it "returns true when fingerprint differs" do
      expect(described_class.changed?(Rails.application, "stale")).to be true
    end
  end
end
