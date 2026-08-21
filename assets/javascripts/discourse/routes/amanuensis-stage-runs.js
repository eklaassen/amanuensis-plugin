import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";
import { ajax } from "discourse/lib/ajax";
import modelErrorFrom from "../lib/amanuensis-model-error";

export default class AmanuensisStageRunsRoute extends DiscourseRoute {
  @service currentUser;
  @service router;

  queryParams = {
    outcome: { refreshModel: true },
    before: { refreshModel: true },
  };

  beforeModel() {
    if (!this.currentUser?.can_write_amanuensis) {
      this.router.transitionTo("discovery.latest");
    }
  }

  model(params) {
    return ajax(`/amanuensis/api/stages/${params.stage}/runs`, {
      data: {
        outcome: params.outcome || undefined,
        before: params.before || undefined,
      },
    }).catch((error) => ({
      ...modelErrorFrom(error, "Failed to fetch stage runs."),
      // stage is carried through on failure too -- the template's
      // stage-switcher chips and "back to runs" links bind their @model to
      // it even in the error state, and an undefined dynamic segment there
      // breaks route link generation rather than just looking empty.
      stage: params.stage,
    }));
  }

  setupController(controller, model) {
    super.setupController(controller, model);
    controller.set("stage", model.stage);
  }

  titleToken() {
    return this.controller?.model?.stage_label;
  }
}
