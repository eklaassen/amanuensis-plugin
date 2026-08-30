# frozen_string_literal: true

# name: amanuensis
# about: Discourse plugin for viewing Writers' Room meeting records from Amanuensis
# version: 0.1.0
# authors: Elliott Klaassen
# url: https://github.com/eklaassen/amanuensis

register_asset "stylesheets/amanuensis.scss"

enabled_site_setting :amanuensis_enabled

register_svg_icon "clipboard-list" if respond_to?(:register_svg_icon)
register_svg_icon "list-check" if respond_to?(:register_svg_icon)
register_svg_icon "flag-checkered" if respond_to?(:register_svg_icon)
register_svg_icon "upload" if respond_to?(:register_svg_icon)

module ::Amanuensis
  PLUGIN_NAME = "amanuensis"
end

require_relative "lib/amanuensis/engine"

after_initialize do
  # Single source of truth stays Amanuensis::Permissions -- the sidebar
  # initializer reads these flags instead of reimplementing group-membership
  # checks in JS.
  add_to_serializer(:current_user, :can_view_amanuensis) { Amanuensis::Permissions.viewer?(object) }
  add_to_serializer(:current_user, :can_write_amanuensis) do
    Amanuensis::Permissions.writer?(object)
  end
  add_to_serializer(:current_user, :can_relabel_speakers_amanuensis) do
    Amanuensis::Permissions.relabel_speakers?(object)
  end
end
