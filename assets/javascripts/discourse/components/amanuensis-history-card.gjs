import AmanuensisBadge from "./amanuensis-badge";
import AmanuensisLocalTime from "./amanuensis-local-time";

// @entry: {created_at, source, actor, summary}
export default <template>
  <div class="amanuensis-history-card">
    <div class="amanuensis-history-card-header">
      <span class="amanuensis-value"><AmanuensisLocalTime
          @timestamp={{@entry.created_at}}
        /></span>
      <AmanuensisBadge @label={{@entry.source}} @variant="source" />
    </div>
    <div class="amanuensis-history-actor">{{@entry.actor}}</div>
    <div class="amanuensis-history-summary">{{@entry.summary}}</div>
  </div>
</template>
