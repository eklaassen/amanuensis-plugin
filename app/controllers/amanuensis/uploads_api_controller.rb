# frozen_string_literal: true

module Amanuensis
  # JSON endpoints backing the upload page. The browser PUTs the file straight
  # to storage using a presigned URL minted upstream, so bytes never pass
  # through Discourse -- these two actions only bracket that transfer.
  class UploadsApiController < ApiController
    before_action :ensure_writer

    # The presigned URL is a write credential, so minting one is rate limited
    # far more tightly than confirming an upload that already happened.
    PRESIGN_LIMIT_PER_HOUR = 10
    COMPLETE_LIMIT_PER_HOUR = 60

    # Long enough to cover a slow 1.5 GiB upload, short enough that a
    # forgotten ticket does not linger.
    OWNERSHIP_TTL = 6.hours

    # Same guard as MeetingsController::MEETING_ID_FORMAT and
    # StagesController::RUN_ID_FORMAT: this id is interpolated into an upstream
    # URL, so `../..` in it would traverse to a different endpoint. The
    # ownership check below already rejects any id we did not mint, but that
    # leaves one check between user input and the URL -- and a later refactor
    # that moves or bypasses it would silently make traversal reachable.
    UPLOAD_ID_FORMAT = /\A[\w-]+\z/

    def create
      RateLimiter.new(current_user, 'amanuensis-upload-presign', PRESIGN_LIMIT_PER_HOUR, 1.hour).performed!

      filename = UploadPolicy.sanitize_filename(params[:filename])
      UploadPolicy.validate!(filename: filename, size_bytes: params[:size_bytes])

      # Braces are load-bearing: post's signature is (path, body = {},
      # idempotency_key:), so bare `filename:` etc. bind as keyword arguments
      # and raise ArgumentError instead of becoming the body hash.
      result = ApiClient.admin.post(
        '/v1/plugin/uploads',
        {
          filename: filename,
          size_bytes: params[:size_bytes].to_i,
          title: upload_title,
          recorded_at: recorded_at
        }
      )

      return render_upstream_error(result) unless result.ok?

      upload_id = result.body['upload_id']
      claim_ownership(upload_id)

      # content_type is passed through because the browser has to echo it as
      # the PUT's Content-Type: it is a signed header, so anything else
      # (audio/x-m4a rather than audio/mp4, or nothing) fails the signature.
      #
      # upload_url is a bearer credential -- it goes back in the XHR body and
      # nowhere else (no href, no attribute, nothing that leaks via Referer).
      render json: {
        upload_id: upload_id,
        upload_url: result.body['upload_url'],
        content_type: result.body['content_type']
      }
    rescue UploadPolicy::Rejected => e
      render json: { errors: [e.message] }, status: 422
    end

    def complete
      RateLimiter.new(current_user, 'amanuensis-upload-complete', COMPLETE_LIMIT_PER_HOUR, 1.hour).performed!

      upload_id = params[:upload_id].to_s
      raise Discourse::InvalidAccess unless upload_id.match?(UPLOAD_ID_FORMAT)
      raise Discourse::InvalidAccess unless owns_upload?(upload_id)

      filename = UploadPolicy.sanitize_filename(params[:filename])
      UploadPolicy.validate!(filename: filename, size_bytes: params[:size_bytes])

      result = ApiClient.admin.post(
        "/v1/plugin/uploads/#{upload_id}/complete",
        {
          filename: filename,
          title: upload_title,
          recorded_at: recorded_at
        }
      )

      return render_upstream_error(result) unless result.ok?

      release_ownership(upload_id)
      render json: { meeting_id: result.body['meeting_id'] }
    rescue UploadPolicy::Rejected => e
      render json: { errors: [e.message] }, status: 422
    end

    private

    def upload_title
      params[:title].presence || I18n.t('amanuensis.uploads.default_title')
    end

    def recorded_at
      parsed = Time.zone.parse(params[:recorded_at].to_s)
      (parsed || Time.zone.now).iso8601
    rescue ArgumentError
      Time.zone.now.iso8601
    end

    # Without this, writer B could complete writer A's upload by guessing an
    # id -- the upstream complete call has no notion of which Discourse user
    # requested the presign.
    def ownership_key(upload_id)
      "amanuensis:upload:#{upload_id}:owner"
    end

    def claim_ownership(upload_id)
      return if upload_id.blank?

      Discourse.redis.setex(ownership_key(upload_id), OWNERSHIP_TTL.to_i, current_user.id)
    end

    def owns_upload?(upload_id)
      return false if upload_id.blank?

      Discourse.redis.get(ownership_key(upload_id)).to_i == current_user.id
    end

    def release_ownership(upload_id)
      Discourse.redis.del(ownership_key(upload_id))
    end

    def render_upstream_error(result)
      message = result.error.presence || I18n.t('amanuensis.uploads.errors.upstream',
                                                status: result.status || 'unknown')
      render json: { errors: [message] }, status: 502
    end
  end
end
