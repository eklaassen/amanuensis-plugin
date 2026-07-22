# frozen_string_literal: true

module ::Amanuensis
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace Amanuensis
  end
end
