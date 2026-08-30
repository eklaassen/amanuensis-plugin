import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { extractError } from "discourse/lib/ajax-error";

// preventDefault() is the modern trigger for the unsaved-changes prompt;
// returnValue is kept for Chrome/Edge < 119. Returning a string is the
// legacy form and browsers ignore the text anyway -- the dialog always
// shows its own wording.
function warnBeforeUnload(event) {
  event.preventDefault();
  event.returnValue = true;
}

export default class AmanuensisUploadNewController extends Controller {
  @tracked title = "";
  @tracked recordedAt = "";
  @tracked selectedFile = null;
  @tracked busy = false;
  @tracked progressPercent = 0;
  @tracked progressLabel = "";
  @tracked message = null;
  @tracked messageKind = null; // "error" | "success"

  get maxMb() {
    return Math.round(this.model.max_bytes / 1_048_576);
  }

  get acceptAttr() {
    return this.model.allowed_extensions
      .map((extension) => `.${extension}`)
      .join(",");
  }

  get allowedExtensionsHint() {
    return this.model.allowed_extensions.join(", ");
  }

  extensionOf(filename) {
    const parts = String(filename).split(".");
    return parts.length > 1 ? parts.pop().toLowerCase() : "";
  }

  showMessage(text, kind) {
    this.message = text;
    this.messageKind = kind;
  }

  setBusy(busy) {
    this.busy = busy;
    window.onbeforeunload = busy ? warnBeforeUnload : null;
  }

  // XHR rather than ajax()/fetch: neither exposes upload progress events,
  // and at 1.5 GB a bar that never moves is indistinguishable from a hang.
  // No CSRF header here -- upload_url is a presigned URL to external
  // storage, not a same-origin Discourse endpoint.
  putFile(url, file, contentType) {
    return new Promise((resolve, reject) => {
      const xhr = new XMLHttpRequest();
      xhr.open("PUT", url, true);
      // Must match the type the server signed (UploadsApiController#create
      // passes it through from the presign response). Content-Type is a
      // signed header on this PUT; left alone, the browser sends whatever
      // it infers from the file (audio/x-m4a rather than audio/mp4, or
      // nothing), and the signature check fails.
      if (contentType) {
        xhr.setRequestHeader("Content-Type", contentType);
      }
      xhr.upload.onprogress = (event) => {
        if (!event.lengthComputable) {
          return;
        }
        const pct = Math.round((event.loaded / event.total) * 100);
        this.progressPercent = pct;
        this.progressLabel = `Uploading… ${pct}%`;
      };
      xhr.onload = () => {
        if (xhr.status >= 200 && xhr.status < 300) {
          resolve();
        } else {
          reject(new Error(`Upload failed (${xhr.status})`));
        }
      };
      xhr.onerror = () => reject(new Error("Upload failed — network error"));
      xhr.send(file);
    });
  }

  @action
  updateTitle(event) {
    this.title = event.target.value;
  }

  @action
  updateRecordedAt(event) {
    this.recordedAt = event.target.value;
  }

  @action
  chooseFile(event) {
    this.selectedFile = event.target.files[0] || null;
  }

  @action
  async submit(event) {
    event.preventDefault();
    this.message = null;

    const file = this.selectedFile;
    if (!file) {
      this.showMessage("Choose a recording first.", "error");
      return;
    }

    // Mirrors the server checks purely for fast feedback -- the server and
    // the pipeline both re-validate, and neither trusts this.
    const allowed = this.model.allowed_extensions;
    if (!allowed.includes(this.extensionOf(file.name))) {
      this.showMessage(
        `That file type is not allowed. Allowed: ${allowed.join(", ")}.`,
        "error"
      );
      return;
    }
    if (file.size > this.model.max_bytes) {
      this.showMessage("That file is too large.", "error");
      return;
    }

    const meta = {
      filename: file.name,
      size_bytes: file.size,
      title: this.title,
      recorded_at: this.recordedAt,
    };

    this.setBusy(true);
    this.progressPercent = 0;
    this.progressLabel = "Preparing…";

    try {
      const ticket = await ajax("/amanuensis/api/uploads", {
        type: "POST",
        data: meta,
      });
      await this.putFile(ticket.upload_url, file, ticket.content_type);
      this.progressLabel = "Finishing…";
      const done = await ajax(
        `/amanuensis/api/uploads/${encodeURIComponent(ticket.upload_id)}/complete`,
        {
          type: "POST",
          data: meta,
        }
      );

      this.setBusy(false);
      this.title = "";
      this.recordedAt = "";
      this.selectedFile = null;
      // A file input's displayed value can't be cleared by reassigning a
      // tracked property (it's not bindable), so this is the one place
      // that still reaches into the DOM directly -- same as the plain-JS
      // version this replaced.
      const fileInput = document.getElementById("amanuensis-upload-file");
      if (fileInput) {
        fileInput.value = "";
      }
      this.showMessage(
        `Uploaded. The recording is now being transcribed${done.meeting_id ? ` (meeting ${done.meeting_id}).` : "."}`,
        "success"
      );
    } catch (error) {
      this.setBusy(false);
      // putFile's own rejections are plain Errors with the message already
      // meant for display; ajax() rejections need extractError to pull the
      // {errors: [...]} shape UploadsApiController renders out of the jqXHR.
      const text =
        error instanceof Error
          ? error.message
          : extractError(error, "Upload failed.");
      this.showMessage(text, "error");
    }
  }
}
