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

  describe 'in combination' do
    let(:parent_activity) { create(:activity, occur_at: 1.day.from_now - 1.hour) }
    let(:child_activity_1) { create(:activity, occur_at: 1.day.from_now, combined_activity_parent: parent_activity) }
    let(:child_activity_2) { create(:activity, occur_at: 1.day.from_now, combined_activity_parent: parent_activity) }

    describe '#activity_combination_set' do
      context 'for a combination of three activities' do
        it 'should be an array of all three activities, regardless of which activity is called' do
          array_of_activities = [parent_activity, child_activity_1, child_activity_2]
          array_of_activities.each do |activity|
            expect(activity.send(:activity_combination_set)).to match_array array_of_activities
          end
        end
      end
    end

    describe '#activity_combination_parent' do
      context 'for a combination of three activities' do
        it 'should return the correct parent, regardless of which activity is called' do
          expect(parent_activity.send(:activity_combination_parent)).to eq parent_activity
          expect(child_activity_1.send(:activity_combination_parent)).to eq parent_activity
          expect(child_activity_2.send(:activity_combination_parent)).to eq parent_activity
        end
      end
    end

    describe 'the parent must be the earliest activity' do
      context 'when a later activity has been assigned the parent of the combination with an earlier activity' do
        let!(:later_activity) { create(:activity, occur_at: 1.day.from_now + 1.hour) }
        let(:earlier_activity) { build(:activity, occur_at: 1.day.from_now, combined_activity_parent: later_activity) }

        it 'does NOT save later activity as its parent' do
          expect(earlier_activity.save).to be false
          expect(earlier_activity.errors[:combined_activity_parent])
            .to eq ['Activity combination parent must be earliest activity.']
        end
      end

      context 'when an earlier activity has been assigned the parent of the combination with a later activity' do
        let(:earlier_activity) { create(:activity, occur_at: 1.day.from_now) }
        let(:later_activity) { build(:activity, occur_at: 1.day.from_now + 1.hour, combined_activity_parent: earlier_activity) }

        it 'successfully saves earlier activity as its parent' do
          expect(later_activity.save).to be true
        end
      end
    end

    describe 'enforce a maximum combination depth of one' do
      context 'when activities are daisy-chained' do
        let(:first_activity_daisy) { create(:activity, occur_at: 1.day.from_now - 1.hour) }
        let(:second_activity_daisy) { create(:activity, occur_at: 1.day.from_now, combined_activity_parent: first_activity_daisy) }
        let(:third_activity_daisy) { build(:activity, occur_at: 1.day.from_now, combined_activity_parent: second_activity_daisy) }

        it 'should NOT successfully save' do
          expect(third_activity_daisy.save).to be false
          expect(third_activity_daisy.errors[:combined_activity_parent])
            .to eq ['Activity combinations cannot be daisy-chained. There should be a single parent activity for a ' \
                    'group of combined activities.']
        end
      end
    end
  end
end
