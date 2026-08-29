class WeeklySessionGenerationJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "⏰ Gerando sessões semanais para mês atual e próximo..."

    conflicts = []

    User.where(role: :therapist).find_each do |therapist|
      generator = SessionGeneratorService.new(therapist)
      generator.generate_for_current_and_next_month
      conflicts.concat(generator.conflicts)
    end

    if conflicts.any?
      Rails.logger.warn "⚠️ #{conflicts.size} slot(s) em conflito não gerados: #{conflicts.to_json}"
    end

    Rails.logger.info "✅ Sessões geradas com sucesso!"
  end
end
