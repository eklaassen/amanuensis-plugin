import { LinkTo } from "@ember/routing";
import AmanuensisBadge from "../components/amanuensis-badge";
import AmanuensisError from "../components/amanuensis-error";
import AmanuensisMetadataItem from "../components/amanuensis-metadata-item";
import AmanuensisStageTimeline from "../components/amanuensis-stage-timeline";

export default <template>
  <div class="amanuensis-container">
    <LinkTo @route="amanuensis-stage-runs" @model={{@controller.model.stage}} class="amanuensis-back-link">&larr; Back to {{@controller.model.stage_label}} runs</LinkTo>

    {{#if @controller.model.error}}
      <AmanuensisError @message={{@controller.model.error}} />
    {{else if @controller.model.run}}
      <header class="amanuensis-header">
        <h1>{{@controller.model.run.meeting_title}}</h1>
        <div class="amanuensis-header-badges">
          <AmanuensisBadge @label={{@controller.model.run.stage_label}} @variant="source" />
          <AmanuensisBadge @label={{@controller.model.run.outcome}} @variant={{@controller.model.run.outcome}} />
          {{#if @controller.model.run.inferred}}
            <span class="amanuensis-inferred-tag">reconstructed</span>
          {{/if}}
        </div>
      </header>

      <section class="amanuensis-section amanuensis-metadata">
        <div class="amanuensis-metadata-grid">
          <AmanuensisMetadataItem @label="Stage" @value={{@controller.model.run.stage_label}} />
          <AmanuensisMetadataItem @label="Outcome" @value={{@controller.model.run.outcome}} />
          <AmanuensisMetadataItem @label="Attempt" @value={{@controller.model.run.attempt}} />
          <AmanuensisMetadataItem @label="Started" @timestamp={{@controller.model.run.started_at}} />
          {{#if @controller.model.run.finished_at}}
            <AmanuensisMetadataItem @label="Finished" @timestamp={{@controller.model.run.finished_at}} />
          {{/if}}
          {{#if @controller.model.run.duration}}
            <AmanuensisMetadataItem @label="Duration" @value={{@controller.model.run.duration}} />
          {{/if}}
          {{#if @controller.model.run.job_id}}
            <AmanuensisMetadataItem @label="Job ID" @value={{@controller.model.run.job_id}} />
          {{/if}}
          {{#if @controller.model.run.rewind_to}}
            <AmanuensisMetadataItem @label="Rewound to" @value={{@controller.model.run.rewind_to_label}} />
          {{/if}}
        </div>
      </section>

      {{#if @controller.model.run.failure_reason}}
        <section class="amanuensis-section">
          <h2>Error</h2>
          <AmanuensisError @message="{{@controller.model.run.error_code}}: {{@controller.model.run.failure_reason}}" />
        </section>
      {{/if}}

      {{#if @controller.model.run.meeting_id}}
        <section class="amanuensis-section">
          <h2>Meeting</h2>
          <LinkTo @route="amanuensis-meeting" @model={{@controller.model.run.meeting_id}} class="amanuensis-pagination-link">View meeting &rarr;</LinkTo>
        </section>
      {{/if}}

      {{#if @controller.model.other_runs.length}}
        <section class="amanuensis-section">
          <h2>Pipeline Timeline</h2>
          <AmanuensisStageTimeline @runs={{@controller.model.other_runs}} />
        </section>
      {{/if}}
    {{/if}}
  </div>
</template>
