# frozen_string_literal: true

Amanuensis::Engine.routes.draw do
  # Every /amanuensis/* page is now Ember-rendered (see
  # assets/javascripts/discourse/amanuensis-route-map.js). These routes
  # exist only so a fresh browser load/refresh/new-tab can boot the
  # Discourse app shell before Ember's own router takes over -- see
  # EmberBootstrapController for why that's needed and how it works.
  # Actual page data is served by the JSON endpoints in the /api scope
  # below.
  get '/' => 'ember_bootstrap#show'
  get '/meetings' => 'ember_bootstrap#show'
  get '/meetings/:id' => 'ember_bootstrap#show'
  get '/pipeline' => 'ember_bootstrap#show'
  get '/stages/:stage' => 'ember_bootstrap#show'
  get '/stages/:stage/runs/:run_id' => 'ember_bootstrap#show'
  get '/outcomes' => 'ember_bootstrap#show'
  get '/uploads/new' => 'ember_bootstrap#show'

  scope '/api', defaults: { format: :json } do
    get '/meetings' => 'meetings_api#index'
    get '/meetings/:id' => 'meetings_api#show'
    get '/pipeline' => 'pipeline_api#active'
    get '/stages/:stage/runs' => 'stages_api#show'
    get '/stages/:stage/runs/:run_id' => 'stages_api#run'
    get '/outcomes' => 'outcomes_api#index'
    get '/uploads/config' => 'uploads_api#config'
    post '/uploads' => 'uploads_api#create'
    post '/uploads/:upload_id/complete' => 'uploads_api#complete'
  end
end

Discourse::Application.routes.draw do
  mount ::Amanuensis::Engine, at: '/amanuensis'
end
