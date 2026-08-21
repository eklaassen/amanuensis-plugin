import { LinkTo } from "@ember/routing";
import { hash } from "@ember/helper";
import { eq } from "discourse/truth-helpers";
import AmanuensisBadge from "../components/amanuensis-badge";
import AmanuensisEmpty from "../components/amanuensis-empty";
import AmanuensisError from "../components/amanuensis-error";
import AmanuensisLocalTime from "../components/amanuensis-local-time";

export default <template>
  <div class="amanuensis-container">
    <header class="amanuensis-header">
      <h1>Outcomes</h1>
    </header>

    <div class="amanuensis-chips">
      <LinkTo
        @route="amanuensis-outcomes"
        @query={{hash status="complete" before=null}}
        class="amanuensis-chip {{if (eq @controller.status "complete") "amanuensis-chip-active"}}"
      >Complete</LinkTo>
      <LinkTo
        @route="amanuensis-outcomes"
        @query={{hash status="failed" before=null}}
        class="amanuensis-chip {{if (eq @controller.status "failed") "amanuensis-chip-active"}}"
      >Failed</LinkTo>
    </div>

    {{#if @controller.model.error}}
      <AmanuensisError @message={{@controller.model.error}} />
    {{else if @controller.model.meetings.length}}
      <div class="amanuensis-table-wrapper">
        <table class="amanuensis-data-table">
          <thead>
            <tr>
              <th>Meeting</th>
              <th>Recorded</th>
              <th>Outcome</th>
              <th>Error</th>
            </tr>
          </thead>
          <tbody>
            {{#each @controller.model.meetings as |meeting|}}
              <tr>
                <td><LinkTo @route="amanuensis-outcome" @model={{meeting.id}}>{{meeting.title}}</LinkTo></td>
                <td><AmanuensisLocalTime @timestamp={{meeting.recorded_at}} /></td>
                <td><AmanuensisBadge @label={{meeting.status}} @variant={{meeting.status}} /></td>
                <td>{{if meeting.failure_reason meeting.failure_reason "—"}}</td>
              </tr>
            {{/each}}
          </tbody>
        </table>
      </div>

      <div class="amanuensis-pagination">
        {{#if @controller.model.pagination.has_more}}
          <LinkTo
            @route="amanuensis-outcomes"
            @query={{hash status=@controller.status before=@controller.model.pagination.next_before}}
            class="amanuensis-pagination-link"
          >&larr; Older</LinkTo>
        {{/if}}
        <LinkTo
          @route="amanuensis-outcomes"
          @query={{hash status=@controller.status before=null}}
          class="amanuensis-pagination-link"
        >Newest &rarr;</LinkTo>
      </div>
    {{else}}
      <AmanuensisEmpty @message="No meetings here yet." />
    {{/if}}
  </div>
</template>
