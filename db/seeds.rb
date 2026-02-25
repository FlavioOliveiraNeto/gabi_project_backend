puts "🚀 Iniciando seed..."

# =========================
# LIMPEZA SEGURA (ORDEM IMPORTA)
# =========================

ClinicalNote.delete_all
PatientNote.delete_all
WeeklySchedule.delete_all
Session.delete_all
User.delete_all

puts "🧹 Banco limpo!"

# =========================
# CONFIGURAÇÕES
# =========================

WEEKS_PAST   = 4
WEEKS_FUTURE = 4

# =========================
# TERAPEUTA
# =========================

therapist = User.create!(
  name: "Gabriella",
  email: "gabrielafelixsilva@gmail.com",
  password: "salame123",
  password_confirmation: "salame123",
  role: :therapist
)

puts "👩‍⚕️ Terapeuta criada!"

# =========================
# PACIENTES
# =========================

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

names.each_with_index do |name, index|

  client = User.create!(
    name: name,
    email: "paciente#{index + 1}@email.com",
    password: "password123",
    password_confirmation: "password123",
    role: :client,
    therapist: therapist,
    google_meet_link: index.even? ? "https://meet.google.com/test-#{index}" : nil
  )

  puts "👤 Paciente criado: #{client.name}"

  # Define 1 ou 2 dias fixos — hora sequencial por paciente para evitar conflitos
  weekdays = WeeklySchedule.weekdays.keys.sample(rand(1..2))
  hour     = 8 + index
  time     = format("%02d:00", hour)

  # =========================
  # CRIA AGENDA FIXA
  # =========================

  weekdays.each do |weekday|
    client.weekly_schedules.create!(
      weekday: weekday,
      sessions_per_week: weekdays.size,
      time: time
    )
  end

  # =========================
  # GERA SESSÕES SEM DUPLICAR
  # =========================

  client.weekly_schedules.each do |schedule|
    weekday_number = weekday_numbers[schedule.weekday]

    generate_session = lambda do |date, status|
      datetime = Time.zone.parse("#{date} #{schedule.time}")

      Session.find_or_create_by!(
        user: client,
        scheduled_at: datetime,
        session_type: :regular
      ) do |s|
        s.status = status
      end
    end

    # PASSADO
    (1..WEEKS_PAST).each do |w|
      date = Date.today - w.weeks
      target_date = date.beginning_of_week + weekday_number
      next if target_date > Date.today

      status = rand < 0.85 ? :completed : :absent
      generate_session.call(target_date, status)
    end

    # SEMANA ATUAL
    current_week_date = Date.today.beginning_of_week + weekday_number
    if current_week_date >= Date.today
      generate_session.call(current_week_date, :scheduled)
    end

    # FUTURO
    (1..WEEKS_FUTURE).each do |w|
      date = Date.today + w.weeks
      target_date = date.beginning_of_week + weekday_number
      generate_session.call(target_date, :scheduled)
    end
  end

  # =========================
  # NOTAS CLÍNICAS
  # =========================

  rand(1..3).times do
    ClinicalNote.create!(
      user: client,
      therapist: therapist,
      date: rand(1..20).days.ago,
      content: "Paciente relatou progresso na última sessão."
    )
  end
end

puts "✅ Seed concluído com sucesso!"
puts "👥 Total usuários: #{User.count}"
puts "📅 Total sessões: #{Session.count}"
puts "📝 Total notas clínicas: #{ClinicalNote.count}"