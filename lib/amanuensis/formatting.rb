# frozen_string_literal: true

module Amanuensis
  # Shared view-formatting helpers used by every server-rendered controller.
  # Extracted from MeetingsController now that PipelineController/
  # StagesController/OutcomesController need formatted_date/format_duration
  # too -- deliberately excludes formatters only one page needs
  # (speaker_color_style, sanitized_summary -- meetings-only, stay put).
  module Formatting
    extend ActiveSupport::Concern

    included do
      helper_method :formatted_date, :format_duration, :format_duration_ms, :humanize_stage,
                    :relative_time
    end

    private

    def formatted_date(iso_string)
      return '' if iso_string.nil?

      Time.parse(iso_string).strftime('%B %d, %Y at %I:%M %p')
    rescue ArgumentError
      iso_string.to_s
    end

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

    RELATIVE_TIME_INTERVALS = [
      [31_536_000, 'year'],
      [2_592_000, 'month'],
      [604_800, 'week'],
      [86_400, 'day'],
      [3_600, 'hour'],
      [60, 'minute']
    ].freeze

    def relative_time(iso_string)
      return '' if iso_string.nil?

      seconds = (Time.now - Time.parse(iso_string)).to_i
      return 'just now' if seconds < 5

      RELATIVE_TIME_INTERVALS.each do |(secs_per_unit, name)|
        count = seconds / secs_per_unit
        return "#{count} #{name.pluralize(count)} ago" if count >= 1
      end

      "#{seconds} #{'second'.pluralize(seconds)} ago"
    rescue ArgumentError
      ''
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
        started_at: formatted_date(run['started_at']),
        duration: run['duration_ms'] ? format_duration_ms(run['duration_ms']) : nil,
        attempt_note: attempt > 1 ? "attempt #{attempt}" : nil,
        failure_reason: run['failure_reason'],
        inferred: run['inferred']
      }
    end
  end
end
