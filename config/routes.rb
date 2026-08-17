# frozen_string_literal: true

Amanuensis::Engine.routes.draw do
  get '/' => 'meetings#index'
  get '/meetings' => 'meetings#index'
  get '/meetings/:id' => 'meetings#show'

  get '/pipeline' => 'pipeline#active'
  get '/stages/:stage' => 'stages#show'
  get '/stages/:stage/runs/:run_id' => 'stages#run'

  get '/uploads/new' => 'uploads#new'

  # Outcomes is Ember-rendered (assets/javascripts/discourse/routes/amanuensis-outcomes.js)
  # so it doesn't need an engine route for HTML -- Discourse's normal SPA
  # fallback serves the Ember shell for /amanuensis/outcomes, same as any
  # other core client-side route. Only the JSON endpoint it calls lives here.
  scope '/api', defaults: { format: :json } do
    get '/outcomes' => 'outcomes_api#index'
    post '/uploads' => 'uploads_api#create'
    post '/uploads/:upload_id/complete' => 'uploads_api#complete'
  end
end

Discourse::Application.routes.draw do
  mount ::Amanuensis::Engine, at: '/amanuensis'
end
