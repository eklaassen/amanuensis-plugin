# frozen_string_literal: true

module Amanuensis
  # Shared proposal/history serializers for the outcome-detail JSON shape --
  # used by OutcomesApiController#show (the full outcome page) and by
  # MeetingsApiController#show (just to derive the has_outcome flag that
  # drives the "see outcome details" link on the meeting page).
  module ProposalSerialization
    extend ActiveSupport::Concern

    PROPOSAL_DECISIONS = %w[pending approved rejected edited].freeze

    private

    def serialize_proposal(proposal)
      items = proposal['items'] || []

      groups = PROPOSAL_DECISIONS.filter_map do |decision|
        decision_items = items.select { |i| i['decision'] == decision }
        next if decision_items.empty?

        {
          decision: decision,
          decision_label: decision.capitalize,
          count: decision_items.length,
          items: decision_items.map { |i| serialize_proposal_item(i, show_edited: decision == 'edited') }
        }
      end

      { state: proposal['state'], groups: groups }
    end

    def serialize_proposal_item(item, show_edited:)
      {
        operation: item['operation'],
        target_type: item['target_type'],
        target_field: item['target_field'],
        proposed_value: item['proposed_value'] ? format_value(item['proposed_value']) : nil,
        edited_value: show_edited && item['edited_value'] ? format_value(item['edited_value']) : nil,
        show_edited: show_edited
      }
    end

    def serialize_history_entry(entry)
      {
        created_at: formatted_date(entry['created_at']),
        source: entry['source'],
        actor: entry['actor'],
        summary: entry['summary']
      }
    end

    def format_value(value)
      case value
      when Hash, Array
        value.to_json
      when nil
        '—'
      else
        value.to_s
      end
    end
  end
end
