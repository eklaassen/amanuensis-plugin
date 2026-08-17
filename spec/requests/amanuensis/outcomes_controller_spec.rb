# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Amanuensis::OutcomesController, type: :request do
  before { SiteSetting.amanuensis_enabled = true }

  # A plain browser GET (no XHR header, no JSON format) is exactly what a
  # typed URL, refresh, or "open in new tab" produces. check_xhr intercepts
  # it before ensure_writer/ensure_plugin_enabled ever run and renders the
  # same bootstrap shell every pure-Ember Discourse page uses -- real access
  # control happens client-side (the Ember route's beforeModel) and at the
  # JSON endpoint it calls (OutcomesApiController, which does 403 a
  # non-writer/anonymous request). This spec is only asserting the shell
  # boots at all, for any visitor -- see outcomes_api_controller_spec.rb for
  # the actual access-control coverage.
  it 'renders the Discourse app shell so Ember can take over, for an anonymous visitor' do
    get '/amanuensis/outcomes'

    expect(response.status).to eq(200)
    expect(response).to render_template('default/empty')
  end

  it 'renders the Discourse app shell for a signed-in user with no special access' do
    sign_in(Fabricate(:user))

    get '/amanuensis/outcomes'

    expect(response.status).to eq(200)
    expect(response).to render_template('default/empty')
  end
end
