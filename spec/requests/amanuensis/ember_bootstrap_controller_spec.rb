# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Amanuensis::EmberBootstrapController, type: :request do
  before { SiteSetting.amanuensis_enabled = true }

  # A plain browser GET (no XHR header, no JSON format) is exactly what a
  # typed URL, refresh, or "open in new tab" produces. check_xhr intercepts
  # it before any before_action this controller could add ever runs, and
  # renders the same bootstrap shell every pure-Ember Discourse page uses --
  # real access control happens client-side (each Ember route's
  # beforeModel) and at the JSON endpoint it calls (each *ApiController,
  # which 403s a non-writer/anonymous request). This spec only asserts the
  # shell boots at all, for any visitor, on every converted path -- see the
  # individual *_api_controller_spec.rb files for access-control coverage.
  EMBER_PATHS = %w[
    /amanuensis/outcomes
    /amanuensis/meetings
    /amanuensis/meetings/some-id
    /amanuensis/pipeline
    /amanuensis/stages/transcribing
    /amanuensis/stages/transcribing/runs/some-run-id
    /amanuensis/uploads/new
  ].freeze

  EMBER_PATHS.each do |path|
    it "renders the Discourse app shell for #{path}, for an anonymous visitor" do
      get path

      expect(response.status).to eq(200)
      # Asserts on the actual rendered output rather than the template name
      # (render_template/assert_template needs the rails-controller-testing
      # gem, which this Discourse test harness doesn't bundle) -- main-outlet
      # is what Ember mounts into, so its presence is direct evidence the
      # real app shell booted rather than a 404 or the old plain-HTML page.
      expect(response.body).to include('main-outlet')
    end
  end

  it 'renders the shell for a signed-in user with no special access too' do
    sign_in(Fabricate(:user))

    get '/amanuensis/outcomes'

    expect(response.status).to eq(200)
    expect(response.body).to include('main-outlet')
  end
end
