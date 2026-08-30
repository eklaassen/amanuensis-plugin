import { on } from "@ember/modifier";
import { LinkTo } from "@ember/routing";
import { trustHTML } from "@ember/template";
import { or } from "discourse/truth-helpers";
import AmanuensisError from "../components/amanuensis-error";
import AmanuensisMeetingBadges from "../components/amanuensis-meeting-badges";
import AmanuensisMetadataItem from "../components/amanuensis-metadata-item";
import AmanuensisStageTimeline from "../components/amanuensis-stage-timeline";

function speakerColorStyle(color) {
  return trustHTML(`--amanuensis-speaker-color: ${color}`);
}

export default <template>
  <div class="amanuensis-container">
    <LinkTo @route="amanuensis-meetings" class="amanuensis-back-link">&larr;
      Back to meetings</LinkTo>

    {{#if @controller.model.error}}
      <AmanuensisError @message={{@controller.model.error}} />
    {{else if @controller.model.meeting}}
      <header class="amanuensis-header">
        <h1>{{@controller.model.meeting.title}}</h1>
        <div class="amanuensis-header-badges">
          <AmanuensisMeetingBadges @meeting={{@controller.model.meeting}} />
        </div>
      </header>

      <section class="amanuensis-section amanuensis-metadata">
        <div class="amanuensis-metadata-grid">
          <AmanuensisMetadataItem
            @label="Recorded"
            @timestamp={{@controller.model.meeting.recorded_at}}
          />
          {{#if @controller.model.meeting.duration}}
            <AmanuensisMetadataItem
              @label="Duration"
              @value={{@controller.model.meeting.duration}}
            />
          {{/if}}
          <AmanuensisMetadataItem
            @label="Source"
            @value={{@controller.model.meeting.source_label}}
          />
          {{#if @controller.model.meeting.discourse_topic_id}}
            <div class="amanuensis-metadata-item">
              <span class="amanuensis-label">Discourse Topic</span>
              <span class="amanuensis-value">
                <a
                  href="/t/{{@controller.model.meeting.discourse_topic_id}}"
                >Topic #{{@controller.model.meeting.discourse_topic_id}}</a>
              </span>
            </div>
          {{/if}}
        </div>
      </section>

      {{#if @controller.model.meeting.summary_html}}
        <section class="amanuensis-section amanuensis-summary">
          <h2>Meeting Summary</h2>
          {{! summary_html is a SafeString (trustHTML, applied in the route) --
              already sanitized server-side, so a plain mustache here renders
              the markup instead of escaping it. }}
          <div
            class="amanuensis-summary-content"
          >{{@controller.model.meeting.summary_html}}</div>
        </section>
      {{/if}}

      {{#if @controller.model.notesbot_groups}}
        <section class="amanuensis-section amanuensis-notesbot">
          <details class="amanuensis-foldable">
            <summary class="amanuensis-foldable-header">
              <span class="amanuensis-foldable-icon">📜</span>
              <span class="amanuensis-foldable-title">Vintage NotesBot
                Transcript</span>
              <span
                class="amanuensis-foldable-count"
              >{{@controller.model.notesbot_turn_count}} turns</span>
              <span class="amanuensis-foldable-toggle">expand</span>
            </summary>
            <div class="amanuensis-notesbot-transcript">
              {{#each @controller.model.notesbot_groups as |group|}}
                <div class="amanuensis-speaker-group">
                  <div
                    class="amanuensis-speaker-header"
                    style={{speakerColorStyle group.speaker_color}}
                  >
                    {{group.speaker}}
                    <span class="amanuensis-speaker-count">{{group.turn_count}}
                      lines</span>
                  </div>
                  {{#each group.turns as |turn|}}
                    <div class="amanuensis-turn">
                      <span
                        class="amanuensis-turn-time"
                      >{{turn.timestamp}}</span>
                      <span
                        class="amanuensis-turn-speaker"
                        style={{speakerColorStyle group.speaker_color}}
                      >{{group.speaker}}</span>
                      <span class="amanuensis-turn-text">{{turn.text}}</span>
                    </div>
                  {{/each}}
                </div>
              {{/each}}
            </div>
          </details>
        </section>
      {{/if}}

      {{#if @controller.model.stage_runs.length}}
        <section class="amanuensis-section amanuensis-pipeline-timeline">
          <h2>Pipeline Timeline</h2>
          <AmanuensisStageTimeline @runs={{@controller.model.stage_runs}} />
        </section>
      {{/if}}

      {{#if
        (or
          @controller.model.has_outcome
          @controller.currentUser.can_relabel_speakers_amanuensis
        )
      }}
        <footer class="amanuensis-meeting-footer">
          {{#if @controller.model.has_outcome}}
            <LinkTo
              @route="amanuensis-outcome"
              @model={{@controller.model.meeting.id}}
              class="amanuensis-outcome-link"
            >See outcome details &rarr;</LinkTo>
          {{/if}}

          {{! Visibility here is a UX nicety only -- the real gate is server-side
              (ensure_relabel_speakers on MeetingsApiController#speaker_access). }}
          {{#if @controller.currentUser.can_relabel_speakers_amanuensis}}
            <button
              type="button"
              class="btn amanuensis-relabel-speakers-link"
              disabled={{@controller.relabelBusy}}
              {{on "click" @controller.openRelabelSpeakers}}
            >{{if
                @controller.relabelBusy
                "Opening…"
                "Relabel speakers"
              }}</button>
            {{#if @controller.relabelError}}
              <span
                class="amanuensis-relabel-speakers-error"
              >{{@controller.relabelError}}</span>
            {{/if}}
          {{/if}}
        </footer>
      {{/if}}
    {{/if}}
  </div>
</template>
