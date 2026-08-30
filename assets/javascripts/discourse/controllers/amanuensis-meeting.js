import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
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
  // Not referenced in this file, but the co-located template reads it via
  // @controller.currentUser.can_relabel_speakers_amanuensis -- the lint rule
  // can't see across the controller/template split.
  // eslint-disable-next-line discourse/no-unused-services
  @service currentUser;

  @tracked relabelBusy = false;
  @tracked relabelError = null;

  @action
  async openRelabelSpeakers() {
    this.relabelError = null;
    this.relabelBusy = true;

    // Opened synchronously, inside the click handler's own call stack, and
    // BEFORE the ajax await below -- popup blockers key off whether
    // window.open() runs within the original user gesture, and an
    // already-awaited call falls outside that window on most browsers
    // (Safari in particular). Navigating this tab's location once the real
    // URL is known, rather than opening a second tab after the fact, keeps
    // exactly one tab in play either way.
    //
    // Not passing "noopener" in the features string: doing so makes
    // window.open() itself return null, leaving nothing to navigate later.
    // tab.opener is cleared by hand below instead, for the same effect.
    const tab = window.open("about:blank", "_blank");

    try {
      const result = await ajax(
        `/amanuensis/api/meetings/${this.model.meeting.id}/speaker-access`,
        {
          type: "POST",
        }
      );

      // Amanuensis validates this server-side (MeetingsApiController#speaker_access
      // rejects anything that isn't a plain http(s) url before it ever reaches
      // here), but re-checking here means a malformed response fails closed
      // instead of navigating the tab to something unexpected.
      let url;
      try {
        url = new URL(result.url);
      } catch {
        url = null;
      }
      if (!url || (url.protocol !== "https:" && url.protocol !== "http:")) {
        tab?.close();
        this.relabelError = "Could not open the relabel page.";
        return;
      }

      if (tab) {
        tab.opener = null;
        tab.location.href = url.href;
      } else {
        // The synchronous open above was itself blocked -- rare, but
        // possible under an aggressive popup blocker.
        this.relabelError =
          "Could not open the relabel page. Allow pop-ups for this site and try again.";
      }
    } catch (error) {
      tab?.close();
      this.relabelError = extractError(
        error,
        "Could not open the relabel page."
      );
    } finally {
      this.relabelBusy = false;
    }
  }
}
