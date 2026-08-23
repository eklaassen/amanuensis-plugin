import Controller from "@ember/controller";
import { service } from "@ember/service";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { extractError } from "discourse/lib/ajax-error";

// Backs the meeting-detail template's "Relabel speakers" action -- gated in
// the template on currentUser.can_relabel_speakers_amanuensis (mirrors
// can_view_amanuensis/can_write_amanuensis, all three sourced from
// Amanuensis::Permissions server-side, see plugin.rb). The button being
// visible is a UX nicety, not the real gate: the server-side
// ensure_relabel_speakers check on MeetingsApiController#speaker_access is
// what actually enforces it.
export default class AmanuensisMeetingController extends Controller {
  @service currentUser;

  @tracked relabelBusy = false;
  @tracked relabelError = null;

  @action
  async openRelabelSpeakers() {
    this.relabelError = null;
    this.relabelBusy = true;
    try {
      const result = await ajax(`/amanuensis/api/meetings/${this.model.meeting.id}/speaker-access`, {
        type: "POST",
      });
      // A new tab, not a same-window navigation -- the relabel page lives on
      // Amanuensis's own origin (not this Discourse instance), and leaving
      // the meeting page open behind it means a moderator who relabels a
      // couple of speakers and comes back doesn't lose their place.
      window.open(result.url, "_blank", "noopener,noreferrer");
    } catch (error) {
      this.relabelError = extractError(error, "Could not open the relabel page.");
    } finally {
      this.relabelBusy = false;
    }
  }
}
