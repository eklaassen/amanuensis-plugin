# frozen_string_literal: true

module Amanuensis
  # Landing point for a fresh browser load of /amanuensis/outcomes -- typed
  # URL, refresh, or opened in a new tab. An in-app sidebar click never
  # reaches this at all: Ember's router intercepts it client-side before any
  # request is made (see amanuensis-route-map.js).
  #
  # Deliberately does NOT inherit from Amanuensis::ApplicationController --
  # that base class skips check_xhr and forces layout 'amanuensis' so the
  # still-server-rendered pages (Meetings/Pipeline/Stages/Upload) can render
  # real HTML. This page wants the opposite: check_xhr's default behavior
  # (raise RenderEmpty for a plain non-XHR, non-JSON GET) is exactly what
  # makes Discourse core render `default/empty` inside the normal
  # "application" layout -- the same bootstrap every other pure-Ember page
  # relies on. Once that shell boots, Ember's route-map takes over and
  # renders the real page client-side by calling OutcomesApiController.
  class OutcomesController < ::ApplicationController
    requires_plugin Amanuensis::PLUGIN_NAME

    # Explicit even though CodeQL can't see that Discourse core's own
    # ::ApplicationController already declares this -- it can't follow the
    # inheritance across the gem boundary, so it flags every subclass as
    # unprotected without an explicit declaration here too (same reasoning
    # as Amanuensis::ApplicationController and Amanuensis::ApiController).
    protect_from_forgery with: :exception

    # Real access control lives where the actual data is: OutcomesApiController
    # returns 403 for a non-writer/anonymous request, and the Ember route's
    # beforeModel redirects them client-side. Gating this action too would be
    # a no-op for a plain browser GET anyway -- check_xhr (declared on the
    # ::ApplicationController ancestor) fires before any before_action this
    # class adds, and short-circuits straight to the empty shell.
    include Amanuensis::AccessControl
    before_action :ensure_writer

    def index
      # Belt-and-suspenders for the one case check_xhr's default RenderEmpty
      # path wouldn't already cover -- a request that arrives as XHR or
      # explicitly asks for JSON. Nothing in this app makes that request
      # (Ember calls /amanuensis/api/outcomes, never this path), but if one
      # ever does, render the same bootstrap instead of hitting
      # ActionView::MissingTemplate for a view that doesn't exist.
      render 'default/empty'
    end
  end
end
