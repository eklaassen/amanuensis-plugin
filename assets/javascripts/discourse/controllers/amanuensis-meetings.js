import Controller from "@ember/controller";
import { tracked } from "@glimmer/tracking";

// Not sent from the server: mirrors meeting_status/proposal_state enums on
// the amanuensis side, but there's no existing Ruby constant for either
// list here either -- see the identical comment on the stage-runs
// controller's OUTCOME_FILTERS.
const STATUS_FILTERS = [
  { value: "pending", label: "Pending" },
  { value: "downloading", label: "Downloading" },
  { value: "transcribing", label: "Transcribing" },
  { value: "summarizing", label: "Summarizing" },
  { value: "vaulting", label: "Vaulting" },
  { value: "archiving", label: "Archiving" },
  { value: "analyzing", label: "Analyzing" },
  { value: "complete", label: "Complete" },
  { value: "failed", label: "Failed" },
];

const CANON_STATUS_FILTERS = [
  { value: "pending", label: "Pending" },
  { value: "reviewed", label: "Reviewed" },
  { value: "applied", label: "Applied" },
];

export default class AmanuensisMeetingsController extends Controller {
  queryParams = ["status", "canon_status", "before"];

  @tracked status = null;
  @tracked canon_status = null;
  @tracked before = null;

  statusFilters = STATUS_FILTERS;
  canonStatusFilters = CANON_STATUS_FILTERS;
}
