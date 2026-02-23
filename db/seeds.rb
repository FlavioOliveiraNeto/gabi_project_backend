puts "Iniciando seed..."

ClinicalNote.destroy_all
WeeklySchedule.destroy_all
PatientNote.destroy_all
Session.destroy_all
User.destroy_all

puts "Banco limpo!"

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

puts "Terapeuta criada!"

# =========================
# CONFIGURAÇÕES
# =========================

WEEKS_PAST = 4
WEEKS_FUTURE = 4

weekday_numbers = WeeklySchedule.weekdays

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

# =========================
# CRIAÇÃO DE PACIENTES
# =========================

names.each_with_index do |name, index|
  client = User.create!(
    name: name,
    email: "paciente#{index + 1}@email.com",
    password: "password123",
    password_confirmation: "password123",
    role: :client,
    google_meet_link: index.even? ? "https://meet.google.com/test-#{index}" : nil,
    therapist: therapist
  )

  puts "Paciente criado: #{client.name}"

  # Define dias aleatórios da semana
  weekdays = WeeklySchedule.weekdays.keys.sample(rand(1..2))
  time = "#{rand(8..19)}:00"

  weekdays.each do |weekday|
    client.weekly_schedules.create!(
      weekday: weekday,
      sessions_per_week: weekdays.size,
      time: time
    )
  end

  # =========================
  # GERA SESSÕES BASEADAS NA AGENDA
  # =========================

  schedules = client.weekly_schedules

  schedules.each do |schedule|
    weekday_number = weekday_numbers[schedule.weekday]

    # PASSADO
    (1..WEEKS_PAST).each do |w|
      date = Date.today - w.weeks
      target_date = date.beginning_of_week + weekday_number

      next if target_date > Date.today

      status = rand < 0.85 ? :completed : :absent

      Session.create!(
        user: client,
        scheduled_at: Time.zone.parse("#{target_date} #{schedule.time}"),
        status: status
      )
    end

    # SEMANA ATUAL
    current_week_date = Date.today.beginning_of_week + weekday_number
    if current_week_date >= Date.today
      Session.create!(
        user: client,
        scheduled_at: Time.zone.parse("#{current_week_date} #{schedule.time}"),
        status: :scheduled
      )
    end

    # FUTURO
    (1..WEEKS_FUTURE).each do |w|
      date = Date.today + w.weeks
      target_date = date.beginning_of_week + weekday_number

      Session.create!(
        user: client,
        scheduled_at: Time.zone.parse("#{target_date} #{schedule.time}"),
        status: :scheduled
      )
    end
  end

  # =========================
  # NOTAS CLÍNICAS
  # =========================

  rand(1..3).times do
    ClinicalNote.create!(
      user: client,
      date: rand(1..20).days.ago,
      content: "Paciente relatou progresso na última sessão."
    )
  end
end

puts "Seed profissional concluído!"
puts "Total de sessões criadas: #{Session.count}"