# frozen_string_literal: true

module Amanuensis
  class StagesController < Amanuensis::ApplicationController
    before_action :ensure_writer
    before_action :validate_stage

    include Amanuensis::Formatting

    PAGE_SIZE = 25

    def show
      params_hash = { limit: PAGE_SIZE }
      params_hash[:before] = params[:before] if params[:before].present?
      params_hash[:outcome] = params[:outcome] if params[:outcome].present?

      result = Amanuensis::ApiClient.reader.get("/v1/plugin/stages/#{params[:stage]}/runs", params_hash)

      if result.ok?
        @runs = result.body['runs']
        @pagination = result.body['pagination']
      else
        @runs = []
        @pagination = { 'has_more' => false }
        @error ||= result.error || "Failed to fetch stage runs (status #{result.status || 'unknown'})"
      end
    end

    RUN_ID_FORMAT = /\A[\w-]+\z/

    def run
      raise Discourse::NotFound unless params[:run_id].to_s.match?(RUN_ID_FORMAT)

      result = Amanuensis::ApiClient.reader.get("/v1/plugin/stages/#{params[:stage]}/runs/#{params[:run_id]}")

      if result.ok?
        @run = result.body
        # The meeting's full timeline for the "other stage runs" card --
        # already carried on the meeting-detail response, so no new endpoint
        # is needed here.
        @other_runs = fetch_other_runs(@run['meeting_id'])
      else
        @error ||= result.error || "Stage run not found (status #{result.status || 'unknown'})"
      end
    end

    private

    def validate_stage
      raise Discourse::NotFound unless Amanuensis::PipelineStages::ORDER.include?(params[:stage])
    end

    # meeting_id is a NOT NULL FK on stage_runs, so a well-formed upstream
    # response always has one -- but this guards the case anyway rather
    # than build "/v1/plugin/meetings/" (a malformed request) from a blank
    # value. Degrades gracefully (no meeting link, no timeline) instead of
    # 404ing the whole page over one missing nested field on an otherwise
    # successful response.
    def fetch_other_runs(meeting_id)
      return [] if meeting_id.blank?

      meeting_result = Amanuensis::ApiClient.reader.get("/v1/plugin/meetings/#{meeting_id}")
      meeting_result.ok? ? meeting_result.body['stage_runs'] : []
    end
  end
end
