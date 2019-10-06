class Activity < ApplicationRecord
  belongs_to :friend
  belongs_to :region
  belongs_to :judge
  belongs_to :location
  belongs_to :activity_type
  belongs_to :combined_activity_parent, class_name: 'Activity', optional: true
  has_many :combined_activity_children, class_name: 'Activity', foreign_key: 'combined_activity_parent'
  has_many :accompaniments, -> { order(created_at: :asc) }, dependent: :destroy
  has_many :users, through: :accompaniments
  has_many :accompaniment_reports, dependent: :destroy

  validates :activity_type_id, :occur_at, :friend_id, :region_id, presence: true
  validate :activity_combination_max_depth_of_one
  validate :activity_combination_parent_must_be_earliest_activity

  scope :accompaniment_eligible, -> {
    joins(:activity_type).where(activity_types: { accompaniment_eligible: true })
  }

  scope :non_accompaniment_eligible, -> {
    joins(:activity_type).where(activity_types: { accompaniment_eligible: false })
  }

  scope :by_region, ->(region) {
    where(region_id: region.id)
  }

  scope :confirmed, -> {
    where(confirmed: true)
  }

  scope :unconfirmed, -> {
    where(confirmed: false)
  }

  scope :by_dates, ->(period_begin, period_end) {
    where('occur_at >= ? AND occur_at <= ? ',
          period_begin,
          period_end)
  }

  scope :by_order, ->(order) {
    order(occur_at: order).group_by do |activity|
      activity.occur_at.to_date
    end
  }

  scope :exclude_combined_children, -> {
    where(combined_activity_parent: nil)
  }

  scope :for_time_confirmed, ->(period_begin, period_end) {
                               accompaniment_eligible
                                 .exclude_combined_children
                                 .confirmed.by_dates(period_begin, period_end)
                                 .order(occur_at: 'asc')
                             }

  scope :for_time_unconfirmed, ->(period_begin, period_end) {
                                 accompaniment_eligibile
                                   .confirmed.by_dates(period_begin, period_end)
                                   .order(occur_at: 'desc')
                               }

  def accompaniment_limit_met?
    !!activity_type &&
      !!activity_type.cap &&
      volunteer_accompaniments.count >= activity_type.cap
  end

  def start_time
    occur_at
  end

  User.roles.each do |role, _index|
    define_method "#{role}_accompaniments" do
      accompaniments.select do |accompaniment|
        accompaniment.user.role == role
      end
    end
  end

  def accompaniment_leader_accompaniments
    accompaniments.select do |accompaniment|
      accompaniment.user.role == 'accompaniment_leader'
    end
  end

  def volunteer_accompaniments
    accompaniments.select do |accompaniment|
      %w[volunteer data_entry].include? accompaniment.user.role
    end
  end

  def self.remaining_this_week?
    Activity.accompaniment_eligible
            .confirmed
            .where('occur_at >= ? AND occur_at <= ? ',
                   Time.now,
                   Date.today.end_of_week.end_of_day).present?
  end

  def self.between_dates(start_date, end_date)
    where('occur_at > ? AND occur_at < ?', start_date, end_date)
  end

  def accompaniment_eligible?
    activity_type.accompaniment_eligible
  end

  def combined_activity_parent?
    combined_activity_children.present?
  end

  def combined_activity_child?
    combined_activity_parent.present?
  end

  private

  def activity_combination_set
    if combined_activity_parent?
      [self] + combined_activity_children
    elsif combined_activity_child?
      [combined_activity_parent] + combined_activity_parent.combined_activity_children
    else
      []
    end
  end

  def activity_combination_parent
    if combined_activity_parent?
      self
    elsif combined_activity_child?
      combined_activity_parent
    end
  end

  def activity_combination_max_depth_of_one
    return unless combined_activity_child?
    if combined_activity_parent? || combined_activity_parent.combined_activity_child?
      errors.add(:combined_activity_parent, 'Activity combinations cannot be daisy-chained. There should be a single' \
                                            ' parent activity for a group of combined activities.')
      false
    end
  end

  def activity_combination_parent_must_be_earliest_activity
    combination = activity_combination_set
    return if combination.empty? || combination.length === 1
    earliest_activity = combination.sort(&:occur_at).first
    unless earliest_activity === activity_combination_parent
      errors.add(:combined_activity_parent, 'Activity combination parent must be earliest activity.')
      false
    end
  end
end
