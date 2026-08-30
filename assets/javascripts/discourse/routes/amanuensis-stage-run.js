import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";
import modelErrorFrom from "../lib/amanuensis-model-error";

export default class AmanuensisStageRunRoute extends DiscourseRoute {
  @service currentUser;
  @service router;

  beforeModel() {
    if (!this.currentUser?.can_write_amanuensis) {
      this.router.transitionTo("discovery.latest");
    }
  }

  model(params) {
    // stage is carried through on failure too -- the template's "back to
    // runs" link binds its @model to it even in the error state, and an
    // undefined dynamic segment there breaks route link generation rather
    // than just looking empty.
    return ajax(
      `/amanuensis/api/stages/${params.stage}/runs/${params.run_id}`
    ).catch((error) => ({
      ...modelErrorFrom(error, "Stage run not found."),
      stage: params.stage,
    }));
  }

  titleToken() {
    const label = this.controller?.model?.stage_label;
    return label ? `${label} Run` : undefined;
  }
}
