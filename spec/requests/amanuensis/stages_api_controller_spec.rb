# frozen_string_literal: true

require "rails_helper"

RSpec.describe Amanuensis::StagesApiController, type: :request do
  fab!(:user)
  fab!(:admin)
  fab!(:group)

  before do
    SiteSetting.amanuensis_enabled = true
    SiteSetting.amanuensis_api_url = "https://amanuensis.example.com"
    SiteSetting.amanuensis_api_secret = "test-secret"
    SiteSetting.amanuensis_writing_group = ""
  end

  def stub_runs(stage, runs: [], has_more: false)
    stub_request(
      :get,
      %r{\Ahttps://amanuensis\.example\.com/v1/plugin/stages/#{stage}/runs(\?.*)?\z},
    ).to_return(
      status: 200,
      headers: {
        "Content-Type" => "application/json",
      },
      body: { runs: runs, pagination: { has_more: has_more } }.to_json,
    )
  end

  def run_body
    {
      "id" => "sr1",
      "meeting_id" => "m1",
      "meeting_title" => "Writers Room Standup",
      "stage" => "transcribing",
      "outcome" => "succeeded",
      "attempt" => 1,
      "started_at" => "2026-07-01T19:05:00Z",
      "finished_at" => "2026-07-01T19:10:00Z",
      "duration_ms" => 300_000,
      "error_code" => nil,
      "failure_reason" => nil,
      "rewind_to" => nil,
      "job_id" => "job-1",
      "inferred" => false,
    }
  end

  def stub_meeting_detail(id, stage_runs: [])
    stub_request(:get, "https://amanuensis.example.com/v1/plugin/meetings/#{id}").to_return(
      status: 200,
      headers: {
        "Content-Type" => "application/json",
      },
      body: { meeting: { "id" => id }, proposal: nil, history: [], stage_runs: stage_runs }.to_json,
    )
  end

  describe "access control on #show" do
    it "blocks a regular signed-in user with no writing group configured" do
      sign_in(user)
      get "/amanuensis/api/stages/transcribing/runs"
      expect(response.status).to eq(403)
    end

    it "blocks an anonymous visitor" do
      get "/amanuensis/api/stages/transcribing/runs"
      expect(response.status).to eq(403)
    end

    it "allows staff" do
      stub_runs("transcribing")
      sign_in(admin)
      get "/amanuensis/api/stages/transcribing/runs"
      expect(response.status).to eq(200)
    end
  end

  describe "#show" do
    before do
      SiteSetting.amanuensis_writing_group = group.name
      group.add(user)
      sign_in(user)
    end

    it "404s for an invalid stage" do
      get "/amanuensis/api/stages/not-a-real-stage/runs"
      expect(response.status).to eq(404)
    end

    it "returns runs for a valid observable stage, plus the stage switcher list" do
      stub_runs("transcribing", runs: [run_body])

      get "/amanuensis/api/stages/transcribing/runs"

      expect(response.status).to eq(200)
      body = response.parsed_body
      expect(body["stage_label"]).to eq("Transcribing")
      expect(body["runs"].first["meeting_title"]).to eq("Writers Room Standup")
      expect(body["observable_stages"]).to eq(
        Amanuensis::PipelineStages::OBSERVABLE.map { |s| { "value" => s, "label" => s.humanize } },
      )
    end

    it "accepts a stage outside the observable set (the escape hatch)" do
      stub_runs("downloading", runs: [])

      get "/amanuensis/api/stages/downloading/runs"

      expect(response.status).to eq(200)
    end

    it "returns an empty list when there are no runs" do
      stub_runs("transcribing", runs: [])

      get "/amanuensis/api/stages/transcribing/runs"

      expect(response.status).to eq(200)
      expect(response.parsed_body["runs"]).to eq([])
    end

    it "surfaces an error when the upstream API fails" do
      stub_request(
        :get,
        %r{\Ahttps://amanuensis\.example\.com/v1/plugin/stages/transcribing/runs(\?.*)?\z},
      ).to_return(status: 500, body: "boom")

      get "/amanuensis/api/stages/transcribing/runs"

      expect(response.status).to eq(502)
      expect(response.parsed_body["error"]).to include("Failed to fetch stage runs")
    end
  end

  describe "#run" do
    before do
      SiteSetting.amanuensis_writing_group = group.name
      group.add(user)
      sign_in(user)
    end

    it "404s for an invalid stage" do
      get "/amanuensis/api/stages/not-a-real-stage/runs/sr1"
      expect(response.status).to eq(404)
    end

    it 'returns the run and the meeting timeline for "other runs"' do
      stub_request(
        :get,
        "https://amanuensis.example.com/v1/plugin/stages/transcribing/runs/sr1",
      ).to_return(
        status: 200,
        headers: {
          "Content-Type" => "application/json",
        },
        body: run_body.to_json,
      )
      stub_meeting_detail("m1", stage_runs: [run_body])

      get "/amanuensis/api/stages/transcribing/runs/sr1"

      expect(response.status).to eq(200)
      body = response.parsed_body
      expect(body["run"]["meeting_title"]).to eq("Writers Room Standup")
      expect(body["other_runs"].first["stage_label"]).to eq("Transcribing")
    end

    it "404s when the run belongs to a different stage than the URL segment" do
      stub_request(
        :get,
        "https://amanuensis.example.com/v1/plugin/stages/summarizing/runs/sr1",
      ).to_return(status: 404, body: "not found")

      get "/amanuensis/api/stages/summarizing/runs/sr1"

      expect(response.status).to eq(502)
      expect(response.parsed_body["error"]).to include("Stage run not found")
      expect(response.parsed_body["stage"]).to eq("summarizing")
    end

    it "surfaces an error when the run is not found upstream" do
      stub_request(
        :get,
        "https://amanuensis.example.com/v1/plugin/stages/transcribing/runs/missing",
      ).to_return(status: 404, body: "not found")

      get "/amanuensis/api/stages/transcribing/runs/missing"

      expect(response.status).to eq(502)
      expect(response.parsed_body["error"]).to include("Stage run not found")
    end

    it "degrades gracefully instead of crashing when the upstream run is missing meeting_id" do
      malformed = run_body.merge("meeting_id" => nil)
      stub_request(
        :get,
        "https://amanuensis.example.com/v1/plugin/stages/transcribing/runs/sr1",
      ).to_return(
        status: 200,
        headers: {
          "Content-Type" => "application/json",
        },
        body: malformed.to_json,
      )

      get "/amanuensis/api/stages/transcribing/runs/sr1"

      expect(response.status).to eq(200)
      body = response.parsed_body
      expect(body["run"]["meeting_title"]).to eq("Writers Room Standup")
      expect(body["run"]["meeting_id"]).to be_nil
      expect(body["other_runs"]).to eq([])
    end
  end
end
