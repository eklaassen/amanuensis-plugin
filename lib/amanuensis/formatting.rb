# frozen_string_literal: true

module Amanuensis
  # Shared view-formatting helpers used by every server-rendered controller.
  # Extracted from MeetingsController now that PipelineController/
  # StagesController/OutcomesController need format_duration too --
  # deliberately excludes formatters only one page needs
  # (speaker_color_style, sanitized_summary -- meetings-only, stay put).
  #
  # Timestamps are deliberately NOT formatted here -- they're passed through
  # as the raw ISO-8601 UTC string the upstream Amanuensis API returns, and
  # rendered in the viewing user's timezone client-side (see
  # <AmanuensisLocalTime>), which also needs the raw UTC value for its hover
  # tooltip.
  module Formatting
    extend ActiveSupport::Concern

    included do
      helper_method :format_duration, :format_duration_ms, :humanize_stage
    end

    private

    def format_duration(seconds)
      return '' if seconds.nil?

      hrs = seconds / 3600
      mins = (seconds % 3600) / 60
      secs = seconds % 60

      if hrs > 0
        format('%dh %dm', hrs, mins)
      elsif mins > 0
        format('%dm %ds', mins, secs)
      else
        format('%ds', secs)
      end
    end

    # stage_runs.duration_ms is milliseconds; format_duration takes seconds.
    def format_duration_ms(ms)
      return '' if ms.nil?

      format_duration(ms / 1000)
    end

    def humanize_stage(stage)
      stage.to_s.humanize
    end

    # Shared shape for a stage_runs entry as consumed by the
    # <AmanuensisStageTimeline> Ember component -- used by both
    # StagesApiController (a stage run's "other runs" for the same meeting)
    # and MeetingsApiController (a meeting's full pipeline timeline). Same
    # upstream record shape in both places, so one serializer.
    def timeline_run(run)
      attempt = run['attempt'].to_i
      {
        stage_label: humanize_stage(run['stage']),
        outcome: run['outcome'],
        started_at: run['started_at'],
        duration: run['duration_ms'] ? format_duration_ms(run['duration_ms']) : nil,
        attempt_note: attempt > 1 ? "attempt #{attempt}" : nil,
        failure_reason: run['failure_reason'],
        inferred: run['inferred']
      }
    end
  end
end
