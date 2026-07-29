# frozen_string_literal: true

module Amanuensis
  # Base class for server-rendered (plain HTML) controllers.
  class ApplicationController < ::ApplicationController
    requires_plugin Amanuensis::PLUGIN_NAME

    include Amanuensis::AccessControl

    # These pages are rendered server-side (plain HTML), so opt out of
    # Discourse's default check_xhr, which would otherwise serve the Ember
    # app bootstrap for non-XHR HTML requests instead of our views.
    skip_before_action :check_xhr
  end
end
