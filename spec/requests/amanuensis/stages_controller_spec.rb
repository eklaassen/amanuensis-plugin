# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Amanuensis::StagesController, type: :request do
  fab!(:user)
  fab!(:admin)
  fab!(:group)

  before do
    SiteSetting.amanuensis_enabled = true
    SiteSetting.amanuensis_api_url = 'https://amanuensis.example.com'
    SiteSetting.amanuensis_api_secret = 'test-secret'
    SiteSetting.amanuensis_writing_group = ''
  end

  def stub_runs(stage, runs: [], has_more: false)
    stub_request(:get, %r{\Ahttps://amanuensis\.example\.com/v1/plugin/stages/#{stage}/runs(\?.*)?\z})
      .to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: { runs: runs, pagination: { has_more: has_more } }.to_json
      )
  end

  def run_body
    {
      'id' => 'sr1',
      'meeting_id' => 'm1',
      'meeting_title' => 'Writers Room Standup',
      'stage' => 'transcribing',
      'outcome' => 'succeeded',
      'attempt' => 1,
      'started_at' => '2026-07-01T19:05:00Z',
      'finished_at' => '2026-07-01T19:10:00Z',
      'duration_ms' => 300_000,
      'error_code' => nil,
      'failure_reason' => nil,
      'rewind_to' => nil,
      'job_id' => 'job-1',
      'inferred' => false,
    }
  end

  def stub_meeting_detail(id)
    stub_request(:get, "https://amanuensis.example.com/v1/plugin/meetings/#{id}")
      .to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: { meeting: { 'id' => id }, proposal: nil, history: [], stage_runs: [] }.to_json
      )
  end

  describe 'access control on #show' do
    it 'blocks a regular signed-in user with no writing group configured' do
      sign_in(user)
      get '/amanuensis/stages/transcribing'
      expect(response.status).to eq(404)
    end

    it 'blocks an anonymous visitor' do
      get '/amanuensis/stages/transcribing'
      expect(response.status).to eq(404)
    end

    it 'allows staff' do
      stub_runs('transcribing')
      sign_in(admin)
      get '/amanuensis/stages/transcribing'
      expect(response.status).to eq(200)
    end
  end

  describe '#show' do
    before do
      SiteSetting.amanuensis_writing_group = group.name
      group.add(user)
      sign_in(user)
    end

    it '404s for an invalid stage' do
      get '/amanuensis/stages/not-a-real-stage'
      expect(response.status).to eq(404)
    end

    it 'renders runs for a valid observable stage' do
      stub_runs('transcribing', runs: [run_body])

      get '/amanuensis/stages/transcribing'

      expect(response.status).to eq(200)
      expect(response.body).to include('Writers Room Standup')
    end

    it 'accepts a stage outside the observable set (the escape hatch)' do
      stub_runs('downloading', runs: [])

      get '/amanuensis/stages/downloading'

      expect(response.status).to eq(200)
    end

    it 'shows the empty state when there are no runs' do
      stub_runs('transcribing', runs: [])

      get '/amanuensis/stages/transcribing'

      expect(response.status).to eq(200)
      expect(response.body).to include('No runs recorded')
    end

    it 'surfaces an error when the upstream API fails' do
      stub_request(:get, %r{\Ahttps://amanuensis\.example\.com/v1/plugin/stages/transcribing/runs(\?.*)?\z})
        .to_return(status: 500, body: 'boom')

      get '/amanuensis/stages/transcribing'

      expect(response.status).to eq(200)
      expect(response.body).to include('Failed to fetch stage runs')
    end
  end

  describe '#run' do
    before do
      SiteSetting.amanuensis_writing_group = group.name
      group.add(user)
      sign_in(user)
    end

    it '404s for an invalid stage' do
      get '/amanuensis/stages/not-a-real-stage/runs/sr1'
      expect(response.status).to eq(404)
    end

    it 'renders the run and fetches the meeting for the timeline' do
      stub_request(:get, 'https://amanuensis.example.com/v1/plugin/stages/transcribing/runs/sr1')
        .to_return(status: 200, headers: { 'Content-Type' => 'application/json' }, body: run_body.to_json)
      stub_meeting_detail('m1')

      get '/amanuensis/stages/transcribing/runs/sr1'

      expect(response.status).to eq(200)
      expect(response.body).to include('Writers Room Standup')
    end

    it '404s when the run belongs to a different stage than the URL segment' do
      stub_request(:get, 'https://amanuensis.example.com/v1/plugin/stages/summarizing/runs/sr1')
        .to_return(status: 404, body: 'not found')

      get '/amanuensis/stages/summarizing/runs/sr1'

      expect(response.status).to eq(200)
      expect(response.body).to include('Stage run not found')
    end

    it 'surfaces an error when the run is not found upstream' do
      stub_request(:get, 'https://amanuensis.example.com/v1/plugin/stages/transcribing/runs/missing')
        .to_return(status: 404, body: 'not found')

      get '/amanuensis/stages/transcribing/runs/missing'

      expect(response.status).to eq(200)
      expect(response.body).to include('Stage run not found')
    end
  end
end
