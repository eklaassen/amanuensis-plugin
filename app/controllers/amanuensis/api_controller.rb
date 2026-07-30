# frozen_string_literal: true

module Amanuensis
  # Base class for future JSON endpoints (Phase 2+: agenda candidates,
  # agendas, uploads). Not yet routed to anything.
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
  end
end
