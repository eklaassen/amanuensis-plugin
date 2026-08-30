# frozen_string_literal: true

require "rails_helper"
require_relative "../../support/plugin_contract"

RSpec.describe Amanuensis::PluginContractFixture do
  describe ".credential_for" do
    it "resolves both uploads routes to :admin" do
      expect(described_class.credential_for(method: "POST", path: "/v1/plugin/uploads")).to eq(
        :admin,
      )
      expect(
        described_class.credential_for(
          method: "POST",
          path: "/v1/plugin/uploads/:upload_id/complete",
        ),
      ).to eq(:admin)
    end

    it "resolves a read-only route to :reader" do
      expect(described_class.credential_for(method: "GET", path: "/v1/plugin/meetings")).to eq(
        :reader,
      )
    end

    it "raises for a route the fixture does not declare" do
      expect do
        described_class.credential_for(method: "GET", path: "/v1/plugin/does-not-exist")
      end.to raise_error(Amanuensis::PluginContractFixture::UnknownRoute)
    end
  end

  describe ".schema_violations" do
    let(:valid_create_body) do
      {
        filename: "interview.m4a",
        size_bytes: 2048,
        title: "Writers' Room",
        recorded_at: "2026-08-01T19:00:00Z",
      }
    end

    it "has no violations for a body matching the create route schema" do
      violations =
        described_class.schema_violations(
          method: "POST",
          path: "/v1/plugin/uploads",
          body: valid_create_body,
        )

      expect(violations).to be_empty
    end

    it "flags a missing required field" do
      body = valid_create_body.reject { |k, _| k == :size_bytes }

      violations =
        described_class.schema_violations(method: "POST", path: "/v1/plugin/uploads", body: body)

      expect(violations).to include(a_string_matching(/size_bytes/))
    end

    it "flags a type mismatch" do
      body = valid_create_body.merge(size_bytes: "not-a-number")

      violations =
        described_class.schema_violations(method: "POST", path: "/v1/plugin/uploads", body: body)

      expect(violations).to include(a_string_matching(/size_bytes/))
    end

    it "has no violations for the complete route with its own (different) required fields" do
      body = {
        filename: "interview.m4a",
        title: "Writers' Room",
        recorded_at: "2026-08-01T19:00:00Z",
      }

      violations =
        described_class.schema_violations(
          method: "POST",
          path: "/v1/plugin/uploads/:upload_id/complete",
          body: body,
        )

      expect(violations).to be_empty
    end

    it "has no violations for a route with no declared request schema" do
      violations =
        described_class.schema_violations(method: "GET", path: "/v1/plugin/meetings", body: {})

      expect(violations).to be_empty
    end
  end
end
