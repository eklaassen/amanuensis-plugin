# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Amanuensis::OutcomesController, type: :request do
  fab!(:user)
  fab!(:admin)
  fab!(:group)

  before do
    SiteSetting.amanuensis_enabled = true
    SiteSetting.amanuensis_api_url = 'https://amanuensis.example.com'
    SiteSetting.amanuensis_api_secret = 'test-secret'
    SiteSetting.amanuensis_writing_group = ''
  end

  def stub_outcomes(status:, meetings: [], has_more: false)
    stub_request(:get, %r{\Ahttps://amanuensis\.example\.com/v1/plugin/meetings\?.*status=#{status}.*\z})
      .to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: { meetings: meetings, pagination: { has_more: has_more } }.to_json
      )
  end

  describe 'access control' do
    it 'blocks a regular signed-in user with no writing group configured' do
      sign_in(user)
      get '/amanuensis/outcomes'
      expect(response.status).to eq(404)
    end

    it 'blocks an anonymous visitor' do
      get '/amanuensis/outcomes'
      expect(response.status).to eq(404)
    end

    it 'allows staff' do
      stub_outcomes(status: 'complete')
      sign_in(admin)
      get '/amanuensis/outcomes'
      expect(response.status).to eq(200)
    end
  end

  describe '#index' do
    before do
      SiteSetting.amanuensis_writing_group = group.name
      group.add(user)
      sign_in(user)
    end

    it 'defaults to status=complete when no filter is given' do
      stub_outcomes(
        status: 'complete',
        meetings: [
          { 'id' => 'm1', 'title' => 'Writers Room Standup', 'recorded_at' => '2026-07-01T19:00:00Z',
            'status' => 'complete', 'failure_reason' => nil },
        ],
      )

      get '/amanuensis/outcomes'

      expect(response.status).to eq(200)
      expect(response.body).to include('Writers Room Standup')
    end

    it 'filters to failed meetings and shows the failure reason' do
      stub_outcomes(
        status: 'failed',
        meetings: [
          { 'id' => 'm2', 'title' => 'Broken Session', 'recorded_at' => '2026-07-02T19:00:00Z',
            'status' => 'failed', 'failure_reason' => 'Upstream transcription service unavailable' },
        ],
      )

      get '/amanuensis/outcomes', params: { status: 'failed' }

      expect(response.status).to eq(200)
      expect(response.body).to include('Broken Session')
      expect(response.body).to include('Upstream transcription service unavailable')
    end

    it '404s for a status outside complete/failed' do
      get '/amanuensis/outcomes', params: { status: 'transcribing' }
      expect(response.status).to eq(404)
    end

    it 'shows the empty state when there are no meetings' do
      stub_outcomes(status: 'complete', meetings: [])

      get '/amanuensis/outcomes'

      expect(response.status).to eq(200)
      expect(response.body).to include('No meetings here yet')
    end

    it 'surfaces an error when the upstream API fails' do
      stub_request(:get, %r{\Ahttps://amanuensis\.example\.com/v1/plugin/meetings\?.*\z})
        .to_return(status: 500, body: 'boom')

      get '/amanuensis/outcomes'

      expect(response.status).to eq(200)
      expect(response.body).to include('Failed to fetch outcomes')
    end
  end
end
