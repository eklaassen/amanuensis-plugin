# frozen_string_literal: true

module Amanuensis
  # Shared landing point for every /amanuensis/* path -- all of them are
  # real Ember routes now (see amanuensis-route-map.js): Meetings, a single
  # meeting, Pipeline, a stage's runs, a single run, Outcomes, Upload. A
  # fresh browser load/refresh/new-tab still needs a real Rails route to
  # boot the Discourse app shell before Ember's own router can take over:
  # there's nothing after this engine's mount for the request to fall
  # through to (Discourse core's only catch-all is permalink-constrained,
  # not a generic SPA fallback). An in-app sidebar click never reaches this
  # controller at all -- Ember's router intercepts it client-side before
  # any request is made.
  #
  # Not inheriting from ::ApplicationController by way of any
  # check_xhr-skipping base class is what makes this work: check_xhr's
  # default behavior (raise RenderEmpty for a plain non-XHR, non-JSON GET)
  # is exactly what makes Discourse core render `default/empty` inside the
  # normal "application" layout -- the same bootstrap every pure-Ember
  # Discourse page relies on.
  #
  # Real access control lives where the actual data is -- each page's own
  # *ApiController returns 403 for a non-writer/anonymous request, and its
  # Ember route's beforeModel redirects them client-side. Gating this
  # controller too would be a no-op for a normal browser GET anyway:
  # check_xhr fires before any before_action a subclass could add, and
  # short-circuits straight to the empty shell.
  class EmberBootstrapController < ::ApplicationController
    requires_plugin Amanuensis::PLUGIN_NAME

    # Explicit even though CodeQL can't see that Discourse core's own
    # ::ApplicationController already declares this -- it can't follow the
    # inheritance across the gem boundary, so it flags every subclass as
    # unprotected without an explicit declaration here too (same reasoning
    # as Amanuensis::ApiController).
    protect_from_forgery with: :exception

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
