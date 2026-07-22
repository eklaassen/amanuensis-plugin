# frozen_string_literal: true

# name: amanuensis
# about: Discourse plugin for viewing Writers' Room meeting records from Amanuensis
# version: 0.1.0
# authors: Elliott Klaassen
# url: https://github.com/eklaassen/amanuensis

register_asset 'stylesheets/amanuensis.scss'

enabled_site_setting :amanuensis_enabled

register_svg_icon 'clipboard-list' if respond_to?(:register_svg_icon)

module ::Amanuensis
  PLUGIN_NAME = 'amanuensis'
end

require_relative 'lib/amanuensis/engine'

after_initialize do
  Amanuensis::Engine.routes.draw do
    get '/' => 'meetings#index'
    get '/meetings' => 'meetings#index'
    get '/meetings/:id' => 'meetings#show'
  end

  Discourse::Application.routes.append do
    mount ::Amanuensis::Engine, at: '/amanuensis'
  end
end
