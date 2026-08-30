# frozen_string_literal: true

module Amanuensis
  # Sanitizes attacker-controlled rich text before it's rendered. Meeting
  # summaries are the only caller today; anything that renders
  # upload-derived or otherwise untrusted text later must reuse this rather
  # than growing its own allowlist.
  module Sanitizer
    ALLOWED_TAGS = %w[p br strong em b i ul ol li h3 h4 blockquote a].freeze
    ALLOWED_ATTRIBUTES = %w[href].freeze

    class << self
      def sanitize_summary(html)
        return "" if html.blank?

        ActionController::Base.helpers.sanitize(
          html,
          tags: ALLOWED_TAGS,
          attributes: ALLOWED_ATTRIBUTES,
        )
      end
    end
  end
end
