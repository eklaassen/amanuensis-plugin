# frozen_string_literal: true

module Amanuensis
  # Thin HTTP client for the Amanuensis API. Generalizes what used to be
  # MeetingsController#api_get into something specs, jobs, and future
  # controllers can all use.
  #
  # Two separate constructors -- .reader and .admin -- rather than a single
  # constructor with a boolean flag. The admin key is the presign/ingestion
  # credential; a flag with a default (`admin: false`) is exactly the kind
  # of thing that gets flipped by accident. Making the two credentials come
  # from two differently-named entry points removes that failure mode.
  class ApiClient
    Result = Struct.new(:status, :body, :error) do
      def ok?
        error.nil? && status.to_i.between?(200, 299)
      end
    end

    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 15

    # The narrow, deliberate rescue list from the original api_get, plus
    # the TLS/DNS/truncated-response failure modes a real HTTPS call to an
    # external host can hit. Not StandardError -- a bug in this client
    # should raise, not be swallowed as an upstream failure.
    RESCUED_ERRORS = [
      Net::OpenTimeout,
      Net::ReadTimeout,
      Errno::ECONNREFUSED,
      Errno::EHOSTUNREACH,
      OpenSSL::SSL::SSLError,
      SocketError,
      EOFError
    ].freeze

    HTTP_METHODS = {
      get: Net::HTTP::Get,
      post: Net::HTTP::Post,
      patch: Net::HTTP::Patch,
      delete: Net::HTTP::Delete
    }.freeze

    def self.reader
      new(SiteSetting.amanuensis_api_url, SiteSetting.amanuensis_api_secret)
    end

    def self.admin
      new(SiteSetting.amanuensis_api_url, SiteSetting.amanuensis_admin_key)
    end

    private_class_method :new

    def get(path, params = {})
      request(:get, path, query: params)
    end

    def post(path, body = {}, idempotency_key: nil)
      request(:post, path, body: body, idempotency_key: idempotency_key)
    end

    def patch(path, body = {}, idempotency_key: nil)
      request(:patch, path, body: body, idempotency_key: idempotency_key)
    end

    def delete(path, params = {})
      request(:delete, path, query: params)
    end

    private

    def initialize(base_url, secret)
      @base_url = base_url
      @secret = secret
    end

    def request(verb, path, query: {}, body: nil, idempotency_key: nil)
      return not_configured_result if @base_url.blank? || @secret.blank?

      uri = URI.join(@base_url, path)
      uri.query = URI.encode_www_form(query) if query.present?

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'
      http.open_timeout = OPEN_TIMEOUT
      http.read_timeout = READ_TIMEOUT

      response = http.request(build_request(verb, uri, body: body, idempotency_key: idempotency_key))
      Result.new(response.code.to_i, parse_body(response.body), nil)
    rescue *RESCUED_ERRORS => e
      Result.new(nil, nil, "Could not reach Amanuensis API: #{e.message}")
    rescue URI::InvalidURIError
      Result.new(nil, nil, 'Invalid Amanuensis API URL configured.')
    end

    def build_request(verb, uri, body:, idempotency_key:)
      request = HTTP_METHODS.fetch(verb).new(uri)
      request['Authorization'] = "Bearer #{@secret}"
      request['Accept'] = 'application/json'

      if body
        request['Content-Type'] = 'application/json'
        request.body = body.to_json
      end

      request['Idempotency-Key'] = idempotency_key if idempotency_key.present?
      request
    end

    def parse_body(raw)
      return nil if raw.blank?

      JSON.parse(raw)
    rescue JSON::ParserError
      nil
    end

    def not_configured_result
      Result.new(nil, nil, 'Amanuensis API is not configured (missing base URL or credential).')
    end
  end
end
