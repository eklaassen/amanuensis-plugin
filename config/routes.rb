# frozen_string_literal: true

Amanuensis::Engine.routes.draw do
  get '/' => 'meetings#index'
  get '/meetings' => 'meetings#index'
  get '/meetings/:id' => 'meetings#show'

  get '/uploads/new' => 'uploads#new'

  # Pipeline, Stages, and Outcomes are Ember-rendered
  # (assets/javascripts/discourse/routes/amanuensis-pipeline.js,
  # amanuensis-stage-runs.js, amanuensis-stage-run.js, and
  # amanuensis-outcomes.js), but a fresh browser load/refresh/new-tab still
  # needs a real Rails route to boot the Discourse app shell before Ember's
  # own router can take over -- there's nothing after this engine's mount
  # for the request to fall through to (Discourse core's only catch-all is
  # permalink-constrained, not a generic SPA fallback). See
  # EmberBootstrapController for how that boot happens.
  get '/pipeline' => 'ember_bootstrap#show'
  get '/stages/:stage' => 'ember_bootstrap#show'
  get '/stages/:stage/runs/:run_id' => 'ember_bootstrap#show'
  get '/outcomes' => 'ember_bootstrap#show'

  scope '/api', defaults: { format: :json } do
    get '/pipeline' => 'pipeline_api#active'
    get '/stages/:stage/runs' => 'stages_api#show'
    get '/stages/:stage/runs/:run_id' => 'stages_api#run'
    get '/outcomes' => 'outcomes_api#index'
    post '/uploads' => 'uploads_api#create'
    post '/uploads/:upload_id/complete' => 'uploads_api#complete'
  end
end

Discourse::Application.routes.draw do
  mount ::Amanuensis::Engine, at: '/amanuensis'
end
