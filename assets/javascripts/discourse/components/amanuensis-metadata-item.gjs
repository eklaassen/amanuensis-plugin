import AmanuensisLocalTime from "./amanuensis-local-time";

// Pass either @value (plain text) or @timestamp (raw ISO-8601 UTC string,
// rendered in the user's timezone via AmanuensisLocalTime) -- not both.
export default <template>
  <div class="amanuensis-metadata-item">
    <span class="amanuensis-label">{{@label}}</span>
    <span class="amanuensis-value">
      {{#if @timestamp}}
        <AmanuensisLocalTime @timestamp={{@timestamp}} />
      {{else}}
        {{@value}}
      {{/if}}
    </span>
  </div>
</template>
