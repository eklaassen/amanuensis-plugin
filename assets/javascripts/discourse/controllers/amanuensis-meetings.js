import Controller from "@ember/controller";
import { tracked } from "@glimmer/tracking";

export default class AmanuensisMeetingsController extends Controller {
  queryParams = ["status", "before"];

  @tracked status = null;
  @tracked before = null;
}
