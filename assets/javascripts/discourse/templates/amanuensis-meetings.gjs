import { LinkTo } from "@ember/routing";
import { hash } from "@ember/helper";
import { eq } from "discourse/truth-helpers";
import AmanuensisEmpty from "../components/amanuensis-empty";
import AmanuensisError from "../components/amanuensis-error";
import AmanuensisIcon from "../components/amanuensis-icon";
import AmanuensisMeetingBadges from "../components/amanuensis-meeting-badges";

export default <template>
  <div class="amanuensis-container">
    <header class="amanuensis-header">
      <h1>
        <AmanuensisIcon @name="clipboard" @size={{24}} @class="amanuensis-icon" />
        Writers' Room Meetings
      </h1>
    </header>

    <div class="amanuensis-chips">
      <LinkTo
        @route="amanuensis-meetings"
        @query={{hash status=null canon_status=@controller.canon_status before=null}}
        class="amanuensis-chip {{unless @controller.status 'amanuensis-chip-active'}}"
      >All</LinkTo>
      {{#each @controller.statusFilters as |filter|}}
        <LinkTo
          @route="amanuensis-meetings"
          @query={{hash status=filter.value canon_status=@controller.canon_status before=null}}
          class="amanuensis-chip {{if (eq filter.value @controller.status) 'amanuensis-chip-active'}}"
        >{{filter.label}}</LinkTo>
      {{/each}}
    </div>

    <div class="amanuensis-chips">
      <LinkTo
        @route="amanuensis-meetings"
        @query={{hash status=@controller.status canon_status=null before=null}}
        class="amanuensis-chip {{unless @controller.canon_status 'amanuensis-chip-active'}}"
      >All canon states</LinkTo>
      {{#each @controller.canonStatusFilters as |filter|}}
        <LinkTo
          @route="amanuensis-meetings"
          @query={{hash status=@controller.status canon_status=filter.value before=null}}
          class="amanuensis-chip {{if (eq filter.value @controller.canon_status) 'amanuensis-chip-active'}}"
        >{{filter.label}}</LinkTo>
      {{/each}}
    </div>

    {{#if @controller.model.error}}
      <AmanuensisError @message={{@controller.model.error}} />
    {{else if @controller.model.meetings.length}}
      <div class="amanuensis-meetings-list">
        {{#each @controller.model.meetings as |meeting|}}
          <LinkTo @route="amanuensis-meeting" @model={{meeting.id}} class="amanuensis-meeting-card">
            <div class="amanuensis-card-header">
              <h3 class="amanuensis-meeting-title">{{meeting.title}}</h3>
              <AmanuensisMeetingBadges @meeting={{meeting}} />
            </div>
            <div class="amanuensis-card-meta">
              <span class="amanuensis-meta-item">
                <AmanuensisIcon @name="clock" @size={{14}} />
                {{meeting.recorded_at}}
              </span>
              <span class="amanuensis-meta-item">
                <AmanuensisIcon @name="mic" @size={{14}} />
                {{meeting.source_label}}
              </span>
              {{#if meeting.duration}}
                <span class="amanuensis-meta-item">
                  <AmanuensisIcon @name="clock" @size={{14}} />
                  {{meeting.duration}}
                </span>
              {{/if}}
              {{#if meeting.has_notesbot_transcript}}
                <span class="amanuensis-meta-item amanuensis-meta-notesbot">📜 Vintage notes available</span>
              {{/if}}
              {{#if meeting.has_summary}}
                <span class="amanuensis-meta-item">📋 Summary</span>
              {{/if}}
            </div>
          </LinkTo>
        {{/each}}
      </div>

      <div class="amanuensis-pagination">
        {{#if @controller.model.pagination.has_more}}
          <LinkTo
            @route="amanuensis-meetings"
            @query={{hash status=@controller.status canon_status=@controller.canon_status before=@controller.model.pagination.next_before}}
            class="amanuensis-pagination-link"
          >&larr; Older</LinkTo>
        {{/if}}
        <LinkTo
          @route="amanuensis-meetings"
          @query={{hash status=@controller.status canon_status=@controller.canon_status before=null}}
          class="amanuensis-pagination-link"
        >Newest &rarr;</LinkTo>
      </div>
    {{else}}
      <AmanuensisEmpty @message="No meetings found." />
    {{/if}}
  </div>
</template>
