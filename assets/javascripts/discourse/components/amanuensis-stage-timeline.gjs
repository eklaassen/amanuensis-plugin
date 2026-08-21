import AmanuensisBadge from "./amanuensis-badge";
import AmanuensisLocalTime from "./amanuensis-local-time";

// @runs: array of {stage_label, outcome, started_at, duration, attempt_note, failure_reason, inferred}
export default <template>
  {{#if @runs.length}}
    <div class="amanuensis-timeline">
      {{#each @runs as |run|}}
        <div class="amanuensis-timeline-entry">
          <div class="amanuensis-timeline-marker"></div>
          <div class="amanuensis-timeline-content">
            <div class="amanuensis-timeline-header">
              <AmanuensisBadge @label={{run.stage_label}} @variant="source" />
              <AmanuensisBadge @label={{run.outcome}} @variant={{run.outcome}} />
              {{#if run.inferred}}
                <span class="amanuensis-inferred-tag">reconstructed</span>
              {{/if}}
            </div>
            <div class="amanuensis-timeline-meta">
              <AmanuensisLocalTime @timestamp={{run.started_at}} />
              {{#if run.duration}}
                &middot;
                {{run.duration}}
              {{/if}}
              {{#if run.attempt_note}}
                &middot;
                {{run.attempt_note}}
              {{/if}}
            </div>
            {{#if run.failure_reason}}
              <div class="amanuensis-timeline-error">{{run.failure_reason}}</div>
            {{/if}}
          </div>
        </div>
      {{/each}}
    </div>
  {{else}}
    <p class="amanuensis-value">No pipeline history recorded for this meeting.</p>
  {{/if}}
</template>
