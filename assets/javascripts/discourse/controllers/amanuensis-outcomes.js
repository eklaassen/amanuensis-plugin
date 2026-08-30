import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";

export default class AmanuensisOutcomesController extends Controller {
  @tracked status = "complete";
  @tracked before = null;
  queryParams = ["status", "before"];
}
