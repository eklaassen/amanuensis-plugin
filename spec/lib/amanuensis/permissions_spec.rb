# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Amanuensis::Permissions do
  fab!(:user)
  fab!(:admin)
  fab!(:moderator)
  fab!(:group)
  fab!(:other_group) { Fabricate(:group) }

  before do
    SiteSetting.amanuensis_viewing_group = ''
    SiteSetting.amanuensis_writing_group = ''
    SiteSetting.amanuensis_relabel_speakers_group = ''
  end

  describe '.viewer?' do
    it 'is false for an anonymous (nil) user' do
      expect(described_class.viewer?(nil)).to eq(false)
    end

    context 'with no viewing group configured (blank setting)' do
      it 'is false for a regular user' do
        expect(described_class.viewer?(user)).to eq(false)
      end

      it 'is true for a moderator' do
        expect(described_class.viewer?(moderator)).to eq(true)
      end

      it 'is true for an admin' do
        expect(described_class.viewer?(admin)).to eq(true)
      end
    end

    context 'with a viewing group configured' do
      before { SiteSetting.amanuensis_viewing_group = group.name }

      it 'is false for a regular user who is not a member' do
        expect(described_class.viewer?(user)).to eq(false)
      end

      it 'is true for a member of the viewing group' do
        group.add(user)
        expect(described_class.viewer?(user)).to eq(true)
      end

      it 'is true for a moderator regardless of membership' do
        expect(described_class.viewer?(moderator)).to eq(true)
      end

      it 'is true for an admin regardless of membership' do
        expect(described_class.viewer?(admin)).to eq(true)
      end
    end

    context 'writers implicitly get view access' do
      it 'is true for a writing-group member even with no viewing group configured' do
        SiteSetting.amanuensis_writing_group = other_group.name
        other_group.add(user)

        expect(described_class.viewer?(user)).to eq(true)
      end

      it 'is true for a writing-group member who is not a member of a separately configured viewing group' do
        SiteSetting.amanuensis_viewing_group = group.name
        SiteSetting.amanuensis_writing_group = other_group.name
        other_group.add(user)

        expect(described_class.viewer?(user)).to eq(true)
      end
    end
  end

  describe '.writer?' do
    it 'is false for an anonymous (nil) user' do
      expect(described_class.writer?(nil)).to eq(false)
    end

    context 'with no writing group configured (blank setting)' do
      it 'is false for a regular user' do
        expect(described_class.writer?(user)).to eq(false)
      end

      it 'is false even for a member of the (unrelated) viewing group' do
        SiteSetting.amanuensis_viewing_group = group.name
        group.add(user)

        expect(described_class.writer?(user)).to eq(false)
      end

      it 'is true for a moderator' do
        expect(described_class.writer?(moderator)).to eq(true)
      end

      it 'is true for an admin' do
        expect(described_class.writer?(admin)).to eq(true)
      end
    end

    context 'with a writing group configured' do
      before { SiteSetting.amanuensis_writing_group = group.name }

      it 'is false for a regular user who is not a member' do
        expect(described_class.writer?(user)).to eq(false)
      end

      it 'is true for a member of the writing group' do
        group.add(user)
        expect(described_class.writer?(user)).to eq(true)
      end

      it 'is false for a member of a different (viewing) group only' do
        SiteSetting.amanuensis_viewing_group = other_group.name
        other_group.add(user)

        expect(described_class.writer?(user)).to eq(false)
      end

      it 'is true for a moderator regardless of membership' do
        expect(described_class.writer?(moderator)).to eq(true)
      end

      it 'is true for an admin regardless of membership' do
        expect(described_class.writer?(admin)).to eq(true)
      end
    end
  end

  describe '.builder?' do
    it 'is false for an anonymous (nil) user' do
      expect(described_class.builder?(nil)).to eq(false)
    end

    it 'is false for a regular user' do
      expect(described_class.builder?(user)).to eq(false)
    end

    it 'is false for a member of both the viewing and writing groups' do
      SiteSetting.amanuensis_viewing_group = group.name
      SiteSetting.amanuensis_writing_group = group.name
      group.add(user)

      expect(described_class.builder?(user)).to eq(false)
    end

    it 'is true for a moderator' do
      expect(described_class.builder?(moderator)).to eq(true)
    end

    it 'is true for an admin' do
      expect(described_class.builder?(admin)).to eq(true)
    end
  end

  describe '.relabel_speakers?' do
    it 'is false for an anonymous (nil) user' do
      expect(described_class.relabel_speakers?(nil)).to eq(false)
    end

    context 'with no relabel-speakers group configured (blank setting)' do
      it 'is false for a regular user' do
        expect(described_class.relabel_speakers?(user)).to eq(false)
      end

      it 'is false even for a member of the (unrelated) writing group' do
        SiteSetting.amanuensis_writing_group = group.name
        group.add(user)

        expect(described_class.relabel_speakers?(user)).to eq(false)
      end

      it 'is true for a moderator' do
        expect(described_class.relabel_speakers?(moderator)).to eq(true)
      end

      it 'is true for an admin' do
        expect(described_class.relabel_speakers?(admin)).to eq(true)
      end
    end

    context 'with a relabel-speakers group configured' do
      before { SiteSetting.amanuensis_relabel_speakers_group = group.name }

      it 'is false for a regular user who is not a member' do
        expect(described_class.relabel_speakers?(user)).to eq(false)
      end

      it 'is true for a member of the relabel-speakers group' do
        group.add(user)
        expect(described_class.relabel_speakers?(user)).to eq(true)
      end

      it 'is false for a member of a different (writing) group only' do
        SiteSetting.amanuensis_writing_group = other_group.name
        other_group.add(user)

        expect(described_class.relabel_speakers?(user)).to eq(false)
      end

      it 'is true for a moderator regardless of membership' do
        expect(described_class.relabel_speakers?(moderator)).to eq(true)
      end

      it 'is true for an admin regardless of membership' do
        expect(described_class.relabel_speakers?(admin)).to eq(true)
      end
    end

    context 'with the actual out-of-the-box default (unset in this example group\'s before block)' do
      it 'defaults to "moderators" -- a plain user in that real Discourse group gets access' do
        SiteSetting.amanuensis_relabel_speakers_group = SiteSetting.defaults[:amanuensis_relabel_speakers_group]
        moderators_group = Group.find(Group::AUTO_GROUPS[:moderators])
        moderators_group.add(user)

        expect(described_class.relabel_speakers?(user)).to eq(true)
      end
    end
  end
end
