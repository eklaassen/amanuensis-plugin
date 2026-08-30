import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";
import modelErrorFrom from "../lib/amanuensis-model-error";

export default class AmanuensisPipelineRoute extends DiscourseRoute {
  @service currentUser;
  @service router;

  beforeModel() {
    // Mirrors the old Amanuensis::AccessControl#ensure_writer gate. The API
    // call is gated the same way server-side (403), but checking here too
    // means a writer-only sidebar link never even attempts a doomed request.
    if (!this.currentUser?.can_write_amanuensis) {
      this.router.transitionTo("discovery.latest");
    }
  }

  model() {
    return ajax("/amanuensis/api/pipeline").catch((error) =>
      modelErrorFrom(error, "Failed to fetch active pipeline.")
    );
  }

  titleToken() {
    return "Active Pipeline";
  }
}
