// @item: {operation, target_type, target_field, proposed_value, edited_value, show_edited}
export default <template>
  <div class="amanuensis-item-card">
    <div class="amanuensis-item-card-header">
      <span class="amanuensis-item-op">{{@item.operation}}</span>
      <span class="amanuensis-item-type">{{@item.target_type}}</span>
    </div>
    {{#if @item.target_field}}
      <div class="amanuensis-item-field">Field: {{@item.target_field}}</div>
    {{/if}}
    <div class="amanuensis-item-value">
      <span class="amanuensis-label">Value</span>
      <code>{{if @item.proposed_value @item.proposed_value "—"}}</code>
    </div>
    {{#if @item.show_edited}}
      <div class="amanuensis-item-value amanuensis-item-value-edited">
        <span class="amanuensis-label">Edited</span>
        <code>{{if @item.edited_value @item.edited_value "—"}}</code>
      </div>
    {{/if}}
  </div>
</template>
