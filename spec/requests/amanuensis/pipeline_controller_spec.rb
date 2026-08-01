# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Amanuensis::PipelineController, type: :request do
  fab!(:user)
  fab!(:admin)
  fab!(:group)

  before do
    SiteSetting.amanuensis_enabled = true
    SiteSetting.amanuensis_api_url = 'https://amanuensis.example.com'
    SiteSetting.amanuensis_api_secret = 'test-secret'
    SiteSetting.amanuensis_writing_group = ''
  end

  def stub_active(meetings: [])
    stub_request(:get, 'https://amanuensis.example.com/v1/plugin/pipeline/active')
      .to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: { meetings: meetings }.to_json
      )
  end

  describe 'when the plugin is disabled' do
    before { SiteSetting.amanuensis_enabled = false }

    it 'returns 404 even for staff' do
      sign_in(admin)
      get '/amanuensis/pipeline'
      expect(response.status).to eq(404)
    end
  end

  describe 'access control' do
    it 'blocks a regular signed-in user with no writing group configured' do
      sign_in(user)
      get '/amanuensis/pipeline'
      expect(response.status).to eq(404)
    end

    it 'blocks an anonymous visitor' do
      get '/amanuensis/pipeline'
      expect(response.status).to eq(404)
    end

    it 'allows staff' do
      stub_active
      sign_in(admin)
      get '/amanuensis/pipeline'
      expect(response.status).to eq(200)
    end

    it 'allows a member of the writing group' do
      SiteSetting.amanuensis_writing_group = group.name
      group.add(user)
      stub_active
      sign_in(user)
      get '/amanuensis/pipeline'
      expect(response.status).to eq(200)
    end

    it 'blocks a member of the VIEWING group who is not also a writer' do
      SiteSetting.amanuensis_viewing_group = group.name
      group.add(user)
      sign_in(user)
      get '/amanuensis/pipeline'
      expect(response.status).to eq(404)
    end
  end

  describe '#active' do
    before do
      SiteSetting.amanuensis_writing_group = group.name
      group.add(user)
      sign_in(user)
    end

    it 'groups meetings by stage and renders them' do
      stub_active(
        meetings: [
          {
            'id' => 'm1',
            'title' => 'Writers Room Standup',
            'status' => 'transcribing',
            'source' => 'google_meet',
            'recorded_at' => '2026-07-01T19:00:00Z',
            'updated_at' => '2026-07-01T19:05:00Z',
            'current_stage_attempt' => nil,
          },
        ],
      )

      get '/amanuensis/pipeline'

      expect(response.status).to eq(200)
      expect(response.body).to include('Writers Room Standup')
      expect(response.body).to include('Transcribing')
    end

    it 'shows the empty state when nothing is active' do
      stub_active(meetings: [])

      get '/amanuensis/pipeline'

      expect(response.status).to eq(200)
      expect(response.body).to include('Nothing in flight')
    end

    it 'surfaces an error when the upstream API fails' do
      stub_request(:get, 'https://amanuensis.example.com/v1/plugin/pipeline/active')
        .to_return(status: 500, body: 'boom')

      get '/amanuensis/pipeline'

      expect(response.status).to eq(200)
      expect(response.body).to include('Failed to fetch active pipeline')
    end
  end
end
