# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Amanuensis::PipelineApiController, type: :request do
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

  describe 'access control' do
    it 'blocks a regular signed-in user with no writing group configured' do
      sign_in(user)
      get '/amanuensis/api/pipeline'
      expect(response.status).to eq(403)
    end

    it 'blocks an anonymous visitor' do
      get '/amanuensis/api/pipeline'
      expect(response.status).to eq(403)
    end

    it 'allows staff' do
      stub_active
      sign_in(admin)
      get '/amanuensis/api/pipeline'
      expect(response.status).to eq(200)
    end

    it 'allows a member of the writing group' do
      SiteSetting.amanuensis_writing_group = group.name
      group.add(user)
      stub_active
      sign_in(user)
      get '/amanuensis/api/pipeline'
      expect(response.status).to eq(200)
    end

    it 'blocks a member of the VIEWING group who is not also a writer' do
      SiteSetting.amanuensis_viewing_group = group.name
      group.add(user)
      sign_in(user)
      get '/amanuensis/api/pipeline'
      expect(response.status).to eq(403)
    end
  end

  describe '#active' do
    before do
      SiteSetting.amanuensis_writing_group = group.name
      group.add(user)
      sign_in(user)
    end

    it 'groups meetings by stage and includes a humanized stage label' do
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

      get '/amanuensis/api/pipeline'

      expect(response.status).to eq(200)
      body = response.parsed_body
      group_entry = body['stage_groups'].first
      expect(group_entry['stage']).to eq('transcribing')
      expect(group_entry['stage_label']).to eq('Transcribing')
      expect(group_entry['meetings'].first['title']).to eq('Writers Room Standup')
      expect(group_entry['meetings'].first['attempt_note']).to be_nil
    end

    it 'notes the attempt number when a meeting has retried' do
      stub_active(
        meetings: [
          { 'id' => 'm1', 'title' => 'Retry Meeting', 'status' => 'transcribing', 'source' => 'google_meet',
            'updated_at' => '2026-07-01T19:05:00Z', 'current_stage_attempt' => 3 },
        ],
      )

      get '/amanuensis/api/pipeline'

      expect(response.parsed_body['stage_groups'].first['meetings'].first['attempt_note']).to eq('attempt 3')
    end

    it 'returns an empty list when nothing is active' do
      stub_active(meetings: [])

      get '/amanuensis/api/pipeline'

      expect(response.status).to eq(200)
      expect(response.parsed_body['stage_groups']).to eq([])
    end

    it 'surfaces an error when the upstream API fails' do
      stub_request(:get, 'https://amanuensis.example.com/v1/plugin/pipeline/active')
        .to_return(status: 500, body: 'boom')

      get '/amanuensis/api/pipeline'

      expect(response.status).to eq(502)
      expect(response.parsed_body['error']).to include('Failed to fetch active pipeline')
    end
  end
end
