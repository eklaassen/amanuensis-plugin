# frozen_string_literal: true

Amanuensis::Engine.routes.draw do
  get '/' => 'meetings#index'
  get '/meetings' => 'meetings#index'
  get '/meetings/:id' => 'meetings#show'
end

Discourse::Application.routes.draw do
  mount ::Amanuensis::Engine, at: '/amanuensis'
end
