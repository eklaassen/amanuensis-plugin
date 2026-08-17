import Controller from "@ember/controller";
import { tracked } from "@glimmer/tracking";

// Not sent from the server: there's no existing Ruby constant for this list
// either (the old ERB view had it as a literal array too), so there's
// nothing to drift from by keeping it here.
const OUTCOME_FILTERS = [
  { value: "succeeded", label: "Succeeded" },
  { value: "failed", label: "Failed" },
  { value: "retrying", label: "Retrying" },
  { value: "rewound", label: "Rewound" },
  { value: "deferred", label: "Deferred" },
  { value: "running", label: "Running" },
];

export default class AmanuensisStageRunsController extends Controller {
  queryParams = ["outcome", "before"];

  @tracked stage = null;
  @tracked outcome = null;
  @tracked before = null;

  outcomeFilters = OUTCOME_FILTERS;
}
