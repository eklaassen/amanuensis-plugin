import { LinkTo } from "@ember/routing";
import AmanuensisBadge from "../components/amanuensis-badge";
import AmanuensisEmpty from "../components/amanuensis-empty";
import AmanuensisError from "../components/amanuensis-error";
import AmanuensisIcon from "../components/amanuensis-icon";
import AmanuensisLocalTime from "../components/amanuensis-local-time";

export default <template>
  <div class="amanuensis-container">
    <header class="amanuensis-header">
      <h1>Active Pipeline</h1>
    </header>

    {{#if @controller.model.error}}
      <AmanuensisError @message={{@controller.model.error}} />
    {{else if @controller.model.stage_groups.length}}
      {{#each @controller.model.stage_groups as |group|}}
        <section class="amanuensis-section">
          <h2>
            {{group.stage_label}}
            <span class="amanuensis-item-count">{{group.meetings.length}}</span>
          </h2>
          <div class="amanuensis-meetings-list">
            {{#each group.meetings as |meeting|}}
              <LinkTo @route="amanuensis-meeting" @model={{meeting.id}} class="amanuensis-meeting-card">
                <div class="amanuensis-card-header">
                  <h3 class="amanuensis-meeting-title">{{meeting.title}}</h3>
                  <AmanuensisBadge @label={{meeting.source_label}} @variant="source" />
                </div>
                <div class="amanuensis-card-meta">
                  <span class="amanuensis-meta-item">
                    <AmanuensisIcon @name="clock" @size={{14}} />
                    Updated <AmanuensisLocalTime @timestamp={{meeting.updated_at}} @relative={{true}} />
                  </span>
                  {{#if meeting.attempt_note}}
                    <span class="amanuensis-meta-item">{{meeting.attempt_note}}</span>
                  {{/if}}
                </div>
              </LinkTo>
            {{/each}}
          </div>
        </section>
      {{/each}}
    {{else}}
      <AmanuensisEmpty @message="Nothing in flight right now." />
    {{/if}}
  </div>
</template>
