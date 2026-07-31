# frozen_string_literal: true

Amanuensis::Engine.routes.draw do
  get '/' => 'meetings#index'
  get '/meetings' => 'meetings#index'
  get '/meetings/:id' => 'meetings#show'

  get '/pipeline' => 'pipeline#active'
  get '/stages/:stage' => 'stages#show'
  get '/stages/:stage/runs/:run_id' => 'stages#run'
  get '/outcomes' => 'outcomes#index'
end

Discourse::Application.routes.draw do
  mount ::Amanuensis::Engine, at: '/amanuensis'
end
