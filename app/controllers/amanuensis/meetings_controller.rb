# frozen_string_literal: true

module Amanuensis
  class MeetingsController < ::ApplicationController
    requires_plugin Amanuensis::PLUGIN_NAME
    helper_method :formatted_date, :format_duration, :speaker_color_style, :format_value, :sanitized_summary

    SUMMARY_ALLOWED_TAGS = %w[p br strong em b i ul ol li h3 h4 blockquote a].freeze
    SUMMARY_ALLOWED_ATTRIBUTES = %w[href].freeze

    before_action :ensure_plugin_enabled
    before_action :ensure_viewing_group_member
    before_action :fetch_from_api, only: %i[index show]

    PAGE_SIZE = 25

    def index
      params_hash = { limit: PAGE_SIZE }
      params_hash[:before] = params[:before] if params[:before].present?
      params_hash[:status] = params[:status] if params[:status].present?

      resp = api_get('/v1/plugin/meetings', params_hash)

      if resp&.code == '200'
        body = JSON.parse(resp.body)
        @meetings = body['meetings']
        @pagination = body['pagination']
      else
        @meetings = []
        @pagination = { 'has_more' => false }
        @error ||= "Failed to fetch meetings (status #{resp&.code || 'unknown'})"
      end

      render layout: false
    end

    MEETING_ID_FORMAT = /\A[\w-]+\z/

    def show
      raise Discourse::NotFound unless params[:id].to_s.match?(MEETING_ID_FORMAT)

      resp = api_get("/v1/plugin/meetings/#{params[:id]}")

      if resp&.code == '200'
        @data = JSON.parse(resp.body)
        @meeting = @data['meeting']
        @proposal = @data['proposal']
        @history = @data['history']
        @notesbot_turns = @meeting['notesbot_turns']

        if @meeting['source'] == 'notesbot' && @notesbot_turns.present?
          @grouped_turns = @notesbot_turns.group_by { |t| t['speaker'] }
        end
      else
        @error ||= "Meeting not found (status #{resp&.code || 'unknown'})"
      end

      render layout: false
    end

    private

    def ensure_plugin_enabled
      raise Discourse::NotFound unless SiteSetting.amanuensis_enabled
    end

    def ensure_viewing_group_member
      return if current_user&.staff?

      group_name = SiteSetting.amanuensis_viewing_group
      raise Discourse::NotFound if group_name.blank?
      raise Discourse::NotFound if current_user.nil?

      group = Group.find_by(name: group_name)
      raise Discourse::NotFound if group.nil?
      raise Discourse::NotFound unless group.group_users.exists?(user_id: current_user.id)
    rescue Discourse::NotFound
      render plain: 'Not found', status: 404
    end

    def fetch_from_api
      @api_url = SiteSetting.amanuensis_api_url
      @api_secret = SiteSetting.amanuensis_api_secret

      if @api_url.blank? || @api_secret.blank?
        @error = 'Amanuensis plugin is not configured. Please set API URL and secret in settings.'
      end
    end

    def api_get(path, params = {})
      return nil if @api_url.blank? || @api_secret.blank?

      uri = URI.join(@api_url, path)
      uri.query = URI.encode_www_form(params) if params.any?

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'
      http.open_timeout = 5
      http.read_timeout = 15

      request = Net::HTTP::Get.new(uri)
      request['Authorization'] = "Bearer #{@api_secret}"
      request['Accept'] = 'application/json'

      response = http.request(request)
      response
    rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED, Errno::EHOSTUNREACH => e
      @error = "Could not reach Amanuensis API: #{e.message}"
      nil
    rescue URI::InvalidURIError
      @error = 'Invalid Amanuensis API URL configured.'
      nil
    end

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
      return '' if summary.blank?

      ActionController::Base.helpers.sanitize(
        summary,
        tags: SUMMARY_ALLOWED_TAGS,
        attributes: SUMMARY_ALLOWED_ATTRIBUTES
      )
    end
  end
end
