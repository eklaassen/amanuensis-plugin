# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Amanuensis::OutcomesApiController, type: :request do
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
      get '/amanuensis/api/outcomes'
      expect(response.status).to eq(403)
    end

    it 'blocks an anonymous visitor' do
      get '/amanuensis/api/outcomes'
      expect(response.status).to eq(403)
    end

    it 'allows staff' do
      stub_outcomes(status: 'complete')
      sign_in(admin)
      get '/amanuensis/api/outcomes'
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

      get '/amanuensis/api/outcomes'

      expect(response.status).to eq(200)
      body = response.parsed_body
      expect(body['status']).to eq('complete')
      expect(body['meetings'].first['title']).to eq('Writers Room Standup')
      expect(body['meetings'].first['recorded_at']).to eq('2026-07-01T19:00:00Z')
    end

    it 'filters to failed meetings and reports the failure reason' do
      stub_outcomes(
        status: 'failed',
        meetings: [
          { 'id' => 'm2', 'title' => 'Broken Session', 'recorded_at' => '2026-07-02T19:00:00Z',
            'status' => 'failed', 'failure_reason' => 'Upstream transcription service unavailable' },
        ],
      )

      get '/amanuensis/api/outcomes', params: { status: 'failed' }

      expect(response.status).to eq(200)
      body = response.parsed_body
      expect(body['meetings'].first['title']).to eq('Broken Session')
      expect(body['meetings'].first['failure_reason']).to eq('Upstream transcription service unavailable')
    end

    it 'only shows meetings whose canon proposal has been applied on the complete tab' do
      stub_outcomes(status: 'complete')

      get '/amanuensis/api/outcomes'

      expect(response.status).to eq(200)
      expect(
        a_request(:get, %r{\Ahttps://amanuensis\.example\.com/v1/plugin/meetings})
          .with(query: hash_including('canon_status' => 'applied')),
      ).to have_been_made
    end

    it 'does not filter by canon_status on the failed tab -- failed meetings never get a proposal' do
      stub_outcomes(status: 'failed')

      get '/amanuensis/api/outcomes', params: { status: 'failed' }

      expect(response.status).to eq(200)
      expect(
        a_request(:get, %r{\Ahttps://amanuensis\.example\.com/v1/plugin/meetings}).with { |req|
          !req.uri.query.to_s.include?('canon_status')
        },
      ).to have_been_made
    end

    it '404s for a status outside complete/failed' do
      get '/amanuensis/api/outcomes', params: { status: 'transcribing' }
      expect(response.status).to eq(404)
    end

    it 'returns an empty list when there are no meetings' do
      stub_outcomes(status: 'complete', meetings: [])

      get '/amanuensis/api/outcomes'

      expect(response.status).to eq(200)
      expect(response.parsed_body['meetings']).to eq([])
    end

    it 'surfaces an error when the upstream API fails' do
      stub_request(:get, %r{\Ahttps://amanuensis\.example\.com/v1/plugin/meetings\?.*\z})
        .to_return(status: 500, body: 'boom')

      get '/amanuensis/api/outcomes'

      expect(response.status).to eq(502)
      expect(response.parsed_body['error']).to include('Failed to fetch outcomes')
    end
  end

  def stub_outcome_show(id, meeting:, proposal: nil, history: [])
    stub_request(:get, "https://amanuensis.example.com/v1/plugin/meetings/#{id}")
      .to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: { meeting: meeting, proposal: proposal, history: history }.to_json
      )
  end

  describe '#show' do
    before do
      SiteSetting.amanuensis_writing_group = group.name
      group.add(user)
      sign_in(user)
    end

    it 'blocks a regular signed-in user with no writing group configured' do
      SiteSetting.amanuensis_writing_group = ''
      get '/amanuensis/api/outcomes/abc123'
      expect(response.status).to eq(403)
    end

    it '404s for a malformed id' do
      get '/amanuensis/api/outcomes/bad%20id'
      expect(response.status).to eq(404)
    end

    it 'returns the meeting reference and proposal grouped by decision' do
      stub_outcome_show(
        'abc123',
        meeting: { 'id' => 'abc123', 'title' => 'Writers Room Standup', 'recorded_at' => '2026-07-01T19:00:00Z' },
        proposal: {
          'state' => 'pending_review',
          'items' => [
            { 'decision' => 'approved', 'operation' => 'create', 'target_type' => 'scene', 'proposed_value' => 'A' },
            { 'decision' => 'edited', 'operation' => 'update', 'target_type' => 'scene', 'proposed_value' => 'B',
              'edited_value' => 'C' },
          ]
        },
      )

      get '/amanuensis/api/outcomes/abc123'

      expect(response.status).to eq(200)
      body = response.parsed_body
      expect(body['meeting']['title']).to eq('Writers Room Standup')

      groups = body['proposal']['groups']
      approved = groups.find { |g| g['decision'] == 'approved' }
      edited = groups.find { |g| g['decision'] == 'edited' }
      expect(approved['decision_label']).to eq('Approved')
      expect(approved['items'].first['proposed_value']).to eq('A')
      expect(edited['items'].first['edited_value']).to eq('C')
    end

    it 'omits the proposal entirely when there are no items' do
      stub_outcome_show(
        'abc123',
        meeting: { 'id' => 'abc123', 'title' => 'X', 'recorded_at' => '2026-07-01T19:00:00Z' },
        proposal: { 'state' => 'none', 'items' => [] },
      )

      get '/amanuensis/api/outcomes/abc123'

      expect(response.parsed_body['proposal']).to be_nil
    end

    it 'formats history entries' do
      stub_outcome_show(
        'abc123',
        meeting: { 'id' => 'abc123', 'title' => 'X', 'recorded_at' => '2026-07-01T19:00:00Z' },
        history: [{ 'created_at' => '2026-07-01T19:00:00Z', 'source' => 'writer', 'actor' => 'elliott',
                    'summary' => 'approved item' }],
      )

      get '/amanuensis/api/outcomes/abc123'

      expect(response.parsed_body['history'].first['actor']).to eq('elliott')
    end

    it 'surfaces an error when the meeting is not found upstream' do
      stub_request(:get, 'https://amanuensis.example.com/v1/plugin/meetings/missing')
        .to_return(status: 404, body: 'not found')

      get '/amanuensis/api/outcomes/missing'

      expect(response.status).to eq(502)
      expect(response.parsed_body['error']).to include('Outcome not found')
    end
  end
end
