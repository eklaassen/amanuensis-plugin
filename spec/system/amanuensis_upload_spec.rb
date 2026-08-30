# frozen_string_literal: true

require_relative "../support/trivial_put_sink"
require_relative "../support/plugin_contract"

# Drives the real Ember upload form in a real browser. Two invariants a
# request spec structurally cannot exercise:
#
#   - CSRF: Rails disables forgery protection in the test env, and a
#     request spec never runs the page's JS, so ajax()'s automatic
#     X-CSRF-Token attachment (or the lack of it -- amanuensis-plugin#39's
#     defect 3) is invisible to one. This spec's happy path only succeeds
#     *because* the browser's real ajax() call carries a real token; if it
#     didn't, the create call below would 422 (see
#     uploads_api_controller_spec.rb's CSRF protection block for that
#     failure mode in isolation).
#   - the progress bar and the onbeforeunload navigation guard, which only
#     exist as browser-side state.
#
# What this does NOT test: SigV4 or any real object-storage signature.
# upload_url points at a TrivialPutSink -- a real HTTP server, so the
# browser's PUT is real network traffic, but the sink accepts any request
# and never inspects it. That invariant belongs to amanuensis's own
# real-MinIO integration test (workstream B), which is the only place
# either codebase ever produces a real signature.
describe "Amanuensis upload form" do
  fab!(:user)
  fab!(:group)

  let(:small_mp3) { Rails.root.join("spec/fixtures/media/small.mp3").to_s }
  let(:small_pdf) { Rails.root.join("spec/fixtures/pdf/small.pdf").to_s }

  # Off by default in the test env for system specs the same as for request
  # specs (Rails' own default) -- without this, the happy-path example below
  # would still pass with no X-CSRF-Token at all, since the server would
  # never actually be checking for one. Confirmed directly: temporarily
  # disabling the frontend's X-CSRF-Token attachment (frontend/discourse/
  # app/instance-initializers/csrf-token.js) with this around hook still in
  # place turns the happy-path example red; the same disable with this hook
  # absent left it green.
  around do |example|
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    begin
      example.run
    ensure
      ActionController::Base.allow_forgery_protection = original
    end
  end

  before do
    SiteSetting.amanuensis_enabled = true
    SiteSetting.amanuensis_api_url = "https://amanuensis.example.com"
    SiteSetting.amanuensis_api_secret = "read-secret"
    SiteSetting.amanuensis_admin_key = "admin-secret"
    SiteSetting.amanuensis_writing_group = group.name
    group.add(user)
    sign_in(user)
  end

  # A failed expectation before the explicit .stop at the bottom of an
  # example would otherwise skip it entirely, leaking that sink's listener
  # thread(s)/socket(s) for the rest of the run -- @sink here (set by the two
  # examples that construct one) always gets stopped, pass or fail.
  after { @sink&.stop }

  def create_credential
    Amanuensis::PluginContractFixture.credential_for(method: "POST", path: "/v1/plugin/uploads")
  end

  def complete_credential
    Amanuensis::PluginContractFixture.credential_for(
      method: "POST",
      path: "/v1/plugin/uploads/:upload_id/complete",
    )
  end

  def secret_for(credential)
    credential == :admin ? SiteSetting.amanuensis_admin_key : SiteSetting.amanuensis_api_secret
  end

  def stub_presign(upload_url:, content_type: "audio/mpeg")
    stub_request(:post, "https://amanuensis.example.com/v1/plugin/uploads").with(
      headers: {
        "Authorization" => "Bearer #{secret_for(create_credential)}",
      },
    ).to_return(
      status: 201,
      headers: {
        "Content-Type" => "application/json",
      },
      body: { upload_id: "upl_1", upload_url: upload_url, content_type: content_type }.to_json,
    )
  end

  def stub_complete
    stub_request(:post, "https://amanuensis.example.com/v1/plugin/uploads/upl_1/complete").with(
      headers: {
        "Authorization" => "Bearer #{secret_for(complete_credential)}",
      },
    ).to_return(
      status: 201,
      headers: {
        "Content-Type" => "application/json",
      },
      body: { meeting_id: "upl_1" }.to_json,
    )
  end

  # datetime-local inputs are set directly via JS rather than Capybara's
  # native fill_in -- typing into them reliably across drivers is a known
  # pain point, and what matters here is that Ember's updateRecordedAt fires
  # ({{on "input" ...}}), not how the keystrokes got there.
  def fill_upload_form(file:)
    fill_in("amanuensis-upload-title", with: "Writers' Room")
    page.execute_script(<<~JS)
      const el = document.getElementById('amanuensis-upload-recorded-at');
      el.value = '2026-08-01T19:00';
      el.dispatchEvent(new Event('input', { bubbles: true }));
    JS
    attach_file("amanuensis-upload-file", file)
  end

  it "uploads a recording end to end" do
    @sink = Amanuensis::TrivialPutSink.new
    stub_presign(upload_url: @sink.url)
    stub_complete

    visit "/amanuensis/uploads/new"
    fill_upload_form(file: small_mp3)
    click_button("Upload")

    expect(page).to have_css(".amanuensis-upload-message-success", text: /Uploaded/)
    expect(
      a_request(:post, "https://amanuensis.example.com/v1/plugin/uploads/upl_1/complete"),
    ).to have_been_made
  end

  it "rejects a .pdf client-side, without ever calling the presign endpoint" do
    # Never reached if the rejection works -- a bogus port, not a real sink.
    stub_presign(upload_url: "http://127.0.0.1:1/unreachable")

    visit "/amanuensis/uploads/new"
    fill_upload_form(file: small_pdf)
    click_button("Upload")

    expect(page).to have_css(".amanuensis-upload-message-error", text: /not allowed/)
    expect(
      a_request(:post, "https://amanuensis.example.com/v1/plugin/uploads"),
    ).not_to have_been_made
  end

  it "rejects an oversized file client-side, without ever calling the presign endpoint" do
    stub_presign(upload_url: "http://127.0.0.1:1/unreachable")

    # Discourse's own spec/support/helpers.rb defines a stub_const(target,
    # const, value) { block } that shadows RSpec's built-in stub_const(name,
    # value) for every spec in this codebase -- target is the real
    # class/module object, not a string, and the stub only lives for the
    # duration of the block, not the whole example. small.mp3 is ~440KB --
    # comfortably over this stubbed cap, so no need for a genuinely huge
    # fixture file.
    stub_const(Amanuensis::UploadPolicy, :MAX_BYTES, 1_000) do
      visit "/amanuensis/uploads/new"
      fill_upload_form(file: small_mp3)
      click_button("Upload")

      expect(page).to have_css(".amanuensis-upload-message-error", text: /too large/)
      expect(
        a_request(:post, "https://amanuensis.example.com/v1/plugin/uploads"),
      ).not_to have_been_made
    end
  end

  it "arms the navigation guard while the upload is in flight, then disarms it" do
    # response_delay opens a window to catch busy=true before the PUT
    # resolves -- without it the whole round trip can complete before this
    # spec ever gets to check window.onbeforeunload. Wide margin (not 1-2s):
    # Capybara's own have_css polling overhead alone can eat a couple of
    # seconds, so a thin delay here is a flaky test waiting to happen, not a
    # safety margin.
    @sink = Amanuensis::TrivialPutSink.new(response_delay: 8)
    stub_presign(upload_url: @sink.url)
    stub_complete

    visit "/amanuensis/uploads/new"
    fill_upload_form(file: small_mp3)
    click_button("Upload")

    expect(page).to have_css(".amanuensis-upload-progress")
    # Neither a JS Function nor a JS null survives evaluate_script's return
    # value round trip through the Playwright/Ruby bridge intact (a Function
    # comes back nil -- indistinguishable from an actual null -- and null
    # itself comes back as an empty Hash instead of Ruby nil). Confirmed
    # directly against this exact driver rather than assumed. typeof
    # (always a string) and strict-equality comparisons (always a boolean)
    # are the two JS-side primitives that do round-trip intact, so run the
    # comparison in JS and only hand a primitive back across the bridge.
    expect(page.evaluate_script("typeof window.onbeforeunload")).to eq("function")

    expect(page).to have_css(".amanuensis-upload-message-success", wait: 15)
    expect(page.evaluate_script("window.onbeforeunload === null")).to eq(true)
  end
end
