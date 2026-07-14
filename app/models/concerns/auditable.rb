# frozen_string_literal: true

# Mixin para modelos que precisam registrar trilha de auditoria.
# Inclua este concern e chame `log_audit(action)` nos pontos relevantes.
#
# O log só é gravado quando Current.user estiver definido (requisições autenticadas).
# Em jobs, seeds ou testes sem contexto de usuário, a chamada é silenciosamente ignorada.
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
