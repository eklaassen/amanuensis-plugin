import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";
import modelErrorFrom from "../lib/amanuensis-model-error";

export default class AmanuensisMeetingRoute extends DiscourseRoute {
  @service currentUser;
  @service router;

  beforeModel() {
    if (!this.currentUser?.can_view_amanuensis) {
      this.router.transitionTo("discovery.latest");
    }
  }

  model(params) {
    return ajax(`/amanuensis/api/meetings/${params.meeting_id}`)
      .then((data) => {
        // summary_html is pre-sanitized server-side (Amanuensis::Sanitizer,
        // an allowlist) before it ever reaches here -- this is the only field
        // on the whole page marked trusted, and only because it already went
        // through that allowlist. Every other field stays a plain string and
        // gets Ember's normal auto-escaping.
        if (data.meeting?.summary_html) {
          data.meeting.summary_html = trustHTML(data.meeting.summary_html);
        }
        return data;
      })
      .catch((error) => modelErrorFrom(error, "Meeting not found."));
  }

  titleToken() {
    return this.controller?.model?.meeting?.title || "Meeting";
  }
}
