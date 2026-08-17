# frozen_string_literal: true

module Amanuensis
  # Shared landing point for a fresh browser load of any /amanuensis/* page
  # that's a real Ember route -- typed URL, refresh, or opened in a new tab.
  # An in-app sidebar click never reaches this at all: Ember's router
  # intercepts it client-side before any request is made (see
  # amanuensis-route-map.js). Introduced as a one-page, one-controller
  # pattern for Outcomes; consolidated here now that more pages are
  # converting to Ember and would otherwise each need an identical copy.
  #
  # Inheriting straight from Discourse's own ::ApplicationController (not
  # skipping check_xhr the way a plain-HTML-rendering controller would) is
  # what makes this work: check_xhr's default behavior (raise RenderEmpty
  # for a plain non-XHR, non-JSON GET) is exactly what makes Discourse core
  # render `default/empty` inside the normal "application" layout -- the
  # same bootstrap every pure-Ember Discourse page relies on. Once that
  # shell boots, Ember's route-map takes over and renders the real page
  # client-side by calling that page's own *ApiController.
  class EmberBootstrapController < ::ApplicationController
    requires_plugin Amanuensis::PLUGIN_NAME

    # Explicit even though CodeQL can't see that Discourse core's own
    # ::ApplicationController already declares this -- it can't follow the
    # inheritance across the gem boundary, so it flags every subclass as
    # unprotected without an explicit declaration here too (same reasoning
    # as Amanuensis::ApiController).
    protect_from_forgery with: :exception

    # Real access control lives where the actual data is -- each page's own
    # *ApiController returns 403 for a non-writer/anonymous request, and its
    # Ember route's beforeModel redirects them client-side. Gating this
    # controller too would be a no-op for a normal browser GET anyway:
    # check_xhr fires before any before_action a subclass could add, and
    # short-circuits straight to the empty shell.
    def show
      # Belt-and-suspenders for the one case check_xhr's default RenderEmpty
      # path wouldn't already cover -- a request that arrives as XHR or
      # explicitly asks for JSON. Nothing in this app makes that request
      # against these paths, but if one ever does, render the same
      # bootstrap instead of hitting ActionView::MissingTemplate for a view
      # that doesn't exist.
      render 'default/empty'
    end
  end
end
