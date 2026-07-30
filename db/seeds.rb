if Rails.env.production? && ENV["SEED_ALLOW_PRODUCTION"] != "true"
  puts "⛔ Seed ignorado em produção. Use SEED_ALLOW_PRODUCTION=true para forçar."
  return
end

puts "🚀 Iniciando seed (idempotente)..."

SEED_PASSWORD = ENV.fetch("SEED_PASSWORD", "SenhaDeDesenvolvimento@123")

if ENV["SEED_RESET"] == "true"
  puts "🧹 SEED_RESET=true — apagando dados existentes..."
  ClinicalNote.delete_all
  PatientNote.delete_all
  Session.delete_all
  WeeklySchedule.delete_all
  RecurringSchedule.delete_all
  CalendarBlock.delete_all
  User.delete_all
end

WEEKS_PAST   = 4
WEEKS_FUTURE = 4

SEED_WEEKDAYS = %w[monday tuesday wednesday thursday friday].freeze

NOTES_PER_PATIENT = 2

therapist_email = ENV.fetch("SEED_THERAPIST_EMAIL", "terapeuta@example.com")

therapist = User.find_or_create_by!(email: therapist_email) do |u|
  u.name                  = "Gabriella"
  u.role                  = :therapist
  u.password              = SEED_PASSWORD
  u.password_confirmation = SEED_PASSWORD
end

puts "👩‍⚕️ Terapeuta: #{therapist.email}"

names = [
  "Ana Beatriz Oliveira",
  "Bruno Mendes",
  "Carlos Novo",
  "Daniela Souza",
  "Eduardo Lima",
  "Fernanda Alves",
  "Gustavo Rocha",
  "Helena Martins",
  "Igor Santana",
  "Juliana Castro",
  "Kleber Nunes",
  "Larissa Gomes",
  "Marcos Pereira"
]

weekday_numbers = WeeklySchedule.weekdays

created_patients = 0

names.each_with_index do |name, index|
  client = User.find_or_create_by!(email: "paciente#{index + 1}@email.com") do |u|
    u.name                  = name
    u.role                  = :client
    u.therapist             = therapist
    u.password              = SEED_PASSWORD
    u.password_confirmation = SEED_PASSWORD
    u.google_meet_link      = index.even? ? "https://meet.google.com/test-#{index}" : nil
    created_patients += 1
  end

  hour = 8 + index
  time = format("%02d:00", hour)

  weekdays = [ SEED_WEEKDAYS[index % SEED_WEEKDAYS.size] ]
  weekdays << SEED_WEEKDAYS[(index + 2) % SEED_WEEKDAYS.size] if index.even?

  weekdays.each do |weekday|
    client.weekly_schedules.find_or_create_by!(weekday: weekday) do |s|
      s.sessions_per_week = weekdays.size
      s.time              = time
      s.effective_from    = WEEKS_PAST.weeks.ago.to_date.beginning_of_week
    end
  end

  client.weekly_schedules.each do |schedule|
    weekday_number = weekday_numbers[schedule.weekday]

    upsert_session = lambda do |date, status|
      datetime = Time.zone.parse("#{date} #{schedule.time}")

      Session.find_or_create_by!(
        user:         client,
        scheduled_at: datetime,
        session_type: :recurring
      ) do |s|
        s.status     = status
        s.start_time = datetime
        s.end_time   = datetime + 50.minutes
      end
    end

    (1..WEEKS_PAST).each do |week|
      target_date = (Date.current - week.weeks).beginning_of_week + weekday_number
      next if target_date > Date.current

      status = ((index + week) % 7).zero? ? :absent : :completed
      upsert_session.call(target_date, status)
    end

    current_week_date = Date.current.beginning_of_week + weekday_number
    upsert_session.call(current_week_date, :scheduled) if current_week_date >= Date.current

    (1..WEEKS_FUTURE).each do |week|
      target_date = (Date.current + week.weeks).beginning_of_week + weekday_number
      upsert_session.call(target_date, :scheduled)
    end
  end

  client.sessions
        .where(status: :completed)
        .order(:start_time)
        .last(NOTES_PER_PATIENT)
        .each do |session|
    ClinicalNote.find_or_create_by!(session: session) do |note|
      note.user      = client
      note.therapist = therapist
      note.date      = session.start_time
      note.content   = "Paciente relatou progresso na última sessão."
    end
  end
end

puts "👤 Pacientes: #{User.clients.count} (#{created_patients} criados agora)"
puts "✅ Seed concluído!"
puts "👥 Total usuários: #{User.count}"
puts "📅 Total sessões: #{Session.count}"
puts "📝 Total notas clínicas: #{ClinicalNote.count}"
