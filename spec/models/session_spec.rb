require 'rails_helper'

RSpec.describe Session, type: :model do
  let(:therapist) { create(:user, :therapist) }
  let(:patient)   { create(:user, :client, therapist: therapist) }

  # Associações
  describe "associações" do
    it { is_expected.to belong_to(:user) }
  end

  # Enums
  describe "enums" do
    it do
      is_expected.to define_enum_for(:status)
        .with_values(scheduled: 0, completed: 1, absent: 2, cancelled: 3)
    end

    it do
      is_expected.to define_enum_for(:session_type)
        .with_values(regular: 0, extra: 1)
    end
  end

  # Validações básicas
  describe "validações" do
    it "é válido com dados corretos" do
      expect(build(:session, user: patient)).to be_valid
    end

    it { is_expected.to validate_presence_of(:scheduled_at) }
  end

  # Unicidade por índice DB 
  describe "constraint de unicidade (user_id, scheduled_at, session_type)" do
    let(:time) { 3.days.from_now.noon }

    it "impede duplicatas com mesmo user, scheduled_at e session_type" do
      create(:session, user: patient, scheduled_at: time, session_type: :regular)

      duplicate = build(:session, user: patient, scheduled_at: time, session_type: :regular)
      expect { duplicate.save! }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it "é inválido por conflito de horário quando session_type difere mas o horário é o mesmo" do
      create(:session, user: patient, scheduled_at: time, session_type: :regular)

      # O índice DB (user_id, scheduled_at, session_type) permitiria tipos distintos,
      # mas no_schedule_conflict rejeita 0 minutos de diferença antes de atingir o índice.
      extra = build(:session, user: patient, scheduled_at: time, session_type: :extra)
      expect(extra).not_to be_valid
      expect(extra.errors[:scheduled_at]).to be_present
    end
  end

  # Validação de conflito de horário
  describe "validação no_schedule_conflict" do
    let(:patient_b) { create(:user, :client, therapist: therapist) }
    let(:base_time) { 3.days.from_now.noon }

    context "quando outro paciente do mesmo terapeuta tem sessão em menos de 1h" do
      before { create(:session, user: patient_b, scheduled_at: base_time, status: :scheduled) }

      it "é inválido com diferença de +30 minutos" do
        conflicting = build(:session, user: patient, scheduled_at: base_time + 30.minutes)
        expect(conflicting).not_to be_valid
        expect(conflicting.errors[:scheduled_at]).to be_present
      end

      it "é inválido com diferença de +59 minutos" do
        conflicting = build(:session, user: patient, scheduled_at: base_time + 59.minutes)
        expect(conflicting).not_to be_valid
      end

      it "é inválido com diferença de +1 segundo" do
        conflicting = build(:session, user: patient, scheduled_at: base_time + 1.second)
        expect(conflicting).not_to be_valid
      end

      it "é inválido com diferença de -30 minutos" do
        conflicting = build(:session, user: patient, scheduled_at: base_time - 30.minutes)
        expect(conflicting).not_to be_valid
        expect(conflicting.errors[:scheduled_at]).to be_present
      end
    end

    context "quando as sessões têm exatamente +1 hora de diferença" do
      before { create(:session, user: patient_b, scheduled_at: base_time, status: :scheduled) }

      it "é válido pois o intervalo mínimo é exclusivo" do
        non_conflicting = build(:session, user: patient, scheduled_at: base_time + 1.hour)
        expect(non_conflicting).to be_valid
      end
    end

    context "quando as sessões têm exatamente -1 hora de diferença" do
      before { create(:session, user: patient_b, scheduled_at: base_time, status: :scheduled) }

      it "é válido pois o limite inferior também é exclusivo" do
        non_conflicting = build(:session, user: patient, scheduled_at: base_time - 1.hour)
        expect(non_conflicting).to be_valid
      end
    end

    context "quando a sessão conflitante é de outro terapeuta" do
      let(:other_therapist) { create(:user, :therapist) }
      let(:other_patient)   { create(:user, :client, therapist: other_therapist) }

      before { create(:session, user: other_patient, scheduled_at: base_time, status: :scheduled) }

      it "é válido — conflito só ocorre dentro do mesmo terapeuta" do
        session = build(:session, user: patient, scheduled_at: base_time)
        expect(session).to be_valid
      end
    end

    context "quando a sessão conflitante está com status diferente de scheduled" do
      before { create(:session, user: patient_b, scheduled_at: base_time, status: :completed) }

      it "é válido — só verifica sessões :scheduled" do
        session = build(:session, user: patient, scheduled_at: base_time + 30.minutes)
        expect(session).to be_valid
      end
    end

    context "quando o paciente não tem terapeuta" do
      let(:patient_without_therapist) { create(:user, :client, therapist: nil) }

      it "é válido sem verificar conflito" do
        expect(build(:session, user: patient_without_therapist)).to be_valid
      end
    end

    context "ao atualizar uma sessão existente" do
      let!(:existing) do
        create(:session, user: patient, scheduled_at: base_time, status: :scheduled)
      end

      it "não conflita consigo mesma" do
        existing.status = :absent
        expect(existing).to be_valid
      end
    end
  end

  # .auto_complete_past_sessions!
  describe ".auto_complete_past_sessions!" do
    context "sessões mais de 1 hora no passado" do
      let!(:overdue) do
        create(:session, user: patient, scheduled_at: 90.minutes.ago, status: :scheduled)
      end

      it "marca como completed" do
        expect { Session.auto_complete_past_sessions! }
          .to change { overdue.reload.status }
          .from("scheduled").to("completed")
      end
    end

    context "sessões no limite exato de 1 hora no passado" do
      let!(:session) do
        create(:session, user: patient, scheduled_at: 1.hour.ago, status: :scheduled)
      end

      it "marca como completed" do
        expect { Session.auto_complete_past_sessions! }
          .to change { session.reload.status }
          .from("scheduled").to("completed")
      end
    end

    context "sessões com menos de 1 hora no passado" do
      let!(:recent) do
        create(:session, user: patient, scheduled_at: 30.minutes.ago, status: :scheduled)
      end

      it "não altera o status" do
        expect { Session.auto_complete_past_sessions! }
          .not_to change { recent.reload.status }
      end
    end

    context "sessões no futuro" do
      let!(:future_session) do
        create(:session, user: patient, scheduled_at: 1.day.from_now, status: :scheduled)
      end

      it "não altera o status" do
        expect { Session.auto_complete_past_sessions! }
          .not_to change { future_session.reload.status }
      end
    end

    context "sessões já com status diferente de scheduled" do
      let!(:completed_past) do
        create(:session, user: patient, scheduled_at: 2.hours.ago, status: :completed)
      end
      let!(:absent_past) do
        create(:session, user: patient, scheduled_at: 3.hours.ago, status: :absent)
      end
      let!(:cancelled_past) do
        create(:session, user: patient, scheduled_at: 4.hours.ago, status: :cancelled)
      end

      it "não altera sessões completed" do
        Session.auto_complete_past_sessions!
        expect(completed_past.reload.status).to eq("completed")
      end

      it "não altera sessões absent" do
        Session.auto_complete_past_sessions!
        expect(absent_past.reload.status).to eq("absent")
      end

      it "não altera sessões cancelled" do
        Session.auto_complete_past_sessions!
        expect(cancelled_past.reload.status).to eq("cancelled")
      end
    end

    context "idempotência" do
      let!(:session) do
        create(:session, user: patient, scheduled_at: 2.hours.ago, status: :scheduled)
      end

      it "é seguro de executar múltiplas vezes" do
        2.times { Session.auto_complete_past_sessions! }
        expect(session.reload.status).to eq("completed")
      end
    end

    context "múltiplas sessões elegíveis" do
      let(:patient_b) { create(:user, :client, therapist: therapist) }
      let!(:s1) { create(:session, user: patient,   scheduled_at: 2.hours.ago, status: :scheduled) }
      let!(:s2) { create(:session, user: patient_b, scheduled_at: 4.hours.ago, status: :scheduled) }

      before { Session.auto_complete_past_sessions! }

      it "completa a sessão do primeiro paciente" do
        expect(s1.reload.status).to eq("completed")
      end

      it "completa a sessão do segundo paciente" do
        expect(s2.reload.status).to eq("completed")
      end
    end
  end
end
