# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Amanuensis plugin initialization' do
  fab!(:user)
  fab!(:group)
  fab!(:other_group) { Fabricate(:group) }

  before do
    SiteSetting.amanuensis_viewing_group = ''
    SiteSetting.amanuensis_writing_group = ''
  end

  def serialized_flags(user)
    CurrentUserSerializer.new(user, scope: Guardian.new(user), root: false).as_json.deep_symbolize_keys
  end

  describe 'current_user serializer' do
    it 'exposes neither flag for a user in no configured group' do
      flags = serialized_flags(user)

      expect(flags[:can_view_amanuensis]).to eq(false)
      expect(flags[:can_write_amanuensis]).to eq(false)
    end

    it 'exposes can_view_amanuensis only for a viewing-group member' do
      SiteSetting.amanuensis_viewing_group = group.name
      group.add(user)

      flags = serialized_flags(user)

      expect(flags[:can_view_amanuensis]).to eq(true)
      expect(flags[:can_write_amanuensis]).to eq(false)
    end

    it 'exposes both flags for a writing-group member' do
      SiteSetting.amanuensis_writing_group = other_group.name
      other_group.add(user)

      flags = serialized_flags(user)

      expect(flags[:can_view_amanuensis]).to eq(true)
      expect(flags[:can_write_amanuensis]).to eq(true)
    end
  end
end
