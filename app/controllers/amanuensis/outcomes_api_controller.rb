# frozen_string_literal: true

module Amanuensis
  # JSON replacement for the old server-rendered OutcomesController --
  # backs the Ember route at /amanuensis/outcomes
  # (assets/javascripts/discourse/routes/amanuensis-outcomes.js). Same
  # upstream call and status-filter rules as before; only the response
  # format changed.
  class OutcomesApiController < Amanuensis::ApiController
    before_action :ensure_writer
    before_action :validate_status

    include Amanuensis::Formatting

    PAGE_SIZE = 25
    VALID_STATUSES = %w[complete failed].freeze

    def index
      params_hash = { limit: PAGE_SIZE, status: @status }
      params_hash[:before] = params[:before] if params[:before].present?

      result = Amanuensis::ApiClient.reader.get('/v1/plugin/meetings', params_hash)

      if result.ok?
        render json: {
          status: @status,
          meetings: result.body['meetings'].map { |m| serialize_meeting(m) },
          pagination: result.body['pagination']
        }
      else
        render json: {
          status: @status,
          meetings: [],
          pagination: { 'has_more' => false },
          error: result.error || "Failed to fetch outcomes (status #{result.status || 'unknown'})"
        }, status: 502
      end
    end

    private

    def validate_status
      @status = params[:status].presence || 'complete'
      raise Discourse::NotFound unless VALID_STATUSES.include?(@status)
    end

    # Formatting happens here, not in JS, so this stays in lockstep with the
    # still-server-rendered meeting/stage pages that use the same
    # Amanuensis::Formatting#formatted_date -- one date format, one place.
    def serialize_meeting(meeting)
      {
        id: meeting['id'],
        title: meeting['title'],
        recorded_at: formatted_date(meeting['recorded_at']),
        status: meeting['status'],
        failure_reason: meeting['failure_reason']
      }
    end
  end
end
