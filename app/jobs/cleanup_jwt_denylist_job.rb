class CleanupJwtDenylistJob < ApplicationJob
  queue_as :default

  def perform
    deleted_count = JwtDenylist.where("exp < ?", Time.current).delete_all
    Rails.logger.info "✅ JWT denylist limpo: #{deleted_count} entradas expiradas removidas."
  end
end
