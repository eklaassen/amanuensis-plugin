# frozen_string_literal: true

module ::Amanuensis
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace Amanuensis

    # app/ is autoloaded by Rails engine convention, but lib/ is not. The
    # permissions, access control, API client, and sanitizer modules all
    # live there, so without this they'd raise NameError at boot.
    config.autoload_paths << File.join(config.root, 'lib')
  end
end
