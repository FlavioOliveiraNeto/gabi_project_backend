module Auditable
  extend ActiveSupport::Concern

  private

  def log_audit(action, metadata = {})
    return unless Current.user.present?

    AuditLog.create!(
      user:        Current.user,
      action:      action,
      entity_type: self.class.name,
      entity_id:   id,
      metadata:    metadata
    )
  end
end
