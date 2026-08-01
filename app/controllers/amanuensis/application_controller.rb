# frozen_string_literal: true

module Amanuensis
  # Base class for server-rendered (plain HTML) controllers.
  class ApplicationController < ::ApplicationController
    requires_plugin Amanuensis::PLUGIN_NAME

    # Explicit even though CodeQL can't see that Discourse core's own
    # ::ApplicationController already declares this -- it can't follow the
    # inheritance across the gem boundary, so it flags every subclass as
    # unprotected without an explicit declaration here too.
    protect_from_forgery with: :exception

    include Amanuensis::AccessControl

    # These pages are rendered server-side (plain HTML), so opt out of
    # Discourse's default check_xhr, which would otherwise serve the Ember
    # app bootstrap for non-XHR HTML requests instead of our views.
    skip_before_action :check_xhr

    # Shared doctype/head/container shell (app/views/layouts/amanuensis.html.erb)
    # for every server-rendered page. Subclasses no longer need `render
    # layout: false` + their own full HTML document.
    layout 'amanuensis'
  end
end
