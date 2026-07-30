require 'rails_helper'

RSpec.describe "db/seeds.rb", type: :model do
  def load_seeds
    Rails.application.load_seed
  end

  around do |example|
    original = $stdout
    $stdout = StringIO.new
    begin
      example.run
    ensure
      $stdout = original
    end
  end

  it "roda sem levantar erro" do
    expect { load_seeds }.not_to raise_error
  end

  context "depois de rodar" do
    before { load_seeds }

    it "cria exatamente uma terapeuta" do
      expect(User.where(role: :therapist).count).to eq(1)
    end

    it "cria pacientes vinculados à terapeuta" do
      therapist = User.find_by(role: :therapist)

      expect(User.where(role: :client).count).to be > 0
      expect(User.where(role: :client).pluck(:therapist_id).uniq).to eq([ therapist.id ])
    end

    it "não usa o e-mail real da terapeuta" do
      expect(User.pluck(:email)).to all(match(/example\.com|@email\.com/))
    end

    it "cria sessões" do
      expect(Session.count).to be > 0
    end

    it "preenche start_time e end_time em todas as sessões" do
      expect(Session.where(start_time: nil).count).to eq(0)
      expect(Session.where(end_time: nil).count).to eq(0)
    end

    it "mantém scheduled_at consistente com start_time" do
      inconsistent = Session.where.not(scheduled_at: nil)
                            .reject { |s| s.scheduled_at == s.start_time }

      expect(inconsistent).to be_empty
    end

    it "desnormaliza therapist_id nas sessões" do
      expect(Session.where(therapist_id: nil).count).to eq(0)
    end

    it "cria notas clínicas, todas ligadas a uma sessão" do
      expect(ClinicalNote.count).to be > 0
      expect(ClinicalNote.where(session_id: nil).count).to eq(0)
    end

    it "associa cada nota clínica ao paciente da própria sessão" do
      mismatched = ClinicalNote.includes(:session).reject { |n| n.session.user_id == n.user_id }

      expect(mismatched).to be_empty
    end

    it "não gera conflito de slot para a terapeuta" do
      conflicts = Session.where(status: :scheduled)
                         .group(:therapist_id, :start_time)
                         .having("COUNT(*) > 1")
                         .count

      expect(conflicts).to be_empty
    end

    it "cria as senhas respeitando a política mínima de 12 caracteres" do
      expect(Devise.password_length.first).to be >= 12
    end

    it "deixa as senhas dos usuários utilizáveis para login" do
      seed_password = "SenhaDeDesenvolvimento@123"

      expect(User.find_by(role: :therapist).valid_password?(seed_password)).to be true
    end
  end

  describe "idempotência" do
    it "não cria nada de novo na segunda execução" do
      load_seeds

      counts = -> { [ User.count, Session.count, ClinicalNote.count, WeeklySchedule.count ] }
      before = counts.call

      load_seeds

      expect(counts.call).to eq(before)
    end

    it "continua estável na terceira execução" do
      load_seeds
      load_seeds
      before = [ User.count, Session.count, ClinicalNote.count ]

      load_seeds

      expect([ User.count, Session.count, ClinicalNote.count ]).to eq(before)
    end

    it "não duplica agenda semanal" do
      load_seeds
      load_seeds

      duplicated = WeeklySchedule.group(:user_id, :weekday).having("COUNT(*) > 1").count

      expect(duplicated).to be_empty
    end

    it "não apaga registros preexistentes" do
      therapist = create(:user, :therapist)
      outsider  = create(:user, :client, therapist: therapist, email: "preexistente@clinica.com")
      slot      = Time.zone.parse("#{Date.current + 120} 21:00")
      session   = create(:session, user: outsider, scheduled_at: slot,
                         start_time: slot, end_time: slot + 50.minutes)
      note      = create(:clinical_note, user: outsider, therapist: therapist,
                         session: session, content: "PRONTUÁRIO PREEXISTENTE")

      load_seeds

      expect(User.exists?(outsider.id)).to be true
      expect(Session.exists?(session.id)).to be true
      expect(ClinicalNote.find(note.id).content).to eq("PRONTUÁRIO PREEXISTENTE")
    end

    it "não sobrescreve a senha de um usuário existente" do
      load_seeds
      therapist = User.find_by(role: :therapist)
      therapist.update!(password: "SenhaTrocada@2026", password_confirmation: "SenhaTrocada@2026")

      load_seeds

      expect(therapist.reload.valid_password?("SenhaTrocada@2026")).to be true
    end

    it "é determinístico: mesma agenda em execuções independentes" do
      load_seeds
      first = WeeklySchedule.order(:user_id, :weekday).pluck(:user_id, :weekday, :time)

      ClinicalNote.delete_all
      Session.delete_all
      WeeklySchedule.delete_all
      User.delete_all
      load_seeds

      second = WeeklySchedule.order(:user_id, :weekday).pluck(:user_id, :weekday, :time)

      expect(second.map { |r| r[1..] }).to eq(first.map { |r| r[1..] })
    end
  end

  describe "SEED_RESET" do
    it "apaga os dados quando explicitamente pedido" do
      load_seeds
      outsider = create(:user, :client, email: "sera-apagado@clinica.com",
                        therapist: User.find_by(role: :therapist))

      stub_const("ENV", ENV.to_h.merge("SEED_RESET" => "true"))
      load_seeds

      expect(User.exists?(outsider.id)).to be false
    end

    it "repopula depois de apagar" do
      load_seeds
      stub_const("ENV", ENV.to_h.merge("SEED_RESET" => "true"))

      load_seeds

      expect(User.clients.count).to eq(13)
      expect(Session.count).to be > 0
    end

    it "não apaga nada por padrão" do
      load_seeds
      therapist = create(:user, :therapist, email: "sobrevivente@clinica.com")

      load_seeds

      expect(User.exists?(therapist.id)).to be true
    end
  end

  context "em produção" do
    it "não faz nada sem SEED_ALLOW_PRODUCTION" do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production"))

      expect { load_seeds }.not_to change(User, :count)
    end
  end
end
