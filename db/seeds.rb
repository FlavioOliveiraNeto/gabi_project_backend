puts "Iniciando o seed do banco de dados..."

# Limpeza de notas para não dar erro de foreign key
ClinicalNote.destroy_all
User.destroy_all

puts "Banco limpo!"

# Cria uma terapeuta (Admin)
admin = User.create!(
  name: 'Gabriella',
  email: 'gabrielafelixsilva@gmail.com',
  password: 'salame123',
  password_confirmation: 'salame123',
  role: :admin,
  confirmed_at: Time.current
)

puts "Terapeuta criada: #{admin.email} (Senha: salame123)"

# Cria alguns pacientes
clients_data = [
  {
    name: 'Ana',
    email: 'ana.cliente@email.com',
    password: 'password123',
    sessions_count: 5,
    google_meet_link: 'https://meet.google.com/abc-defg-hij'
  },
  {
    name: 'Bruno',
    email: 'bruno.cliente@email.com',
    password: 'password123',
    sessions_count: 12,
    google_meet_link: 'https://meet.google.com/xyz-wvu-tsr'
  },
  {
    name: 'Carlos',
    email: 'carlos.novo@email.com',
    password: 'password123',
    sessions_count: 0,
    google_meet_link: nil
  }
]

clients_data.each do |data|
  client = User.create!(
    name: data[:name],
    email: data[:email],
    password: data[:password],
    password_confirmation: data[:password],
    role: :client,
    sessions_count: data[:sessions_count],
    google_meet_link: data[:google_meet_link],
    confirmed_at: Time.current
  )
  
  puts "Cliente criado: #{client.email}"

  # Adiciona anotações para alguns clientes
  if client.sessions_count > 0
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