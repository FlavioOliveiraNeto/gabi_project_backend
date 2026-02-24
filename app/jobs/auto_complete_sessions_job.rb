class AutoCompleteSessionsJob
  include Sidekiq::Job

  def perform
    Rails.logger.info "⏰ Auto-completando sessões passadas..."
    Session.auto_complete_past_sessions!
    Rails.logger.info "✅ Sessões auto-completadas com sucesso!"
  end
end
