import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";
import { ajax } from "discourse/lib/ajax";
import modelErrorFrom from "../lib/amanuensis-model-error";

export default class AmanuensisOutcomeRoute extends DiscourseRoute {
  @service currentUser;
  @service router;

  beforeModel() {
    // Mirrors the outcomes list's own gate (Amanuensis::AccessControl#
    // ensure_writer) -- a writer-only sidebar link never even attempts a
    // doomed request.
    if (!this.currentUser?.can_write_amanuensis) {
      this.router.transitionTo("discovery.latest");
    }
  }

  model(params) {
    return ajax(`/amanuensis/api/outcomes/${params.meeting_id}`).catch((error) =>
      modelErrorFrom(error, "Outcome not found.")
    );
  }

  titleToken() {
    const title = this.controller?.model?.meeting?.title;
    return title ? `${title} Outcome` : "Outcome";
  }
}
