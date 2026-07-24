class AuditLog < ApplicationRecord
  def readonly?
    persisted?
  end

  before_destroy { raise ActiveRecord::ReadOnlyRecord }

  belongs_to :user

  validates :action,      presence: true
  validates :entity_type, presence: true
  validates :entity_id,   presence: true

  scope :for_entity, ->(type, id) { where(entity_type: type, entity_id: id) }
  scope :for_user,   ->(user) { where(user: user) }
  scope :recent,     -> { order(created_at: :desc) }
end
