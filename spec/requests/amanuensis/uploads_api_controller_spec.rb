# frozen_string_literal: true

require 'rails_helper'
require_relative '../../support/plugin_contract'

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

  # The secret value a given fixture credential (:admin/:reader) resolves to
  # under this file's SiteSettings -- not hardcoded, so a contract change
  # (say, this route moving from adminSecret to pluginSecret) changes what
  # every stub below expects without anyone having to notice and update a
  # literal string.
  def secret_for(credential)
    credential == :admin ? SiteSetting.amanuensis_admin_key : SiteSetting.amanuensis_api_secret
  end

  # .with(headers:) here is load-bearing, not incidental: every example in
  # this file calls stub_presign, so if the controller ever regressed to the
  # wrong credential, WebMock would refuse to match ANY of them ("no stub
  # matched") instead of the drift being invisible to everything but one
  # dedicated example.
  def stub_presign(status: 201,
                   body: { upload_id: 'upl_1', upload_url: 'https://s3.example.com/signed',
                           content_type: 'audio/mp4' })
    credential = Amanuensis::PluginContractFixture.credential_for(method: 'POST', path: '/v1/plugin/uploads')
    stub_request(:post, 'https://amanuensis.example.com/v1/plugin/uploads')
      .with(headers: { 'Authorization' => "Bearer #{secret_for(credential)}" })
      .to_return(status: status, headers: { 'Content-Type' => 'application/json' }, body: body.to_json)
  end

  def stub_complete(id: 'upl_1', status: 201, body: { meeting_id: 'upl_1' })
    credential = Amanuensis::PluginContractFixture.credential_for(
      method: 'POST', path: '/v1/plugin/uploads/:upload_id/complete'
    )
    stub_request(:post, "https://amanuensis.example.com/v1/plugin/uploads/#{id}/complete")
      .with(headers: { 'Authorization' => "Bearer #{secret_for(credential)}" })
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

  describe '#upload_config' do
    it 'blocks a signed-in non-writer' do
      sign_in(user)
      get '/amanuensis/api/uploads/config'
      expect(response.status).to eq(403)
    end

    it 'returns the size cap and allowed extensions for a writer' do
      group.add(user)
      sign_in(user)

      get '/amanuensis/api/uploads/config'

      expect(response.status).to eq(200)
      expect(response.parsed_body['max_bytes']).to eq(Amanuensis::UploadPolicy::MAX_BYTES)
      expect(response.parsed_body['allowed_extensions']).to eq(Amanuensis::UploadPolicy::ALLOWED_EXTENSIONS)
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

    it 'passes the signed content type through for the browser to echo' do
      # Content-Type is a signed header on the presigned PUT. Without this the
      # browser sends whatever it infers from the file and S3 rejects it.
      stub_presign
      post '/amanuensis/api/uploads', params: valid_payload

      expect(response.parsed_body['content_type']).to eq('audio/mp4')
    end

    it 'authenticates upstream with the admin key, not the read secret' do
      # Redundant with stub_presign's own header matcher now (a wrong
      # credential would fail the `post` call itself, not just this
      # assertion) -- kept explicit since it's the clearest statement of
      # intent for anyone reading this file.
      stub_presign
      post '/amanuensis/api/uploads', params: valid_payload

      credential = Amanuensis::PluginContractFixture.credential_for(method: 'POST', path: '/v1/plugin/uploads')
      expect(
        a_request(:post, 'https://amanuensis.example.com/v1/plugin/uploads')
          .with(headers: { 'Authorization' => "Bearer #{secret_for(credential)}" })
      ).to have_been_made
    end

    it 'sends a request body that matches the contract schema for this route' do
      captured_body = nil
      stub_request(:post, 'https://amanuensis.example.com/v1/plugin/uploads')
        .with { |request| captured_body = JSON.parse(request.body); true }
        .to_return(status: 201, headers: { 'Content-Type' => 'application/json' },
                   body: { upload_id: 'upl_1', upload_url: 'https://s3.example.com/signed',
                           content_type: 'audio/mp4' }.to_json)

      post '/amanuensis/api/uploads', params: valid_payload

      violations = Amanuensis::PluginContractFixture.schema_violations(
        method: 'POST', path: '/v1/plugin/uploads', body: captured_body
      )
      expect(violations).to be_empty
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

    it 'authenticates the complete call upstream with the admin key, not the read secret' do
      # The presign call already had this assertion; the complete call
      # didn't -- a gap noted in amanuensis-plugin#39's evidence.
      presign_as(user)
      stub_complete

      post '/amanuensis/api/uploads/upl_1/complete', params: valid_payload

      credential = Amanuensis::PluginContractFixture.credential_for(
        method: 'POST', path: '/v1/plugin/uploads/:upload_id/complete'
      )
      expect(
        a_request(:post, 'https://amanuensis.example.com/v1/plugin/uploads/upl_1/complete')
          .with(headers: { 'Authorization' => "Bearer #{secret_for(credential)}" })
      ).to have_been_made
    end

    it 'sends a request body that matches the contract schema for this route' do
      presign_as(user)
      captured_body = nil
      stub_request(:post, 'https://amanuensis.example.com/v1/plugin/uploads/upl_1/complete')
        .with { |request| captured_body = JSON.parse(request.body); true }
        .to_return(status: 201, headers: { 'Content-Type' => 'application/json' },
                   body: { meeting_id: 'upl_1' }.to_json)

      post '/amanuensis/api/uploads/upl_1/complete', params: valid_payload

      violations = Amanuensis::PluginContractFixture.schema_violations(
        method: 'POST', path: '/v1/plugin/uploads/:upload_id/complete', body: captured_body
      )
      expect(violations).to be_empty
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
