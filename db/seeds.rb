puts "Iniciando o seed do banco de dados..."

ClinicalNote.destroy_all
WeeklySchedule.destroy_all
PatientNote.destroy_all
Session.destroy_all
User.destroy_all

puts "Banco limpo!"

# Cria a terapeuta
therapist = User.create!(
  name: 'Gabriella',
  email: 'gabrielafelixsilva@gmail.com',
  password: 'salame123',
  password_confirmation: 'salame123',
  role: :therapist
)

puts "Terapeuta criada: #{therapist.email} (Senha: salame123)"

clients_data = [
  {
    name: 'Ana Beatriz Oliveira',
    email: 'ana.cliente@email.com',
    password: 'password123',
    google_meet_link: 'https://meet.google.com/abc-defg-hij',
    weekdays: %w[monday wednesday friday],
    sessions_per_week: 3
  },
  {
    name: 'Bruno Mendes',
    email: 'bruno.cliente@email.com',
    password: 'password123',
    google_meet_link: 'https://meet.google.com/xyz-wvu-tsr',
    weekdays: %w[tuesday thursday],
    sessions_per_week: 2
  },
  {
    name: 'Carlos Novo',
    email: 'carlos.novo@email.com',
    password: 'password123',
    google_meet_link: nil,
    weekdays: %w[monday],
    sessions_per_week: 1
  },{
    name: 'Daniela Souza',
    email: 'daniela.souza@email.com',
    password: 'password123',
    google_meet_link: 'https://meet.google.com/dan-iela-123',
    weekdays: %w[monday],
    sessions_per_week: 1,
    time: '11:00'
  },
  {
    name: 'Eduardo Lima',
    email: 'eduardo.lima@email.com',
    password: 'password123',
    google_meet_link: nil,
    weekdays: %w[tuesday],
    sessions_per_week: 1,
    time: '14:00'
  },
  {
    name: 'Fernanda Alves',
    email: 'fernanda.alves@email.com',
    password: 'password123',
    google_meet_link: 'https://meet.google.com/fer-nan-da22',
    weekdays: %w[wednesday],
    sessions_per_week: 1,
    time: '15:00'
  },
  {
    name: 'Gustavo Rocha',
    email: 'gustavo.rocha@email.com',
    password: 'password123',
    google_meet_link: nil,
    weekdays: %w[thursday],
    sessions_per_week: 1,
    time: '16:00'
  },
  {
    name: 'Helena Martins',
    email: 'helena.martins@email.com',
    password: 'password123',
    google_meet_link: 'https://meet.google.com/hel-ena-987',
    weekdays: %w[friday],
    sessions_per_week: 1,
    time: '17:00'
  },
  {
    name: 'Igor Santana',
    email: 'igor.santana@email.com',
    password: 'password123',
    google_meet_link: nil,
    weekdays: %w[monday],
    sessions_per_week: 1,
    time: '18:00'
  },
  {
    name: 'Juliana Castro',
    email: 'juliana.castro@email.com',
    password: 'password123',
    google_meet_link: 'https://meet.google.com/jul-cas-456',
    weekdays: %w[tuesday],
    sessions_per_week: 1,
    time: '19:00'
  },
  {
    name: 'Kleber Nunes',
    email: 'kleber.nunes@email.com',
    password: 'password123',
    google_meet_link: nil,
    weekdays: %w[wednesday],
    sessions_per_week: 1,
    time: '20:00'
  },
  {
    name: 'Larissa Gomes',
    email: 'larissa.gomes@email.com',
    password: 'password123',
    google_meet_link: 'https://meet.google.com/lar-gom-321',
    weekdays: %w[thursday],
    sessions_per_week: 1,
    time: '09:00'
  },
  {
    name: 'Marcos Pereira',
    email: 'marcos.pereira@email.com',
    password: 'password123',
    google_meet_link: nil,
    weekdays: %w[friday],
    sessions_per_week: 1,
    time: '08:00'
  }
]

clients_data.each do |data|
  client = User.create!(
    name: data[:name],
    email: data[:email],
    password: data[:password],
    password_confirmation: data[:password],
    role: :client,
    google_meet_link: data[:google_meet_link],
    therapist: therapist
  )

  puts "Paciente criado: #{client.email}"

  data[:weekdays].each do |weekday|
    client.weekly_schedules.create!(
      weekday: weekday,
      sessions_per_week: data[:sessions_per_week],
      time: data[:time] || '10:00'
    )
  end

  # Sessões de exemplo
  3.times do |i|
    Session.create!(
      user: client,
      scheduled_at: (i + 1).weeks.ago,
      status: i == 2 ? :absent : :completed
    )
  end

  if client.google_meet_link.present?
    ClinicalNote.create!(
      user: client,
      date: 1.week.ago,
      content: "Sessão inicial. Paciente relatou ansiedade leve. Definimos objetivos iniciais."
    )
    ClinicalNote.create!(
      user: client,
      date: Time.current,
      content: "Segunda sessão. Evolução positiva. Discutimos rotina de sono."
    )
    puts "   2 notas adicionadas para #{client.email}"
  end
end

puts "Seed concluído com sucesso!"
