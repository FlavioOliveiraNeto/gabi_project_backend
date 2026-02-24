class WeeklySessionGenerationJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "⏰ Gerando sessões semanais para mês atual e próximo..."

    User.where(role: :therapist).find_each do |therapist|
      SessionGeneratorService.new(therapist).generate_for_current_and_next_month
    end

    Rails.logger.info "✅ Sessões geradas com sucesso!"
  end
end