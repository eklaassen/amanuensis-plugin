import { on } from "@ember/modifier";
import { trustHTML } from "@ember/template";

function progressBarStyle(percent) {
  return trustHTML(`width: ${percent}%`);
}

export default <template>
  <div class="amanuensis-container">
    <h1 class="amanuensis-page-title">Upload a recording</h1>
    <p class="amanuensis-hint">
      The file goes straight to storage from your browser, then enters the
      pipeline for transcription. Allowed:
      {{@controller.allowedExtensionsHint}}. Maximum
      {{@controller.maxMb}}
      MB.
    </p>

    <form
      class="amanuensis-upload-form"
      autocomplete="off"
      {{on "submit" @controller.submit}}
    >
      <label class="amanuensis-field">
        <span class="amanuensis-field-label">Title</span>
        <input
          type="text"
          id="amanuensis-upload-title"
          placeholder="Writers' Room"
          value={{@controller.title}}
          {{on "input" @controller.updateTitle}}
          required
        />
      </label>

      <label class="amanuensis-field">
        <span class="amanuensis-field-label">Recorded at</span>
        <input
          type="datetime-local"
          id="amanuensis-upload-recorded-at"
          value={{@controller.recordedAt}}
          {{on "input" @controller.updateRecordedAt}}
          required
        />
      </label>

      <label class="amanuensis-field">
        <span class="amanuensis-field-label">Recording</span>
        <input
          type="file"
          id="amanuensis-upload-file"
          accept={{@controller.acceptAttr}}
          {{on "change" @controller.chooseFile}}
          required
        />
      </label>

      <button
        type="submit"
        class="amanuensis-button"
        disabled={{@controller.busy}}
      >Upload</button>
    </form>

    {{#if @controller.busy}}
      <div class="amanuensis-upload-progress">
        <div class="amanuensis-progress-track">
          <div
            class="amanuensis-progress-bar"
            style={{progressBarStyle @controller.progressPercent}}
          ></div>
        </div>
        <p class="amanuensis-hint">{{@controller.progressLabel}}</p>
      </div>
    {{/if}}

    {{#if @controller.message}}
      <div
        class="amanuensis-upload-message amanuensis-upload-message-{{@controller.messageKind}}"
      >{{@controller.message}}</div>
    {{/if}}
  </div>
</template>
