# frozen_string_literal: true

require "rails_helper"

RSpec.describe Amanuensis::ApiClient do
  before do
    SiteSetting.amanuensis_api_url = "https://amanuensis.example.com"
    SiteSetting.amanuensis_api_secret = "reader-secret"
    SiteSetting.amanuensis_admin_key = "admin-secret"
  end

  describe ".reader" do
    it "authenticates with the reader secret and never the admin key" do
      stub_request(:get, "https://amanuensis.example.com/v1/plugin/meetings").with(
        headers: {
          "Authorization" => "Bearer reader-secret",
        },
      ).to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })

      result = described_class.reader.get("/v1/plugin/meetings")

      expect(result.ok?).to eq(true)
      expect(
        a_request(:get, "https://amanuensis.example.com/v1/plugin/meetings").with(
          headers: {
            "Authorization" => "Bearer reader-secret",
          },
        ),
      ).to have_been_made
      expect(
        a_request(:get, "https://amanuensis.example.com/v1/plugin/meetings").with(
          headers: {
            "Authorization" => "Bearer admin-secret",
          },
        ),
      ).not_to have_been_made
    end
  end

  describe ".admin" do
    it "authenticates with the admin key" do
      stub_request(:get, "https://amanuensis.example.com/v1/plugin/meetings").with(
        headers: {
          "Authorization" => "Bearer admin-secret",
        },
      ).to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })

      result = described_class.admin.get("/v1/plugin/meetings")

      expect(result.ok?).to eq(true)
      expect(
        a_request(:get, "https://amanuensis.example.com/v1/plugin/meetings").with(
          headers: {
            "Authorization" => "Bearer admin-secret",
          },
        ),
      ).to have_been_made
    end
  end

  describe "verb coverage" do
    it "sends GET requests with encoded query params" do
      stub_request(:get, "https://amanuensis.example.com/v1/plugin/meetings?limit=25").to_return(
        status: 200,
        body: '{"meetings":[]}',
        headers: {
          "Content-Type" => "application/json",
        },
      )

      result = described_class.reader.get("/v1/plugin/meetings", limit: 25)

      expect(result.status).to eq(200)
      expect(result.body).to eq({ "meetings" => [] })
    end

    it "sends POST requests with a JSON body" do
      stub =
        stub_request(:post, "https://amanuensis.example.com/v1/plugin/meetings").with(
          body: { title: "New meeting" }.to_json,
          headers: {
            "Content-Type" => "application/json",
          },
        ).to_return(
          status: 201,
          body: '{"id":"abc123"}',
          headers: {
            "Content-Type" => "application/json",
          },
        )

      result = described_class.reader.post("/v1/plugin/meetings", { title: "New meeting" })

      expect(stub).to have_been_requested
      expect(result.status).to eq(201)
      expect(result.body).to eq({ "id" => "abc123" })
    end

    it "sends an Idempotency-Key header on POST when provided" do
      stub =
        stub_request(:post, "https://amanuensis.example.com/v1/plugin/meetings").with(
          headers: {
            "Idempotency-Key" => "key-123",
          },
        ).to_return(status: 201, body: "{}", headers: { "Content-Type" => "application/json" })

      described_class.reader.post("/v1/plugin/meetings", {}, idempotency_key: "key-123")

      expect(stub).to have_been_requested
    end

    it "sends PATCH requests with a JSON body" do
      stub =
        stub_request(:patch, "https://amanuensis.example.com/v1/plugin/meetings/abc123").with(
          body: { title: "Renamed" }.to_json,
        ).to_return(
          status: 200,
          body: '{"id":"abc123"}',
          headers: {
            "Content-Type" => "application/json",
          },
        )

      result = described_class.reader.patch("/v1/plugin/meetings/abc123", { title: "Renamed" })

      expect(stub).to have_been_requested
      expect(result.status).to eq(200)
      expect(result.body).to eq({ "id" => "abc123" })
    end

    it "sends DELETE requests with encoded query params" do
      stub =
        stub_request(
          :delete,
          "https://amanuensis.example.com/v1/plugin/meetings/abc123?force=true",
        ).to_return(status: 204, body: "")

      result = described_class.reader.delete("/v1/plugin/meetings/abc123", force: true)

      expect(stub).to have_been_requested
      expect(result.status).to eq(204)
      expect(result.body).to be_nil
    end
  end

  describe "rescued transport errors" do
    [
      Net::OpenTimeout,
      Net::ReadTimeout,
      Errno::ECONNREFUSED,
      Errno::EHOSTUNREACH,
      OpenSSL::SSL::SSLError,
      SocketError,
      EOFError,
    ].each do |error_class|
      it "rescues #{error_class} into an error Result instead of raising" do
        stub_request(:get, "https://amanuensis.example.com/v1/plugin/meetings").to_raise(
          error_class,
        )

        result = described_class.reader.get("/v1/plugin/meetings")

        expect(result.ok?).to eq(false)
        expect(result.status).to be_nil
        expect(result.error).to be_present
      end
    end

    it "does not rescue errors outside the deliberate list" do
      stub_request(:get, "https://amanuensis.example.com/v1/plugin/meetings").to_raise(
        ArgumentError,
      )

      expect { described_class.reader.get("/v1/plugin/meetings") }.to raise_error(ArgumentError)
    end

    it "returns an error Result for an invalid configured URL instead of raising" do
      SiteSetting.amanuensis_api_url = "https://amanuensis example.com"

      result = described_class.reader.get("/v1/plugin/meetings")

      expect(result.ok?).to eq(false)
      expect(result.error).to eq("Invalid Amanuensis API URL configured.")
    end
  end

  describe "malformed JSON handling" do
    it "is not ok when a 2xx response body is not valid JSON" do
      stub_request(:get, "https://amanuensis.example.com/v1/plugin/meetings").to_return(
        status: 200,
        body: "not json",
        headers: {
          "Content-Type" => "text/plain",
        },
      )

      result = described_class.reader.get("/v1/plugin/meetings")

      # A 2xx with an unparseable body is a broken upstream response. If ok?
      # were true here, callers would reach for result.body['key'] on nil.
      expect(result.status).to eq(200)
      expect(result.body).to be_nil
      expect(result.error).to match(/Malformed JSON/)
      expect(result.ok?).to eq(false)
    end

    it "leaves the error nil for a non-2xx response with an unparseable body" do
      stub_request(:get, "https://amanuensis.example.com/v1/plugin/meetings").to_return(
        status: 500,
        body: "boom",
      )

      result = described_class.reader.get("/v1/plugin/meetings")

      # Upstream error pages are usually plain text. The status is what
      # carries the meaning, so callers can build their own message from it.
      expect(result.status).to eq(500)
      expect(result.body).to be_nil
      expect(result.error).to be_nil
      expect(result.ok?).to eq(false)
    end

    it "treats an empty body as a legitimate success" do
      stub_request(:get, "https://amanuensis.example.com/v1/plugin/meetings").to_return(
        status: 204,
        body: "",
      )

      result = described_class.reader.get("/v1/plugin/meetings")

      expect(result.body).to be_nil
      expect(result.error).to be_nil
      expect(result.ok?).to eq(true)
    end
  end

  describe "missing configuration handling" do
    it "returns an error Result without making a request when the API URL is blank" do
      SiteSetting.amanuensis_api_url = ""

      result = described_class.reader.get("/v1/plugin/meetings")

      expect(result.ok?).to eq(false)
      expect(result.error).to be_present
      expect(a_request(:get, /amanuensis\.example\.com/)).not_to have_been_made
    end

    it "returns an error Result without making a request when the secret is blank" do
      SiteSetting.amanuensis_api_secret = ""

      result = described_class.reader.get("/v1/plugin/meetings")

      expect(result.ok?).to eq(false)
      expect(result.error).to be_present
      expect(a_request(:get, /amanuensis\.example\.com/)).not_to have_been_made
    end

    it "returns an error Result without making a request when the admin key is blank" do
      SiteSetting.amanuensis_admin_key = ""

      result = described_class.admin.get("/v1/plugin/meetings")

      expect(result.ok?).to eq(false)
      expect(result.error).to be_present
      expect(a_request(:get, /amanuensis\.example\.com/)).not_to have_been_made
    end
  end

  describe "Result#ok?" do
    it "is false for a non-2xx status even without a transport error" do
      stub_request(:get, "https://amanuensis.example.com/v1/plugin/meetings").to_return(
        status: 500,
        body: "boom",
      )

      result = described_class.reader.get("/v1/plugin/meetings")

      expect(result.ok?).to eq(false)
      expect(result.status).to eq(500)
      expect(result.error).to be_nil
    end
  end
end
