# frozen_string_literal: true

module Amanuensis
  class MeetingsController < Amanuensis::ApplicationController
    before_action :ensure_viewer

    helper_method :formatted_date, :format_duration, :speaker_color_style, :format_value, :sanitized_summary

    PAGE_SIZE = 25

    def index
      params_hash = { limit: PAGE_SIZE }
      params_hash[:before] = params[:before] if params[:before].present?
      params_hash[:status] = params[:status] if params[:status].present?

      result = Amanuensis::ApiClient.reader.get('/v1/plugin/meetings', params_hash)

      if result.ok?
        @meetings = result.body['meetings']
        @pagination = result.body['pagination']
      else
        @meetings = []
        @pagination = { 'has_more' => false }
        @error ||= result.error || "Failed to fetch meetings (status #{result.status || 'unknown'})"
      end
    end

    MEETING_ID_FORMAT = /\A[\w-]+\z/

    def show
      raise Discourse::NotFound unless params[:id].to_s.match?(MEETING_ID_FORMAT)

      result = Amanuensis::ApiClient.reader.get("/v1/plugin/meetings/#{params[:id]}")

      if result.ok?
        @data = result.body
        @meeting = @data['meeting']
        @proposal = @data['proposal']
        @history = @data['history']
        @notesbot_turns = @meeting['notesbot_turns']

        if @meeting['source'] == 'notesbot' && @notesbot_turns.present?
          @grouped_turns = @notesbot_turns.group_by { |t| t['speaker'] }
        end
      else
        @error ||= result.error || "Meeting not found (status #{result.status || 'unknown'})"
      end
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

    SPEAKER_COLORS = %w[
      #4A90D9 #E8734A #50B86C #D94A8E #B86CE8
      #4AD9C8 #E8B04A #6CB850 #D94A4A #4A6CD9
    ].freeze

    def speaker_color_style(speaker)
      return '' if speaker.blank?

      hash = speaker.each_char.map(&:ord).sum
      color = SPEAKER_COLORS[hash % SPEAKER_COLORS.length]
      "border-left-color: #{color}; color: #{color};"
    end

    def format_value(value)
      case value
      when Hash, Array
        value.to_json
      when nil
        '—'
      else
        value.to_s
      end
    end

    def sanitized_summary(summary)
      Amanuensis::Sanitizer.sanitize_summary(summary)
    end
  end
end
