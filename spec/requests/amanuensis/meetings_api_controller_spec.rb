# frozen_string_literal: true

require "rails_helper"

RSpec.describe Amanuensis::MeetingsApiController, type: :request do
  fab!(:user)
  fab!(:admin)
  fab!(:group)

  before do
    SiteSetting.amanuensis_enabled = true
    SiteSetting.amanuensis_api_url = "https://amanuensis.example.com"
    SiteSetting.amanuensis_api_secret = "test-secret"
    SiteSetting.amanuensis_admin_key = "admin-secret"
    SiteSetting.amanuensis_viewing_group = ""
    SiteSetting.amanuensis_relabel_speakers_group = ""
  end

  def stub_meetings_index(meetings: [], has_more: false)
    stub_request(
      :get,
      %r{\Ahttps://amanuensis\.example\.com/v1/plugin/meetings(\?.*)?\z},
    ).to_return(
      status: 200,
      headers: {
        "Content-Type" => "application/json",
      },
      body: { meetings: meetings, pagination: { has_more: has_more } }.to_json,
    )
  end

  def stub_meeting_show(id, meeting:, proposal: nil, history: [], stage_runs: [])
    stub_request(:get, "https://amanuensis.example.com/v1/plugin/meetings/#{id}").to_return(
      status: 200,
      headers: {
        "Content-Type" => "application/json",
      },
      body: {
        meeting: meeting,
        proposal: proposal,
        history: history,
        stage_runs: stage_runs,
      }.to_json,
    )
  end

  describe "access control on #index" do
    context "with no viewing group configured" do
      it "blocks a regular signed-in user" do
        sign_in(user)
        get "/amanuensis/api/meetings"
        expect(response.status).to eq(403)
      end

      it "blocks an anonymous visitor" do
        get "/amanuensis/api/meetings"
        expect(response.status).to eq(403)
      end

      it "allows staff" do
        stub_meetings_index
        sign_in(admin)
        get "/amanuensis/api/meetings"
        expect(response.status).to eq(200)
      end
    end

    context "with a viewing group configured" do
      before { SiteSetting.amanuensis_viewing_group = group.name }

      it "allows a member of the group" do
        group.add(user)
        stub_meetings_index
        sign_in(user)
        get "/amanuensis/api/meetings"
        expect(response.status).to eq(200)
      end
    end
  end

  describe "#index" do
    before do
      SiteSetting.amanuensis_viewing_group = group.name
      group.add(user)
      sign_in(user)
    end

    it "returns the meetings from the API with humanized/formatted fields" do
      stub_meetings_index(
        meetings: [
          {
            "id" => "abc123",
            "title" => "Writers Room Standup",
            "source" => "google_meet",
            "status" => "complete",
            "recorded_at" => "2026-07-01T19:00:00Z",
            "duration_seconds" => 90,
            "has_summary" => true,
            "has_notesbot_transcript" => false,
            "canon_status" => "applied",
          },
        ],
      )

      get "/amanuensis/api/meetings"

      expect(response.status).to eq(200)
      meeting = response.parsed_body["meetings"].first
      expect(meeting["title"]).to eq("Writers Room Standup")
      expect(meeting["source_label"]).to eq("Google meet")
      expect(meeting["duration"]).to eq("1m 30s")
      expect(meeting["has_summary"]).to eq(true)
      expect(meeting["canon_status"]).to eq("applied")
    end

    it "forwards the canon_status filter to the upstream API" do
      stub_meetings_index
      get "/amanuensis/api/meetings", params: { canon_status: "applied" }

      expect(response.status).to eq(200)
      expect(
        a_request(:get, %r{\Ahttps://amanuensis\.example\.com/v1/plugin/meetings}).with(
          query: hash_including("canon_status" => "applied"),
        ),
      ).to have_been_made
    end

    it "surfaces an error when the upstream API fails" do
      stub_request(
        :get,
        %r{\Ahttps://amanuensis\.example\.com/v1/plugin/meetings(\?.*)?\z},
      ).to_return(status: 500, body: "boom")

      get "/amanuensis/api/meetings"

      expect(response.status).to eq(502)
      expect(response.parsed_body["error"]).to include("Failed to fetch meetings")
    end

    it "surfaces an error instead of raising when a 200 body is unparseable" do
      stub_request(
        :get,
        %r{\Ahttps://amanuensis\.example\.com/v1/plugin/meetings(\?.*)?\z},
      ).to_return(
        status: 200,
        body: "<html>gateway</html>",
        headers: {
          "Content-Type" => "text/html",
        },
      )

      get "/amanuensis/api/meetings"

      expect(response.status).to eq(502)
      expect(response.parsed_body["error"]).to include("Malformed JSON")
    end
  end

  describe "#show" do
    before do
      SiteSetting.amanuensis_viewing_group = group.name
      group.add(user)
      sign_in(user)
    end

    it "404s for a malformed id" do
      get "/amanuensis/api/meetings/bad%20id"
      expect(response.status).to eq(404)
    end

    it "returns meeting detail for a valid id" do
      stub_meeting_show(
        "abc123",
        meeting: {
          "id" => "abc123",
          "title" => "Writers Room Standup",
          "source" => "google_meet",
          "status" => "complete",
          "recorded_at" => "2026-07-01T19:00:00Z",
          "discourse_topic_id" => 42,
          "summary" => "<p>Great meeting</p>",
        },
      )

      get "/amanuensis/api/meetings/abc123"

      expect(response.status).to eq(200)
      body = response.parsed_body
      expect(body["meeting"]["title"]).to eq("Writers Room Standup")
      expect(body["meeting"]["discourse_topic_id"]).to eq(42)
      expect(body["meeting"]["summary_html"]).to eq("<p>Great meeting</p>")
    end

    it "sanitizes the summary before it reaches the client" do
      stub_meeting_show(
        "abc123",
        meeting: {
          "id" => "abc123",
          "title" => "X",
          "source" => "google_meet",
          "status" => "complete",
          "summary" => "<p>hi</p><script>alert(1)</script>",
        },
      )

      get "/amanuensis/api/meetings/abc123"

      # The disallowed <script> tag is stripped, but sanitize leaves its text
      # content behind as plain text (unwrapped, not executable) -- verified
      # directly against ActionController::Base.helpers.sanitize rather than
      # assumed.
      expect(response.parsed_body["meeting"]["summary_html"]).to eq("<p>hi</p>alert(1)")
    end

    it "groups notesbot turns by speaker with a deterministic color" do
      stub_meeting_show(
        "abc123",
        meeting: {
          "id" => "abc123",
          "title" => "X",
          "source" => "notesbot",
          "status" => "complete",
          "notesbot_turns" => [
            { "speaker" => "Alice", "timestamp" => "00:01", "text" => "hello" },
            { "speaker" => "Bob", "timestamp" => "00:02", "text" => "hi" },
            { "speaker" => "Alice", "timestamp" => "00:03", "text" => "how are you" },
          ],
        },
      )

      get "/amanuensis/api/meetings/abc123"

      body = response.parsed_body
      expect(body["notesbot_turn_count"]).to eq(3)
      alice = body["notesbot_groups"].find { |g| g["speaker"] == "Alice" }
      bob = body["notesbot_groups"].find { |g| g["speaker"] == "Bob" }
      expect(alice["turn_count"]).to eq(2)
      # Deterministic (sum of char codes mod palette size), not random --
      # verified against the actual algorithm rather than just asserted to
      # look like a color.
      expect(alice["speaker_color"]).to eq("#D94A4A")
      expect(bob["speaker_color"]).to eq("#4AD9C8")
    end

    it "does not build notesbot groups for a non-notesbot meeting even with turns present" do
      stub_meeting_show(
        "abc123",
        meeting: {
          "id" => "abc123",
          "title" => "X",
          "source" => "google_meet",
          "status" => "complete",
          "notesbot_turns" => [{ "speaker" => "Alice", "timestamp" => "00:01", "text" => "hi" }],
        },
      )

      get "/amanuensis/api/meetings/abc123"

      expect(response.parsed_body["notesbot_groups"]).to be_nil
    end

    it "flags has_outcome when the proposal has items -- the full breakdown lives on the outcome page" do
      stub_meeting_show(
        "abc123",
        meeting: {
          "id" => "abc123",
          "title" => "X",
          "source" => "google_meet",
          "status" => "complete",
        },
        proposal: {
          "state" => "pending_review",
          "items" => [
            {
              "decision" => "pending",
              "operation" => "create",
              "target_type" => "scene",
              "proposed_value" => "A",
            },
          ],
        },
      )

      get "/amanuensis/api/meetings/abc123"

      body = response.parsed_body
      expect(body["has_outcome"]).to eq(true)
      expect(body).not_to have_key("proposal")
      expect(body).not_to have_key("history")
    end

    it "flags has_outcome false when there is no proposal or it has no items" do
      stub_meeting_show(
        "abc123",
        meeting: {
          "id" => "abc123",
          "title" => "X",
          "source" => "google_meet",
          "status" => "complete",
        },
        proposal: {
          "state" => "none",
          "items" => [],
        },
      )

      get "/amanuensis/api/meetings/abc123"

      expect(response.parsed_body["has_outcome"]).to eq(false)
    end

    it "formats the pipeline timeline" do
      stub_meeting_show(
        "abc123",
        meeting: {
          "id" => "abc123",
          "title" => "X",
          "source" => "google_meet",
          "status" => "complete",
        },
        stage_runs: [
          {
            "stage" => "transcribing",
            "outcome" => "succeeded",
            "started_at" => "2026-07-01T19:00:00Z",
            "duration_ms" => 5000,
            "attempt" => 1,
          },
        ],
      )

      get "/amanuensis/api/meetings/abc123"

      body = response.parsed_body
      expect(body["stage_runs"].first["stage_label"]).to eq("Transcribing")
      expect(body["stage_runs"].first["duration"]).to eq("5s")
    end

    it "surfaces an error when the meeting is not found upstream" do
      stub_request(:get, "https://amanuensis.example.com/v1/plugin/meetings/missing").to_return(
        status: 404,
        body: "not found",
      )

      get "/amanuensis/api/meetings/missing"

      expect(response.status).to eq(502)
      expect(response.parsed_body["error"]).to include("Meeting not found")
    end
  end

  describe "#speaker_access" do
    fab!(:relabel_group, :group)

    def stub_speaker_access_token(
      id,
      status: 201,
      url: "https://amanuensis.example.com/v1/meetings/#{id}/speakers?token=abc"
    )
      stub_request(
        :post,
        "https://amanuensis.example.com/v1/plugin/meetings/#{id}/speaker-access-token",
      ).to_return(
        status: status,
        headers: {
          "Content-Type" => "application/json",
        },
        body: { token: "abc", url: url }.to_json,
      )
    end

    describe "access control" do
      it "blocks an anonymous visitor" do
        post "/amanuensis/api/meetings/abc123/speaker-access"
        expect(response.status).to eq(403)
      end

      it "blocks a signed-in user who is not in the relabel-speakers group" do
        sign_in(user)
        post "/amanuensis/api/meetings/abc123/speaker-access"
        expect(response.status).to eq(403)
      end

      it "blocks a user who IS a viewer/writer but not a relabel_speakers-group member" do
        # Proves speaker_access is gated on its own permission, not just
        # reusing ensure_viewer -- see the before_action except:/only: split
        # on MeetingsApiController.
        SiteSetting.amanuensis_viewing_group = relabel_group.name
        relabel_group.add(user)

        sign_in(user)
        post "/amanuensis/api/meetings/abc123/speaker-access"
        expect(response.status).to eq(403)
      end

      it "allows a member of the configured relabel-speakers group" do
        SiteSetting.amanuensis_relabel_speakers_group = relabel_group.name
        relabel_group.add(user)
        stub_speaker_access_token("abc123")

        sign_in(user)
        post "/amanuensis/api/meetings/abc123/speaker-access"
        expect(response.status).to eq(200)
      end

      it "allows staff regardless of group membership" do
        stub_speaker_access_token("abc123")
        sign_in(admin)
        post "/amanuensis/api/meetings/abc123/speaker-access"
        expect(response.status).to eq(200)
      end
    end

    context "as an authorized user" do
      before do
        SiteSetting.amanuensis_relabel_speakers_group = relabel_group.name
        relabel_group.add(user)
        sign_in(user)
      end

      it "calls Amanuensis with the admin credential, not the read-only one" do
        stub_speaker_access_token("abc123")

        post "/amanuensis/api/meetings/abc123/speaker-access"

        expect(
          a_request(
            :post,
            "https://amanuensis.example.com/v1/plugin/meetings/abc123/speaker-access-token",
          ).with(headers: { "Authorization" => "Bearer admin-secret" }),
        ).to have_been_made
      end

      it "returns the url Amanuensis minted" do
        stub_speaker_access_token(
          "abc123",
          url: "https://amanuensis.example.com/v1/meetings/abc123/speakers?token=abc",
        )

        post "/amanuensis/api/meetings/abc123/speaker-access"

        expect(response.status).to eq(200)
        expect(response.parsed_body["url"]).to eq(
          "https://amanuensis.example.com/v1/meetings/abc123/speakers?token=abc",
        )
      end

      it "surfaces a 502 when Amanuensis cannot mint a token (e.g. unknown meeting)" do
        stub_speaker_access_token("missing", status: 404)
        stub_request(
          :post,
          "https://amanuensis.example.com/v1/plugin/meetings/missing/speaker-access-token",
        ).to_return(status: 404, body: "not found")

        post "/amanuensis/api/meetings/missing/speaker-access"

        expect(response.status).to eq(502)
        expect(response.parsed_body["error"]).to be_present
      end

      it "fails closed with a 502, not a bad url, when Amanuensis returns something other than an http(s) link" do
        stub_speaker_access_token("abc123", url: "javascript:alert(1)")

        post "/amanuensis/api/meetings/abc123/speaker-access"

        expect(response.status).to eq(502)
        expect(response.parsed_body["url"]).to be_nil
      end

      it "fails closed with a 502 when the upstream body is present but malformed (no url key)" do
        stub_request(
          :post,
          "https://amanuensis.example.com/v1/plugin/meetings/abc123/speaker-access-token",
        ).to_return(
          status: 201,
          headers: {
            "Content-Type" => "application/json",
          },
          body: { token: "abc" }.to_json,
        )

        post "/amanuensis/api/meetings/abc123/speaker-access"

        expect(response.status).to eq(502)
      end

      it "rejects a malformed meeting id without calling Amanuensis at all" do
        post "/amanuensis/api/meetings/not-valid%21/speaker-access"

        expect(response.status).to eq(404)
        expect(
          a_request(:post, %r{/v1/plugin/meetings/.*/speaker-access-token}),
        ).not_to have_been_made
      end
    end
  end
end
