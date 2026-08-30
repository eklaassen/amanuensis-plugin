import { array, hash } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import { eq } from "discourse/truth-helpers";
import AmanuensisBadge from "../components/amanuensis-badge";
import AmanuensisEmpty from "../components/amanuensis-empty";
import AmanuensisError from "../components/amanuensis-error";
import AmanuensisLocalTime from "../components/amanuensis-local-time";

export default <template>
  <div class="amanuensis-container">
    <header class="amanuensis-header">
      <h1>{{@controller.model.stage_label}} Runs</h1>
    </header>

    <div class="amanuensis-chips">
      {{#each @controller.model.observable_stages as |stageOption|}}
        <LinkTo
          @route="amanuensis-stage-runs"
          @model={{stageOption.value}}
          class="amanuensis-chip
            {{if
              (eq stageOption.value @controller.model.stage)
              'amanuensis-chip-active'
            }}"
        >{{stageOption.label}}</LinkTo>
      {{/each}}
    </div>

    <div class="amanuensis-chips">
      <LinkTo
        @route="amanuensis-stage-runs"
        @model={{@controller.model.stage}}
        @query={{hash outcome=null before=null}}
        class="amanuensis-chip
          {{unless @controller.outcome 'amanuensis-chip-active'}}"
      >All</LinkTo>
      {{#each @controller.outcomeFilters as |filter|}}
        <LinkTo
          @route="amanuensis-stage-runs"
          @model={{@controller.model.stage}}
          @query={{hash outcome=filter.value before=null}}
          class="amanuensis-chip
            {{if
              (eq filter.value @controller.outcome)
              'amanuensis-chip-active'
            }}"
        >{{filter.label}}</LinkTo>
      {{/each}}
    </div>

    {{#if @controller.model.error}}
      <AmanuensisError @message={{@controller.model.error}} />
    {{else if @controller.model.runs.length}}
      <div class="amanuensis-table-wrapper">
        <table class="amanuensis-data-table">
          <thead>
            <tr>
              <th>Meeting</th>
              <th>Started</th>
              <th>Duration</th>
              <th>Attempt</th>
              <th>Outcome</th>
              <th>Error</th>
            </tr>
          </thead>
          <tbody>
            {{#each @controller.model.runs as |run|}}
              <tr>
                <td>
                  <LinkTo
                    @route="amanuensis-stage-run"
                    @models={{array @controller.model.stage run.id}}
                  >{{run.meeting_title}}</LinkTo>
                  {{#if run.inferred}}
                    <span class="amanuensis-inferred-tag">reconstructed</span>
                  {{/if}}
                </td>
                <td><AmanuensisLocalTime @timestamp={{run.started_at}} /></td>
                <td>{{if run.duration run.duration "—"}}</td>
                <td>{{run.attempt}}</td>
                <td><AmanuensisBadge
                    @label={{run.outcome}}
                    @variant={{run.outcome}}
                  /></td>
                <td>{{if run.failure_reason run.failure_reason "—"}}</td>
              </tr>
            {{/each}}
          </tbody>
        </table>
      </div>

      <div class="amanuensis-pagination">
        {{#if @controller.model.pagination.has_more}}
          <LinkTo
            @route="amanuensis-stage-runs"
            @model={{@controller.model.stage}}
            @query={{hash
              outcome=@controller.outcome
              before=@controller.model.pagination.next_before
            }}
            class="amanuensis-pagination-link"
          >&larr; Older</LinkTo>
        {{/if}}
        <LinkTo
          @route="amanuensis-stage-runs"
          @model={{@controller.model.stage}}
          @query={{hash outcome=@controller.outcome before=null}}
          class="amanuensis-pagination-link"
        >Newest &rarr;</LinkTo>
      </div>
    {{else}}
      <AmanuensisEmpty @message="No runs recorded for this stage yet." />
    {{/if}}
  </div>
</template>
