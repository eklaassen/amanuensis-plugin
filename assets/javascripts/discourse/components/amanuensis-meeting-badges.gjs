import { eq } from "discourse/truth-helpers";
import AmanuensisBadge from "./amanuensis-badge";

// @meeting: needs status, source, source_label
export default <template>
  <AmanuensisBadge @label={{@meeting.status}} @variant={{@meeting.status}} />
  {{#if (eq @meeting.source "notesbot")}}
    <AmanuensisBadge @label="NotesBot" @variant="notesbot" />
  {{else}}
    <AmanuensisBadge @label={{@meeting.source_label}} @variant="source" />
  {{/if}}
</template>
