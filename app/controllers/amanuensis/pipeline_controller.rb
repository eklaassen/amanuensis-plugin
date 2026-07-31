# frozen_string_literal: true

module Amanuensis
  # "Active now" board -- every meeting currently mid-pipeline, grouped by
  # stage. Expected to be near-empty most of the time; that's the design
  # center, not an edge case (see the empty state in active.html.erb).
  class PipelineController < Amanuensis::ApplicationController
    before_action :ensure_writer

    include Amanuensis::Formatting

    def active
      result = Amanuensis::ApiClient.reader.get('/v1/plugin/pipeline/active')

      if result.ok?
        meetings = result.body['meetings']
        grouped = meetings.group_by { |m| m['status'] }
        # Ordered by pipeline stage; a stage with nothing in it is omitted
        # entirely rather than rendered as an empty section.
        @stage_groups = Amanuensis::PipelineStages::ORDER.filter_map do |stage|
          next if grouped[stage].blank?

          { stage: stage, meetings: grouped[stage] }
        end
      else
        @stage_groups = []
        @error ||= result.error || "Failed to fetch active pipeline (status #{result.status || 'unknown'})"
      end
    end
  end
end
