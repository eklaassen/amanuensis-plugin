# frozen_string_literal: true

module Amanuensis
  # JSON replacement for the old server-rendered MeetingsController --
  # backs the Ember routes at /amanuensis/meetings and
  # /amanuensis/meetings/:id (assets/javascripts/discourse/routes/
  # amanuensis-meetings.js and amanuensis-meeting.js).
  class MeetingsApiController < Amanuensis::ApiController
    # speaker_access is gated on its own, narrower permission -- excluded here
    # so a relabel_speakers-group member who isn't ALSO a viewer (e.g. not in
    # amanuensis_viewing_group) doesn't get a confusing 403 from this check
    # before ever reaching ensure_relabel_speakers below.
    before_action :ensure_viewer, except: [:speaker_access]
    before_action :ensure_relabel_speakers, only: [:speaker_access]

    include Amanuensis::Formatting

    PAGE_SIZE = 25

    def index
      params_hash = { limit: PAGE_SIZE }
      params_hash[:before] = params[:before] if params[:before].present?
      params_hash[:status] = params[:status] if params[:status].present?
      params_hash[:canon_status] = params[:canon_status] if params[:canon_status].present?

      result = Amanuensis::ApiClient.reader.get('/v1/plugin/meetings', params_hash)

      if result.ok?
        render json: {
          meetings: result.body['meetings'].map { |m| serialize_meeting_summary(m) },
          pagination: result.body['pagination']
        }
      else
        render json: {
          meetings: [],
          pagination: { 'has_more' => false },
          error: result.error || "Failed to fetch meetings (status #{result.status || 'unknown'})"
        }, status: 502
      end
    end

    MEETING_ID_FORMAT = /\A[\w-]+\z/

    def show
      raise Discourse::NotFound unless params[:id].to_s.match?(MEETING_ID_FORMAT)

      result = Amanuensis::ApiClient.reader.get("/v1/plugin/meetings/#{params[:id]}")

      if result.ok?
        render json: serialize_meeting_detail(result.body)
      else
        render json: { error: result.error || "Meeting not found (status #{result.status || 'unknown'})" },
               status: 502
      end
    end

    # POST /amanuensis/api/meetings/:id/speaker-access -- mints a short-lived
    # capability token scoped to this one meeting and hands back the URL to
    # Amanuensis's relabel-speakers page. ensure_relabel_speakers (above) is
    # the actual gate: by the time this runs, the requesting user has already
    # been checked against SiteSetting.amanuensis_relabel_speakers_group.
    # Amanuensis itself never learns which Discourse user asked -- only that
    # an authorized plugin call happened for this meeting id, via the admin
    # (not reader) credential, matching the ingestion/upload endpoints'
    # privilege tier for the same reason: this mints a write-granting
    # credential, not just a read.
    def speaker_access
      raise Discourse::NotFound unless params[:id].to_s.match?(MEETING_ID_FORMAT)

      result = Amanuensis::ApiClient.admin.post("/v1/plugin/meetings/#{params[:id]}/speaker-access-token")
      url = result.ok? && result.body.is_a?(Hash) ? result.body['url'] : nil

      if url.present? && valid_relabel_url?(url)
        render json: { url: url }
      else
        render json: {
          error: result.error || "Could not create a relabel link (status #{result.status || 'unknown'})"
        }, status: 502
      end
    end

    private

    # Amanuensis's own speaker-access-token endpoint already only ever mints
    # an http(s) url pointed at itself -- this is defense in depth against a
    # malformed/unexpected response shape, not a defense against Amanuensis
    # itself (a trusted first-party service), so it can never navigate the
    # tab openRelabelSpeakers() opens to something unexpected.
    def valid_relabel_url?(url)
      URI.parse(url).is_a?(URI::HTTP) # covers both URI::HTTP and its URI::HTTPS subclass
    rescue URI::InvalidURIError
      false
    end

    def serialize_meeting_summary(meeting)
      {
        id: meeting['id'],
        title: meeting['title'],
        status: meeting['status'],
        source: meeting['source'],
        source_label: meeting['source'].to_s.humanize,
        recorded_at: meeting['recorded_at'],
        duration: meeting['duration_seconds'] ? format_duration(meeting['duration_seconds']) : nil,
        has_notesbot_transcript: meeting['has_notesbot_transcript'],
        has_summary: meeting['has_summary'],
        canon_status: meeting['canon_status']
      }
    end

    def serialize_meeting_detail(data)
      meeting = data['meeting']
      proposal = data['proposal']

      {
        meeting: serialize_meeting_full(meeting),
        notesbot_groups: notesbot_groups_for(meeting),
        notesbot_turn_count: meeting['notesbot_turns']&.length || 0,
        # The full proposal/history breakdown lives on the outcome-detail
        # page now (OutcomesApiController#show) -- this page only needs to
        # know whether to show the "See outcome details" link.
        has_outcome: proposal.present? && proposal['items'].present?,
        stage_runs: (data['stage_runs'] || []).map { |r| timeline_run(r) }
      }
    end

    def serialize_meeting_full(meeting)
      {
        id: meeting['id'],
        title: meeting['title'],
        status: meeting['status'],
        source: meeting['source'],
        source_label: meeting['source'].to_s.humanize,
        recorded_at: meeting['recorded_at'],
        duration: meeting['duration_seconds'] ? format_duration(meeting['duration_seconds']) : nil,
        discourse_topic_id: meeting['discourse_topic_id'],
        summary_html: meeting['summary'].present? ? sanitized_summary(meeting['summary']) : nil
      }
    end

    # Grouped by speaker, always -- the old ERB view had a fallback path for
    # an ungrouped flat list, but the controller only ever set @grouped_turns
    # (never left it nil) whenever this section rendered at all, so that
    # fallback was dead code. Not reproduced here.
    def notesbot_groups_for(meeting)
      turns = meeting['notesbot_turns']
      return nil unless meeting['source'] == 'notesbot' && turns.present?

      turns.group_by { |t| t['speaker'] }.map do |speaker, speaker_turns|
        {
          speaker: speaker,
          # A bare hex color, not a CSS declaration string -- the template
          # sets it as a plain --amanuensis-speaker-color custom property
          # (an ordinary attribute value, not raw HTML), so no html-safe/
          # trustHTML ceremony is needed to bind it.
          speaker_color: speaker_color(speaker),
          turn_count: speaker_turns.length,
          turns: speaker_turns.map { |t| { timestamp: t['timestamp'], text: t['text'] } }
        }
      end
    end

    SPEAKER_COLORS = %w[
      #4A90D9 #E8734A #50B86C #D94A8E #B86CE8
      #4AD9C8 #E8B04A #6CB850 #D94A4A #4A6CD9
    ].freeze

    def speaker_color(speaker)
      return '' if speaker.blank?

      hash = speaker.each_char.map(&:ord).sum
      SPEAKER_COLORS[hash % SPEAKER_COLORS.length]
    end

    def sanitized_summary(summary)
      Amanuensis::Sanitizer.sanitize_summary(summary)
    end
  end
end
