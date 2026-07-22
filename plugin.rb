# frozen_string_literal: true

# name: amanuensis
# about: Discourse plugin for viewing Writers' Room meeting records from Amanuensis
# version: 0.1.0
# authors: Elliott Klaassen
# url: https://github.com/eklaassen/amanuensis

register_asset 'stylesheets/amanuensis.scss'

enabled_site_setting :amanuensis_enabled

register_svg_icon 'clipboard-list' if respond_to?(:register_svg_icon)

after_initialize do
  module ::Amanuensis
    PLUGIN_NAME = 'amanuensis'

    class Engine < ::Rails::Engine
      engine_name PLUGIN_NAME
      isolate_namespace Amanuensis
    end
  end

  Amanuensis::Engine.routes.draw do
    get '/' => 'meetings#index'
    get '/meetings' => 'meetings#index'
    get '/meetings/:id' => 'meetings#show'
  end

  Discourse::Application.routes.append do
    mount ::Amanuensis::Engine, at: '/amanuensis'
  end
end
