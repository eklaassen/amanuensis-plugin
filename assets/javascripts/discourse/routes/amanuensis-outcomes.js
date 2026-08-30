import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";
import modelErrorFrom from "../lib/amanuensis-model-error";

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
    const status = params.status || "complete";

    // status is carried through on failure too -- setupController below
    // always reads model.status to drive the status-filter chips' active
    // highlighting, even in the error state.
    return ajax("/amanuensis/api/outcomes", {
      data: {
        status,
        before: params.before || undefined,
      },
    }).catch((error) => ({
      ...modelErrorFrom(error, "Failed to fetch outcomes."),
      status,
    }));
  }

  // DiscourseRoute (discourse/routes/discourse) collects this into the
  // document title via _collectTitleTokens -- {{page-title}} isn't a real
  // helper in this codebase, this is the actual mechanism.
  titleToken() {
    return "Outcomes";
  }

  // Query-param changes (the status chips, "Older"/"Newest" pagination
  // links) re-run model() rather than push a new history entry on top of
  // the same page.
  setupController(controller, model) {
    super.setupController(controller, model);
    controller.set("status", model.status);
  }
}
