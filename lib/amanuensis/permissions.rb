# frozen_string_literal: true

module Amanuensis
  # Pure policy object with no controller coupling, so specs, jobs, and
  # serializers can all call it.
  #
  # Fail-closed throughout: a nil (anonymous) user is never a viewer, writer,
  # or builder, and a blank group setting is never "everyone" -- it means
  # staff-only.
  module Permissions
    class << self
      # staff || writer? || member of the viewing group
      def viewer?(user)
        return false if user.nil?
        return true if user.staff?
        return true if writer?(user)

        group_member?(user, SiteSetting.amanuensis_viewing_group)
      end

      # staff || member of the writing group
      def writer?(user)
        return false if user.nil?
        return true if user.staff?

        group_member?(user, SiteSetting.amanuensis_writing_group)
      end

      # staff only, for now
      def builder?(user)
        return false if user.nil?

        user.staff?
      end

      # staff || member of the relabel-speakers group (defaults to
      # "moderators" -- see config/settings.yml). Deliberately its own
      # setting rather than reusing writing_group: relabeling rewrites a
      # meeting's stored transcript, a narrower and more sensitive action
      # than the rest of what writer? gates.
      def relabel_speakers?(user)
        return false if user.nil?
        return true if user.staff?

        group_member?(user, SiteSetting.amanuensis_relabel_speakers_group)
      end

      private

      def group_member?(user, group_name)
        return false if group_name.blank?

        group = Group.find_by(name: group_name)
        return false if group.nil?

        GroupUser.exists?(group_id: group.id, user_id: user.id)
      end
    end
  end
end
