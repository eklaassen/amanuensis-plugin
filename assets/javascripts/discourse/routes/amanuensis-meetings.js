import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";
import { ajax } from "discourse/lib/ajax";
import modelErrorFrom from "../lib/amanuensis-model-error";

export default class AmanuensisMeetingsRoute extends DiscourseRoute {
  @service currentUser;
  @service router;

  queryParams = {
    status: { refreshModel: true },
    canon_status: { refreshModel: true },
    before: { refreshModel: true },
  };

  beforeModel() {
    // Meetings is viewer-level (Amanuensis::Permissions.viewer?), not
    // writer-level like Outcomes/Pipeline/Stages -- mirrors the old
    // MeetingsController's ensure_viewer gate.
    if (!this.currentUser?.can_view_amanuensis) {
      this.router.transitionTo("discovery.latest");
    }
  }

  model(params) {
    return ajax("/amanuensis/api/meetings", {
      data: {
        status: params.status || undefined,
        canon_status: params.canon_status || undefined,
        before: params.before || undefined,
      },
    }).catch((error) => modelErrorFrom(error, "Failed to fetch meetings."));
  }

  titleToken() {
    return "Writers' Room Meetings";
  }
}
