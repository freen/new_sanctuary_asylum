require 'rails_helper'

RSpec.describe Activity, type: :model do

  it { is_expected.to belong_to :friend }
  it { is_expected.to belong_to :judge }
  it { is_expected.to belong_to :location }
  it { is_expected.to belong_to :region }
  it { is_expected.to belong_to :activity_type }

  it { is_expected.to validate_presence_of :friend_id }
  it { is_expected.to validate_presence_of :region_id }
  it { is_expected.to validate_presence_of :occur_at }
  it { is_expected.to validate_presence_of :activity_type_id }

  describe 'Combined Activities' do
    describe 'the parent in any activity combination must be the earliest activity' do
      context 'later_activity has been assigned the parent of the combination with earlier_activity' do
        let(:later_activity) { create(:activity, occur_at: 1.day.from_now + 1.hour) }
        let(:earlier_activity) { build(:activity, occur_at: 1.day.from_now, combined_activity_parent: later_activity) }

        it 'does NOT save later_activity as its parent' do
          expect(earlier_activity.save).to be false
          expect(earlier_activity.errors[:combined_activity_parent])
            .to eq ['Activity combination parent must be earliest activity.']
        end
      end

      context 'earlier_activity has been assigned the parent of the combination with later_activity' do
        let(:later_activity) { build(:activity, occur_at: 1.day.from_now + 1.hour, combined_activity_parent: earlier_activity) }
        let(:earlier_activity) { create(:activity, occur_at: 1.day.from_now) }

        it 'successfully saves earlier_activity as its parent' do
          expect(later_activity.save).to be true
        end
      end
    end

    describe 'have a maximum depth of one' do
      context 'activities which are daisy-chained' do
        let(:first_activity) { create(:activity, occur_at: 1.day.from_now - 1.hour) }
        let(:second_activity) { create(:activity, occur_at: 1.day.from_now, combined_activity_parent: first_activity) }
        let(:third_activity) { build(:activity, occur_at: 1.day.from_now, combined_activity_parent: second_activity) }

        it 'should NOT successfully save' do
          expect(third_activity.save).to be false
          expect(third_activity.errros[:combined_activity_parent])
            .to eq ['Activity combinations cannot be daisy-chained. There should be a single parent activity for a ' \
                    'group of combined activities.']
        end
      end

      context 'activities which are not daisy-chained' do
        let(:first_activity) { create(:activity, occur_at: 1.day.from_now - 1.hour) }
        let(:second_activity) { build(:activity, occur_at: 1.day.from_now, combined_activity_parent: first_activity) }
        let(:third_activity) { build(:activity, occur_at: 1.day.from_now, combined_activity_parent: first_activity) }

        it 'should successfully save' do
          expect(second_activity.save).to be true
          expect(third_activity.save).to be true
        end
      end
    end
  end
end
