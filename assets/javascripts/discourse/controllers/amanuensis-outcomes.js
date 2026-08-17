import Controller from "@ember/controller";
import { tracked } from "@glimmer/tracking";

export default class AmanuensisOutcomesController extends Controller {
  queryParams = ["status", "before"];

  @tracked status = "complete";
  @tracked before = null;
}
