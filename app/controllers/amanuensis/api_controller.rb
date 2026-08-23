# frozen_string_literal: true

module Amanuensis
  # Base class for every JSON endpoint (MeetingsApiController,
  # PipelineApiController, StagesApiController, OutcomesApiController,
  # UploadsApiController) -- each backs an Ember route the same way.
  #
  # Unlike ApplicationController, this does not skip check_xhr -- JSON
  # requests from Ember's ajax() are XHR by definition. It also does not
  # skip verify_authenticity_token: ajax() sends X-CSRF-Token automatically,
  # so there's no reason to weaken CSRF protection on write endpoints here.
  class ApiController < ::ApplicationController
    requires_plugin Amanuensis::PLUGIN_NAME
    requires_login

    # Explicit even though CodeQL can't see that Discourse core's own
    # ::ApplicationController already declares this -- it can't follow the
    # inheritance across the gem boundary, so it flags every subclass as
    # unprotected without an explicit declaration here too. ajax() still
    # sends X-CSRF-Token automatically, so this doesn't change behavior for
    # legitimate JSON requests.
    protect_from_forgery with: :exception

    include Amanuensis::AccessControl

    private

    # JSON callers get 403 where a hard page load gets 404 (see
    # EmberBootstrapController). Hiding a page's existence from someone who
    # shouldn't know about it is worth a 404 for that first HTML request;
    # for an XHR made by code that already rendered the page, the caller
    # already knows the endpoint exists, and a 404 there just makes a
    # permissions problem look like a routing bug.
    #
    # These override AccessControl's versions -- a method on the class wins
    # over one from an included module.
    def ensure_viewer
      raise Discourse::InvalidAccess unless Amanuensis::Permissions.viewer?(current_user)
    end

    def ensure_writer
      raise Discourse::InvalidAccess unless Amanuensis::Permissions.writer?(current_user)
    end

    def ensure_builder
      raise Discourse::InvalidAccess unless Amanuensis::Permissions.builder?(current_user)
    end

    def ensure_relabel_speakers
      raise Discourse::InvalidAccess unless Amanuensis::Permissions.relabel_speakers?(current_user)
    end
  end
end
