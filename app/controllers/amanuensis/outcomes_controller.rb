# frozen_string_literal: true

module Amanuensis
  # Finished meetings, filtered to exactly one of complete/failed --
  # GET /v1/plugin/meetings?status= is a single-value equality filter, so
  # there is no clean way to ask it for "complete OR failed" (a true "all
  # finished, no in-progress" view) without either a second endpoint or a
  # client-side merge that degrades pagination. Two tabs, not three.
  class OutcomesController < Amanuensis::ApplicationController
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
        @meetings = result.body['meetings']
        @pagination = result.body['pagination']
      else
        @meetings = []
        @pagination = { 'has_more' => false }
        @error ||= result.error || "Failed to fetch outcomes (status #{result.status || 'unknown'})"
      end
    end

    private

    def validate_status
      @status = params[:status].presence || 'complete'
      raise Discourse::NotFound unless VALID_STATUSES.include?(@status)
    end
  end
end
