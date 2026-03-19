# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAiContext::Serializers::ClaudeRulesSerializer do
  let(:context) do
    {
      schema: {
        adapter: "postgresql",
        tables: {
          "users" => { columns: [ { name: "id" }, { name: "email" } ], primary_key: "id" },
          "posts" => { columns: [ { name: "id" }, { name: "title" } ], primary_key: "id" }
        }
      },
      models: {
        "User" => { table_name: "users", associations: [ { type: "has_many", name: "posts" } ], validations: [] },
        "Post" => { table_name: "posts", associations: [ { type: "belongs_to", name: "user" } ], validations: [] }
      }
    }
  end

  it "generates .claude/rules/ files" do
    Dir.mktmpdir do |dir|
      result = described_class.new(context).call(dir)
      expect(result[:written].size).to eq(2)

      schema_file = File.join(dir, ".claude", "rules", "rails-schema.md")
      expect(File.exist?(schema_file)).to be true
      content = File.read(schema_file)
      expect(content).to include("users")
      expect(content).to include("rails_get_schema")

      models_file = File.join(dir, ".claude", "rules", "rails-models.md")
      expect(File.exist?(models_file)).to be true
      content = File.read(models_file)
      expect(content).to include("User")
      expect(content).to include("rails_get_model_details")
    end
  end

  it "skips unchanged files" do
    Dir.mktmpdir do |dir|
      first = described_class.new(context).call(dir)
      expect(first[:written].size).to eq(2)

      second = described_class.new(context).call(dir)
      expect(second[:written].size).to eq(0)
      expect(second[:skipped].size).to eq(2)
    end
  end

  it "skips schema rule when no tables" do
    context[:schema] = { adapter: "postgresql", tables: {} }
    Dir.mktmpdir do |dir|
      result = described_class.new(context).call(dir)
      expect(result[:written].size).to eq(1) # only models
    end
  end

  it "skips models rule when no models" do
    context[:models] = {}
    Dir.mktmpdir do |dir|
      result = described_class.new(context).call(dir)
      expect(result[:written].size).to eq(1) # only schema
    end
  end
end
