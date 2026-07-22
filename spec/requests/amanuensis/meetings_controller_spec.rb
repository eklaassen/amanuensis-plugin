# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Amanuensis::MeetingsController, type: :request do
  fab!(:user)
  fab!(:admin)
  fab!(:group)

  before do
    SiteSetting.amanuensis_enabled = true
    SiteSetting.amanuensis_api_url = 'https://amanuensis.example.com'
    SiteSetting.amanuensis_api_secret = 'test-secret'
    SiteSetting.amanuensis_viewing_group = ''
  end

  def stub_meetings_index(meetings: [], has_more: false)
    stub_request(:get, %r{\Ahttps://amanuensis\.example\.com/v1/plugin/meetings(\?.*)?\z})
      .to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: { meetings: meetings, pagination: { has_more: has_more } }.to_json
      )
  end

  def stub_meeting_show(id, meeting:, proposal: nil, history: [])
    stub_request(:get, "https://amanuensis.example.com/v1/plugin/meetings/#{id}")
      .to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: { meeting: meeting, proposal: proposal, history: history }.to_json
      )
  end

  describe 'when the plugin is disabled' do
    before { SiteSetting.amanuensis_enabled = false }

    it 'returns 404 even for staff' do
      sign_in(admin)
      get '/amanuensis/meetings'
      expect(response.status).to eq(404)
    end
  end

  describe 'access control on #index' do
    context 'with no viewing group configured' do
      it 'blocks a regular signed-in user' do
        sign_in(user)
        get '/amanuensis/meetings'
        expect(response.status).to eq(404)
      end

      it 'blocks an anonymous visitor' do
        get '/amanuensis/meetings'
        expect(response.status).to eq(404)
      end

      it 'allows staff' do
        stub_meetings_index
        sign_in(admin)
        get '/amanuensis/meetings'
        expect(response.status).to eq(200)
      end
    end

    context 'with a viewing group configured' do
      before { SiteSetting.amanuensis_viewing_group = group.name }

      it 'blocks a non-member' do
        sign_in(user)
        get '/amanuensis/meetings'
        expect(response.status).to eq(404)
      end

      it 'allows a member of the group' do
        group.add(user)
        stub_meetings_index
        sign_in(user)
        get '/amanuensis/meetings'
        expect(response.status).to eq(200)
      end

      it 'allows staff regardless of membership' do
        stub_meetings_index
        sign_in(admin)
        get '/amanuensis/meetings'
        expect(response.status).to eq(200)
      end
    end
  end

  describe '#index' do
    before do
      SiteSetting.amanuensis_viewing_group = group.name
      group.add(user)
      sign_in(user)
    end

    it 'renders the meetings returned by the API' do
      stub_meetings_index(meetings: [{ 'id' => 'abc123', 'title' => 'Writers Room Standup', 'source' => 'google_meet', 'status' => 'complete' }])

      get '/amanuensis/meetings'

      expect(response.status).to eq(200)
      expect(response.body).to include('Writers Room Standup')
    end

    it 'surfaces an error when the upstream API fails' do
      stub_request(:get, %r{\Ahttps://amanuensis\.example\.com/v1/plugin/meetings(\?.*)?\z})
        .to_return(status: 500, body: 'boom')

      get '/amanuensis/meetings'

      expect(response.status).to eq(200)
      expect(response.body).to include('Failed to fetch meetings')
    end
  end

  describe '#show' do
    before do
      SiteSetting.amanuensis_viewing_group = group.name
      group.add(user)
      sign_in(user)
    end

    it 'renders meeting detail for a valid id' do
      stub_meeting_show(
        'abc123',
        meeting: {
          'id' => 'abc123',
          'title' => 'Writers Room Standup',
          'source' => 'google_meet',
          'status' => 'complete'
        }
      )

      get '/amanuensis/meetings/abc123'

      expect(response.status).to eq(200)
      expect(response.body).to include('Writers Room Standup')
    end

    it 'surfaces an error when the meeting is not found upstream' do
      stub_request(:get, 'https://amanuensis.example.com/v1/plugin/meetings/missing')
        .to_return(status: 404, body: 'not found')

      get '/amanuensis/meetings/missing'

      expect(response.status).to eq(200)
      expect(response.body).to include('Meeting not found')
    end
  end
end
