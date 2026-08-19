import { eq } from "discourse/truth-helpers";

// @name: "clock" | "mic" | "clipboard", @size: number, @class: optional css class
export default <template>
  {{#if (eq @name "clock")}}
    <svg class={{@class}} xmlns="http://www.w3.org/2000/svg" width={{@size}} height={{@size}} viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
      <circle cx="12" cy="12" r="10" />
      <polyline points="12 6 12 12 16 14" />
    </svg>
  {{else if (eq @name "mic")}}
    <svg class={{@class}} xmlns="http://www.w3.org/2000/svg" width={{@size}} height={{@size}} viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
      <path d="M12 1a3 3 0 0 0-3 3v8a3 3 0 0 0 6 0V4a3 3 0 0 0-3-3z" />
      <path d="M19 10v2a7 7 0 0 1-14 0v-2" />
      <line x1="12" y1="19" x2="12" y2="23" />
      <line x1="8" y1="23" x2="16" y2="23" />
    </svg>
  {{else if (eq @name "clipboard")}}
    <svg class={{@class}} xmlns="http://www.w3.org/2000/svg" width={{@size}} height={{@size}} viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
      <path d="M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2" />
      <rect x="8" y="2" width="8" height="4" rx="1" ry="1" />
      <path d="M9 14l2 2 4-4" />
    </svg>
  {{/if}}
</template>
