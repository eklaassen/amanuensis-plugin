import { LinkTo } from "@ember/routing";
import AmanuensisEmpty from "../components/amanuensis-empty";
import AmanuensisError from "../components/amanuensis-error";
import AmanuensisHistoryCard from "../components/amanuensis-history-card";
import AmanuensisMetadataItem from "../components/amanuensis-metadata-item";
import AmanuensisProposalItemCard from "../components/amanuensis-proposal-item-card";

export default <template>
  <div class="amanuensis-container">
    <LinkTo @route="amanuensis-outcomes" class="amanuensis-back-link">&larr; Back to outcomes</LinkTo>

    {{#if @controller.model.error}}
      <AmanuensisError @message={{@controller.model.error}} />
    {{else if @controller.model.meeting}}
      <header class="amanuensis-header">
        <h1>{{@controller.model.meeting.title}}</h1>
      </header>

      <section class="amanuensis-section amanuensis-metadata">
        <div class="amanuensis-metadata-grid">
          <AmanuensisMetadataItem @label="Recorded" @value={{@controller.model.meeting.recorded_at}} />
        </div>
        <LinkTo
          @route="amanuensis-meeting"
          @model={{@controller.model.meeting.id}}
          class="amanuensis-outcome-meeting-link"
        >See meeting summary &rarr;</LinkTo>
      </section>

      {{#if @controller.model.proposal}}
        <section class="amanuensis-section amanuensis-proposal">
          <h2>Proposal Items</h2>
          <p class="amanuensis-proposal-state">State: <strong>{{@controller.model.proposal.state}}</strong></p>

          {{#each @controller.model.proposal.groups as |group|}}
            <div class="amanuensis-item-group">
              <h3 class="amanuensis-item-group-header amanuensis-item-group-{{group.decision}}">
                {{group.decision_label}}
                <span class="amanuensis-item-count">{{group.count}}</span>
              </h3>
              <div class="amanuensis-item-cards">
                {{#each group.items as |item|}}
                  <AmanuensisProposalItemCard @item={{item}} />
                {{/each}}
              </div>
            </div>
          {{/each}}
        </section>
      {{else}}
        <AmanuensisEmpty @message="No proposal decisions for this meeting." />
      {{/if}}

      {{#if @controller.model.history.length}}
        <section class="amanuensis-section amanuensis-history">
          <h2>Applied Changes</h2>
          <div class="amanuensis-history-cards">
            {{#each @controller.model.history as |entry|}}
              <AmanuensisHistoryCard @entry={{entry}} />
            {{/each}}
          </div>
        </section>
      {{/if}}
    {{/if}}
  </div>
</template>
