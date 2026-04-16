# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"

# Regression coverage for the glob-sourced file-read hardening added after
# v5.9.0. `get_service_pattern`, `get_job_pattern`, and `get_helper_methods`
# all previously globbed `app/services/`, `app/jobs/`, and `app/helpers/`
# then called `File.size` / `safe_read` on the result with no realpath
# containment check and no `sensitive_file?` recheck. A symlink pre-planted
# inside those directories pointing at `config/master.key` (or any
# sensitive-pattern match) would leak the secret through the tool's output.
#
# Fix: each tool now filters glob results through `BaseTool.safe_glob_realpath`
# which (a) resolves the realpath, (b) enforces separator-aware containment
# under the realpath'd directory root, (c) rejects paths that match the
# configured sensitive_patterns after realpath resolution.
RSpec.describe "glob-sourced file read hardening" do
  shared_context "with a sensitive-file symlink" do |tool_dir_rel|
    let(:tmpdir) { Dir.mktmpdir }
    let(:tool_dir) { File.join(tmpdir, tool_dir_rel) }
    let(:secret_path) { File.join(tmpdir, "config", "master.key") }
    let(:secret_contents) { "SECRET-MUST-NOT-LEAK-#{SecureRandom.hex(4)}" }

    before do
      FileUtils.mkdir_p(tool_dir)
      FileUtils.mkdir_p(File.dirname(secret_path))
      File.write(secret_path, secret_contents)
      File.symlink(secret_path, File.join(tool_dir, "sneaky.rb"))
      allow(Rails).to receive(:root).and_return(Pathname.new(tmpdir))
    end

    after { FileUtils.remove_entry(tmpdir) }
  end

  describe RailsAiContext::Tools::GetServicePattern do
    include_context "with a sensitive-file symlink", "app/services"

    it "does not leak master.key content via a symlinked service file" do
      result = described_class.call(detail: "full")
      expect(result.content.first[:text]).not_to include(secret_contents)
    end
  end

  describe RailsAiContext::Tools::GetJobPattern do
    include_context "with a sensitive-file symlink", "app/jobs"

    it "does not leak master.key content via a symlinked job file" do
      result = described_class.call(detail: "full")
      expect(result.content.first[:text]).not_to include(secret_contents)
    end
  end

  describe RailsAiContext::Tools::GetHelperMethods do
    include_context "with a sensitive-file symlink", "app/helpers"

    it "does not leak master.key content via a symlinked helper file" do
      result = described_class.call(detail: "full")
      expect(result.content.first[:text]).not_to include(secret_contents)
    end
  end

  describe RailsAiContext::Tools::GetTurboMap do
    include_context "with a sensitive-file symlink", "app/models"

    it "does not leak master.key content via a symlinked model file" do
      result = described_class.call
      expect(result.content.first[:text]).not_to include(secret_contents)
    end
  end

  describe RailsAiContext::Tools::GetConventions do
    include_context "with a sensitive-file symlink", "app/controllers"

    it "does not leak master.key content via a symlinked controller file" do
      result = described_class.call
      expect(result.content.first[:text]).not_to include(secret_contents)
    end
  end

  describe RailsAiContext::Tools::GetEnv do
    include_context "with a sensitive-file symlink", "app"

    it "does not leak master.key content via a symlinked app file" do
      result = described_class.call
      expect(result.content.first[:text]).not_to include(secret_contents)
    end
  end

  describe RailsAiContext::Tools::AnalyzeFeature do
    include_context "with a sensitive-file symlink", "app/services"

    it "does not leak master.key content via a symlinked service file" do
      result = described_class.call(feature: "sneaky")
      expect(result.content.first[:text]).not_to include(secret_contents)
    end
  end

  describe RailsAiContext::Tools::SearchCode do
    let(:tmpdir) { Dir.mktmpdir }
    let(:secret_path) { File.join(tmpdir, "config", "master.key") }
    let(:secret_value) { "SEARCH-SECRET-LEAK-#{SecureRandom.hex(4)}" }

    before do
      FileUtils.mkdir_p(File.join(tmpdir, "app", "models"))
      FileUtils.mkdir_p(File.dirname(secret_path))
      File.write(secret_path, "password = #{secret_value}")
      File.symlink(secret_path, File.join(tmpdir, "app", "models", "decoy.rb"))
      allow(Rails).to receive(:root).and_return(Pathname.new(tmpdir))
      allow(RailsAiContext::Tools::SearchCode).to receive(:ripgrep_available?).and_return(false)
    end

    after { FileUtils.remove_entry(tmpdir) }

    it "does not surface content from a symlink pointing at master.key" do
      result = described_class.call(pattern: "password")
      expect(result.content.first[:text]).not_to include(secret_value)
    end
  end

  describe RailsAiContext::Tools::GetStimulus do
    let(:tmpdir) { Dir.mktmpdir }
    let(:secret_path) { File.join(tmpdir, "config", "master.key") }
    let(:secret_value) { "STIMULUS-SECRET-#{SecureRandom.hex(4)}" }

    before do
      FileUtils.mkdir_p(File.join(tmpdir, "app", "views"))
      FileUtils.mkdir_p(File.dirname(secret_path))
      File.write(secret_path, "data-controller=\"evil\" #{secret_value}")
      File.symlink(secret_path, File.join(tmpdir, "app", "views", "sneaky.erb"))
      allow(Rails).to receive(:root).and_return(Pathname.new(tmpdir))
    end

    after { FileUtils.remove_entry(tmpdir) }

    it "does not surface master.key content via a symlinked view" do
      result = described_class.call
      expect(result.content.first[:text]).not_to include(secret_value)
    end
  end

  describe "safe_glob_realpath helper" do
    let(:tmpdir) { Dir.mktmpdir }
    let(:real_root) { File.realpath(tmpdir).to_s }
    let(:tool_dir) { File.join(tmpdir, "app", "services") }
    let(:real_tool_dir) { File.realpath(tool_dir).to_s }

    before { FileUtils.mkdir_p(tool_dir) }
    after  { FileUtils.remove_entry(tmpdir) }

    it "returns realpath for in-tree files" do
      safe = File.join(tool_dir, "ok.rb")
      File.write(safe, "ok")
      result = RailsAiContext::Tools::BaseTool.send(:safe_glob_realpath, safe, real_tool_dir, real_root)
      expect(result).to eq(File.realpath(safe).to_s)
    end

    it "rejects symlinks escaping to sibling directories" do
      outside = File.join(tmpdir, "outside.rb")
      File.write(outside, "escape")
      link = File.join(tool_dir, "escape.rb")
      File.symlink(outside, link)
      result = RailsAiContext::Tools::BaseTool.send(:safe_glob_realpath, link, real_tool_dir, real_root)
      expect(result).to be_nil
    end

    it "rejects symlinks pointing at sensitive files" do
      secret = File.join(tmpdir, "config", "master.key")
      FileUtils.mkdir_p(File.dirname(secret))
      File.write(secret, "secret")
      link = File.join(tool_dir, "evil.rb")
      File.symlink(secret, link)
      result = RailsAiContext::Tools::BaseTool.send(:safe_glob_realpath, link, real_tool_dir, real_root)
      expect(result).to be_nil
    end

    it "rejects broken symlinks without raising" do
      link = File.join(tool_dir, "dangling.rb")
      File.symlink("/nonexistent/path/nowhere.rb", link)
      result = RailsAiContext::Tools::BaseTool.send(:safe_glob_realpath, link, real_tool_dir, real_root)
      expect(result).to be_nil
    end

    it "uses separator-aware containment (blocks sibling-prefix bypass)" do
      sibling = "#{tmpdir}/app/services_evil"
      FileUtils.mkdir_p(sibling)
      sibling_file = File.join(sibling, "evil.rb")
      File.write(sibling_file, "evil")
      result = RailsAiContext::Tools::BaseTool.send(:safe_glob_realpath, sibling_file, real_tool_dir, real_root)
      expect(result).to be_nil
    end
  end
end
