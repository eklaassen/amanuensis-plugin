# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Amanuensis::UploadsApiController, type: :request do
  fab!(:user)
  fab!(:other_user) { Fabricate(:user) }
  fab!(:admin)
  fab!(:group)

  let(:valid_payload) do
    {
      filename: 'interview.m4a',
      size_bytes: 2048,
      title: "Writers' Room",
      recorded_at: '2026-08-01T19:00:00Z'
    }
  end

  before do
    SiteSetting.amanuensis_enabled = true
    SiteSetting.amanuensis_api_url = 'https://amanuensis.example.com'
    SiteSetting.amanuensis_api_secret = 'read-secret'
    SiteSetting.amanuensis_admin_key = 'admin-secret'
    SiteSetting.amanuensis_viewing_group = ''
    SiteSetting.amanuensis_writing_group = group.name
    RateLimiter.enable
  end

  after { RateLimiter.disable }

  def stub_presign(status: 201, body: { upload_id: 'upl_1', upload_url: 'https://s3.example.com/signed' })
    stub_request(:post, 'https://amanuensis.example.com/v1/plugin/uploads')
      .to_return(status: status, headers: { 'Content-Type' => 'application/json' }, body: body.to_json)
  end

  def stub_complete(id: 'upl_1', status: 201, body: { meeting_id: 'upl_1' })
    stub_request(:post, "https://amanuensis.example.com/v1/plugin/uploads/#{id}/complete")
      .to_return(status: status, headers: { 'Content-Type' => 'application/json' }, body: body.to_json)
  end

  describe 'access control' do
    it 'blocks an anonymous visitor' do
      post '/amanuensis/api/uploads', params: valid_payload
      expect(response.status).to eq(403)
    end

    it 'blocks a signed-in non-writer' do
      sign_in(user)
      post '/amanuensis/api/uploads', params: valid_payload
      expect(response.status).to eq(403)
    end

    it 'allows a member of the writing group' do
      group.add(user)
      stub_presign
      sign_in(user)

      post '/amanuensis/api/uploads', params: valid_payload

      expect(response.status).to eq(200)
    end

    it 'allows staff regardless of membership' do
      stub_presign
      sign_in(admin)

      post '/amanuensis/api/uploads', params: valid_payload

      expect(response.status).to eq(200)
    end
  end

  describe '#create' do
    before do
      group.add(user)
      sign_in(user)
    end

    it 'returns the presigned url and upload id' do
      stub_presign
      post '/amanuensis/api/uploads', params: valid_payload

      expect(response.parsed_body['upload_id']).to eq('upl_1')
      expect(response.parsed_body['upload_url']).to eq('https://s3.example.com/signed')
    end

    it 'authenticates upstream with the admin key, not the read secret' do
      stub_presign
      post '/amanuensis/api/uploads', params: valid_payload

      expect(
        a_request(:post, 'https://amanuensis.example.com/v1/plugin/uploads')
          .with(headers: { 'Authorization' => 'Bearer admin-secret' })
      ).to have_been_made
    end

    it 'rejects a disallowed extension without calling upstream' do
      stub_presign
      post '/amanuensis/api/uploads', params: valid_payload.merge(filename: 'notes.pdf')

      expect(response.status).to eq(422)
      expect(a_request(:post, 'https://amanuensis.example.com/v1/plugin/uploads')).not_to have_been_made
    end

    it 'rejects a file over the cap without calling upstream' do
      stub_presign
      post '/amanuensis/api/uploads',
           params: valid_payload.merge(size_bytes: Amanuensis::UploadPolicy::MAX_BYTES + 1)

      expect(response.status).to eq(422)
      expect(a_request(:post, 'https://amanuensis.example.com/v1/plugin/uploads')).not_to have_been_made
    end

    it 'surfaces an upstream failure as a 502' do
      stub_presign(status: 500, body: {})
      post '/amanuensis/api/uploads', params: valid_payload

      expect(response.status).to eq(502)
      expect(response.parsed_body['errors']).to be_present
    end
  end

  describe '#complete' do
    before do
      group.add(user)
      sign_in(user)
    end

    def presign_as(signed_in_user)
      sign_in(signed_in_user)
      stub_presign
      post '/amanuensis/api/uploads', params: valid_payload
    end

    it 'completes an upload the caller owns' do
      presign_as(user)
      stub_complete

      post '/amanuensis/api/uploads/upl_1/complete', params: valid_payload

      expect(response.status).to eq(200)
      expect(response.parsed_body['meeting_id']).to eq('upl_1')
    end

    it 'refuses to complete an upload belonging to another writer' do
      # Without the ownership claim, writer B could finish writer A's upload
      # just by knowing the id -- upstream has no notion of Discourse users.
      group.add(other_user)
      presign_as(other_user)
      stub_complete

      sign_in(user)
      post '/amanuensis/api/uploads/upl_1/complete', params: valid_payload

      expect(response.status).to eq(403)
      expect(
        a_request(:post, 'https://amanuensis.example.com/v1/plugin/uploads/upl_1/complete')
      ).not_to have_been_made
    end

    it 'refuses an upload id that was never issued' do
      stub_complete(id: 'never-issued')

      post '/amanuensis/api/uploads/never-issued/complete', params: valid_payload

      expect(response.status).to eq(403)
    end

    it 'refuses an upload id with characters outside the allowed format' do
      # The id is interpolated into the upstream URL, so anything outside
      # [\w-] is refused before the request is built. Note an encoded-slash
      # id (`..%2F..%2Fadmin`) never gets this far -- Rails will not match a
      # path segment containing a slash, so routing rejects it first. This
      # guard is the second layer, covering everything that does route.
      stub_request(:post, %r{amanuensis\.example\.com}).to_return(status: 201, body: '{}')

      post '/amanuensis/api/uploads/abc%20def/complete', params: valid_payload

      expect(response.status).to eq(403)
      expect(a_request(:post, %r{amanuensis\.example\.com})).not_to have_been_made
    end
  end
end
