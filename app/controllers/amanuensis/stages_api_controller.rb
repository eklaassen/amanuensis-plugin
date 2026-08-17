# frozen_string_literal: true

module Amanuensis
  # JSON replacement for the old server-rendered StagesController -- backs
  # the Ember routes at /amanuensis/stages/:stage and
  # /amanuensis/stages/:stage/runs/:run_id
  # (assets/javascripts/discourse/routes/amanuensis-stage-runs.js and
  # amanuensis-stage-run.js).
  class StagesApiController < Amanuensis::ApiController
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
        render json: {
          stage: params[:stage],
          stage_label: humanize_stage(params[:stage]),
          observable_stages: observable_stages,
          runs: result.body['runs'].map { |r| serialize_run_summary(r) },
          pagination: result.body['pagination']
        }
      else
        render json: {
          stage: params[:stage],
          stage_label: humanize_stage(params[:stage]),
          observable_stages: observable_stages,
          runs: [],
          pagination: { 'has_more' => false },
          error: result.error || "Failed to fetch stage runs (status #{result.status || 'unknown'})"
        }
      end
    end

    RUN_ID_FORMAT = /\A[\w-]+\z/

    def run
      raise Discourse::NotFound unless params[:run_id].to_s.match?(RUN_ID_FORMAT)

      result = Amanuensis::ApiClient.reader.get("/v1/plugin/stages/#{params[:stage]}/runs/#{params[:run_id]}")

      if result.ok?
        run = result.body
        render json: {
          stage: params[:stage],
          stage_label: humanize_stage(params[:stage]),
          run: serialize_run_detail(run),
          other_runs: fetch_other_runs(run['meeting_id']).map { |r| timeline_run(r) }
        }
      else
        render json: {
          stage: params[:stage],
          stage_label: humanize_stage(params[:stage]),
          error: result.error || "Stage run not found (status #{result.status || 'unknown'})"
        }
      end
    end

    private

    def validate_stage
      raise Discourse::NotFound unless Amanuensis::PipelineStages::ORDER.include?(params[:stage])
    end

    # The stage-switcher chips at the top of the runs list -- sent from the
    # server instead of duplicated as a literal in JS so the UI can't drift
    # from Amanuensis::PipelineStages::OBSERVABLE the way the pipeline
    # stage order already has to be hand-kept in sync with a different repo
    # (see that module's own comment).
    def observable_stages
      Amanuensis::PipelineStages::OBSERVABLE.map { |stage| { value: stage, label: humanize_stage(stage) } }
    end

    # meeting_id is a NOT NULL FK on stage_runs, so a well-formed upstream
    # response always has one -- but this guards the case anyway rather
    # than build "/v1/plugin/meetings/" (a malformed request) from a blank
    # value. Degrades gracefully (no meeting link, no timeline) instead of
    # erroring the whole page over one missing nested field on an otherwise
    # successful response.
    def fetch_other_runs(meeting_id)
      return [] if meeting_id.blank?

      meeting_result = Amanuensis::ApiClient.reader.get("/v1/plugin/meetings/#{meeting_id}")
      meeting_result.ok? ? meeting_result.body['stage_runs'] : []
    end

    def serialize_run_summary(run)
      {
        id: run['id'],
        meeting_id: run['meeting_id'],
        meeting_title: run['meeting_title'],
        started_at: formatted_date(run['started_at']),
        duration: run['duration_ms'] ? format_duration_ms(run['duration_ms']) : nil,
        attempt: run['attempt'],
        outcome: run['outcome'],
        failure_reason: run['failure_reason'],
        inferred: run['inferred']
      }
    end

    def serialize_run_detail(run)
      {
        id: run['id'],
        meeting_id: run['meeting_id'],
        meeting_title: run['meeting_title'],
        stage: run['stage'],
        stage_label: humanize_stage(run['stage']),
        outcome: run['outcome'],
        attempt: run['attempt'],
        started_at: formatted_date(run['started_at']),
        finished_at: run['finished_at'] ? formatted_date(run['finished_at']) : nil,
        duration: run['duration_ms'] ? format_duration_ms(run['duration_ms']) : nil,
        job_id: run['job_id'],
        rewind_to: run['rewind_to'],
        rewind_to_label: run['rewind_to'] ? humanize_stage(run['rewind_to']) : nil,
        inferred: run['inferred'],
        error_code: run['error_code'],
        failure_reason: run['failure_reason']
      }
    end
  end
end
