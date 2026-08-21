import Component from "@glimmer/component";
import { service } from "@ember/service";
import moment from "moment";

const ABSOLUTE_FORMAT = "MMMM D, YYYY h:mm A";

// @timestamp: raw ISO-8601 UTC string from the db (or blank). Rendered in
// the viewing user's Discourse timezone preference; the raw UTC value is
// kept as the `title` so hovering always shows what's actually in the db.
// @relative: render "3 hours ago" instead of an absolute date/time.
export default class AmanuensisLocalTime extends Component {
  @service currentUser;

  get momentValue() {
    if (!this.args.timestamp) {
      return null;
    }

    const timezone =
      this.currentUser?.user_option?.timezone || moment.tz.guess() || "UTC";

    return moment.utc(this.args.timestamp).tz(timezone);
  }

  get displayValue() {
    const value = this.momentValue;
    if (!value) {
      return null;
    }

    return this.args.relative ? value.fromNow() : value.format(ABSOLUTE_FORMAT);
  }

  <template>
    {{#if this.displayValue}}
      <span class="amanuensis-local-time" title={{@timestamp}}>{{this.displayValue}}</span>
    {{else}}
      <span class="amanuensis-local-time amanuensis-local-time--empty">—</span>
    {{/if}}
  </template>
}
