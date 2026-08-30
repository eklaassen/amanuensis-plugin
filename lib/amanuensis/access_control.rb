# frozen_string_literal: true

module Amanuensis
  # Thin controller concern around Amanuensis::Permissions. Deliberately does
  # not rescue/render anything itself -- it just raises, and lets the host
  # ApplicationController's rescue_from negotiate the response format. This
  # mirrors what the controller already did before this refactor.
  module AccessControl
    extend ActiveSupport::Concern

    included { before_action :ensure_plugin_enabled }

    private

    def ensure_plugin_enabled
      raise Discourse::NotFound unless SiteSetting.amanuensis_enabled
    end

    # These raise Discourse::NotFound (a 404, hiding existence) to preserve
    # the server-rendered meeting pages' current behaviour, which the
    # request specs assert on. Future JSON endpoints (Phase 2+) should raise
    # Discourse::InvalidAccess / Discourse::NotLoggedIn instead -- an
    # Ember-driven API can afford to distinguish "log in" from "you can't do
    # that" without leaking anything a 404-on-everything model is trying to
    # hide.
    def ensure_viewer
      raise Discourse::NotFound unless Amanuensis::Permissions.viewer?(current_user)
    end

    def ensure_writer
      raise Discourse::NotFound unless Amanuensis::Permissions.writer?(current_user)
    end

    def ensure_builder
      raise Discourse::NotFound unless Amanuensis::Permissions.builder?(current_user)
    end

    def ensure_relabel_speakers
      raise Discourse::NotFound unless Amanuensis::Permissions.relabel_speakers?(current_user)
    end
  end
end
