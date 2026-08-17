import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";
import { ajax } from "discourse/lib/ajax";

export default class AmanuensisOutcomesRoute extends DiscourseRoute {
  @service currentUser;
  @service router;

  queryParams = {
    status: { refreshModel: true },
    before: { refreshModel: true },
  };

  beforeModel() {
    // Mirrors the old Amanuensis::AccessControl#ensure_writer gate. The API
    // call is gated the same way server-side (403), but checking here too
    // means a writer-only sidebar link never even attempts a doomed request.
    if (!this.currentUser?.can_write_amanuensis) {
      this.router.transitionTo("discovery.latest");
    }
  }

  model(params) {
    return ajax("/amanuensis/api/outcomes", {
      data: {
        status: params.status || "complete",
        before: params.before || undefined,
      },
    });
  }

  // Query-param changes (the status chips, "Older"/"Newest" pagination
  // links) re-run model() rather than push a new history entry on top of
  // the same page.
  setupController(controller, model) {
    super.setupController(controller, model);
    controller.set("status", model.status);
  }
}
