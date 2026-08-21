# frozen_string_literal: true

module Amanuensis
  # JSON replacement for the old server-rendered OutcomesController --
  # backs the Ember routes at /amanuensis/outcomes and
  # /amanuensis/outcomes/:id (assets/javascripts/discourse/routes/
  # amanuensis-outcomes.js and amanuensis-outcome.js). #index's upstream
  # call and status-filter rules are unchanged from before; only the
  # response format changed.
  class OutcomesApiController < Amanuensis::ApiController
    before_action :ensure_writer
    before_action :validate_status, only: :index

    include Amanuensis::Formatting
    include Amanuensis::ProposalSerialization

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

    MEETING_ID_FORMAT = /\A[\w-]+\z/

    def show
      raise Discourse::NotFound unless params[:id].to_s.match?(MEETING_ID_FORMAT)

      result = Amanuensis::ApiClient.reader.get("/v1/plugin/meetings/#{params[:id]}")

      if result.ok?
        render json: serialize_outcome_detail(result.body)
      else
        render json: { error: result.error || "Outcome not found (status #{result.status || 'unknown'})" },
               status: 502
      end
    end

    private

    def validate_status
      @status = params[:status].presence || 'complete'
      raise Discourse::NotFound unless VALID_STATUSES.include?(@status)
    end

    def serialize_outcome_detail(data)
      meeting = data['meeting']
      proposal = data['proposal']

      {
        meeting: serialize_meeting_ref(meeting),
        proposal: proposal && proposal['items'].present? ? serialize_proposal(proposal) : nil,
        history: (data['history'] || []).map { |h| serialize_history_entry(h) }
      }
    end

    def serialize_meeting_ref(meeting)
      {
        id: meeting['id'],
        title: meeting['title'],
        recorded_at: formatted_date(meeting['recorded_at'])
      }
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
