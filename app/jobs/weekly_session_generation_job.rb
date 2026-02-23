class WeeklySessionGenerationJob
  include Sidekiq::Job

  def perform
    Rails.logger.info "⏰ Gerando sessões semanais..."

    User.where(role: :therapist).find_each do |therapist|
      SessionGeneratorService.new(therapist).generate_for_next_month
    end

    Rails.logger.info "✅ Sessões geradas com sucesso!"
  end
end