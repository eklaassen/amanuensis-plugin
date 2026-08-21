# frozen_string_literal: true

module Amanuensis
  # JSON replacement for the old server-rendered PipelineController -- backs
  # the Ember route at /amanuensis/pipeline
  # (assets/javascripts/discourse/routes/amanuensis-pipeline.js). "Active
  # now" board -- every meeting currently mid-pipeline, grouped by stage.
  # Expected to be near-empty most of the time; that's the design center,
  # not an edge case (see the empty state in the template).
  class PipelineApiController < Amanuensis::ApiController
    before_action :ensure_writer

    include Amanuensis::Formatting

    def active
      result = Amanuensis::ApiClient.reader.get('/v1/plugin/pipeline/active')

      if result.ok?
        meetings = result.body['meetings']
        grouped = meetings.group_by { |m| m['status'] }
        # Ordered by pipeline stage; a stage with nothing in it is omitted
        # entirely rather than rendered as an empty section.
        stage_groups = Amanuensis::PipelineStages::ORDER.filter_map do |stage|
          next if grouped[stage].blank?

          { stage: stage, stage_label: humanize_stage(stage), meetings: grouped[stage].map { |m| serialize_meeting(m) } }
        end

        render json: { stage_groups: stage_groups }
      else
        render json: {
          stage_groups: [],
          error: result.error || "Failed to fetch active pipeline (status #{result.status || 'unknown'})"
        }, status: 502
      end
    end

    private

    def serialize_meeting(meeting)
      attempt = meeting['current_stage_attempt'].to_i
      {
        id: meeting['id'],
        title: meeting['title'],
        source_label: meeting['source'].to_s.humanize,
        updated_relative: relative_time(meeting['updated_at']),
        attempt_note: attempt > 1 ? "attempt #{attempt}" : nil
      }
    end
  end
end
