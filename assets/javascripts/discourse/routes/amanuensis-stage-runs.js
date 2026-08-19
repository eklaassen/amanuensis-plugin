import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";
import { ajax } from "discourse/lib/ajax";

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
    });
  }

  setupController(controller, model) {
    super.setupController(controller, model);
    controller.set("stage", model.stage);
  }

  titleToken() {
    return this.controller?.model?.stage_label;
  }
}
