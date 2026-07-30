namespace :jobs do
  desc "Verifica se o supervisor do SolidQueue está ativo e se os jobs recorrentes rodaram"
  task health: :environment do
    stale_after = 5.minutes

    processes = SolidQueue::Process.all.to_a
    alive     = processes.select { |p| p.last_heartbeat_at && p.last_heartbeat_at > stale_after.ago }

    puts "── SolidQueue ────────────────────────────────────────────"
    puts "Ambiente          : #{Rails.env}"
    puts "Adapter ActiveJob : #{Rails.application.config.active_job.queue_adapter.inspect}"
    puts "SOLID_QUEUE_IN_PUMA: #{ENV['SOLID_QUEUE_IN_PUMA'].inspect}"
    puts

    puts "Processos registrados : #{processes.size}"
    puts "Processos vivos       : #{alive.size}"
    processes.each do |p|
      age = p.last_heartbeat_at ? "#{(Time.current - p.last_heartbeat_at).to_i}s atrás" : "nunca"
      puts "  - #{p.kind.ljust(11)} pid=#{p.pid} host=#{p.hostname} heartbeat=#{age}"
    end

    if alive.none? { |p| p.kind == "Scheduler" }
      puts
      puts "⚠️  NENHUM Scheduler vivo — os jobs recorrentes do config/recurring.yml"
      puts "    NÃO estão sendo enfileirados."
    end

    puts
    puts "── Tarefas recorrentes registradas ───────────────────────"
    tasks = SolidQueue::RecurringTask.order(:key).to_a
    if tasks.empty?
      puts "  (nenhuma — o Scheduler nunca subiu neste banco)"
    else
      tasks.each { |t| puts "  - #{t.key.ljust(32)} #{t.schedule.ljust(12)} #{t.class_name || t.command}" }
    end

    puts
    puts "── Últimas execuções recorrentes ─────────────────────────"
    executions = SolidQueue::RecurringExecution.order(run_at: :desc).limit(10).to_a
    if executions.empty?
      puts "  (nenhuma execução registrada)"
    else
      executions.each { |e| puts "  - #{e.task_key.ljust(32)} #{e.run_at}" }
    end

    puts
    puts "── Fila ──────────────────────────────────────────────────"
    puts "Jobs pendentes  : #{SolidQueue::Job.where(finished_at: nil).count}"
    puts "Prontos p/ rodar: #{SolidQueue::ReadyExecution.count}"
    puts "Agendados       : #{SolidQueue::ScheduledExecution.count}"
    puts "Falhos          : #{SolidQueue::FailedExecution.count}"

    SolidQueue::FailedExecution.order(created_at: :desc).limit(3).each do |failure|
      puts "  ! #{failure.job&.class_name}: #{failure.error.to_s.lines.first&.strip}"
    end

    puts
    puts "── Evidência no domínio ──────────────────────────────────"

    overdue = Session.where(status: :scheduled).where(start_time: ...1.hour.ago).count
    puts "Sessões passadas ainda 'scheduled' : #{overdue}"
    puts "  (esperado 0 — AutoCompleteSessionsJob roda a cada hora)" if overdue.positive?

    expired_tokens = JwtDenylist.where(exp: ...Time.current).count
    puts "Tokens expirados na denylist       : #{expired_tokens}"
    puts "  (esperado ~0 — CleanupJwtDenylistJob roda às 3h)" if expired_tokens.positive?

    future = Session.where(status: :scheduled).where(start_time: Time.current..).count
    puts "Sessões futuras agendadas          : #{future}"
    puts "  (0 pode indicar WeeklySessionGenerationJob parado)" if future.zero?

    puts
    healthy = alive.any? { |p| p.kind == "Scheduler" } && overdue.zero?
    puts healthy ? "✅ Jobs aparentam estar saudáveis." : "❌ Jobs NÃO estão funcionando corretamente."
  end
end
