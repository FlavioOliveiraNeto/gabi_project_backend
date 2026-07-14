require "rails_helper"

RSpec.describe AutoCompleteSessionsJob, type: :job do
  let(:therapist) { create(:user, :therapist) }
  let(:patient)   { create(:user, :client, therapist: therapist) }

  # .queue_name
  describe ".queue_name" do
    it "usa a fila :default" do
      expect(described_class.queue_name).to eq("default")
    end
  end

  # #perform
  describe "#perform" do
    it "delega para Session.auto_complete_past_sessions!" do
      expect(Session).to receive(:auto_complete_past_sessions!).once
      described_class.new.perform
    end

    context "sessões elegíveis (scheduled + >= 1 hora atrás)" do
      context "mais de 1 hora no passado" do
        let!(:overdue_session) do
          create(:session, user: patient, status: :scheduled, scheduled_at: 90.minutes.ago)
        end

        it "marca como completed" do
          described_class.new.perform
          expect(overdue_session.reload.status).to eq("completed")
        end
      end

      context "exatamente 1 hora no passado" do
        let!(:limit_session) do
          create(:session, user: patient, status: :scheduled, scheduled_at: 1.hour.ago)
        end

        it "marca como completed (condição <= inclui o limite)" do
          described_class.new.perform
          expect(limit_session.reload.status).to eq("completed")
        end
      end

      context "múltiplas sessões de múltiplos pacientes" do
        let(:patient_b) { create(:user, :client, therapist: therapist) }
        let!(:s1) { create(:session, user: patient,   status: :scheduled, scheduled_at: 2.hours.ago) }
        let!(:s2) { create(:session, user: patient_b, status: :scheduled, scheduled_at: 4.hours.ago) }
        let!(:s3) { create(:session, user: patient,   status: :scheduled, scheduled_at: 30.minutes.ago) }

        before { described_class.new.perform }

        it "completa sessões elegíveis de patient" do
          expect(s1.reload.status).to eq("completed")
        end

        it "completa sessões elegíveis de patient_b" do
          expect(s2.reload.status).to eq("completed")
        end

        it "não altera sessão recente (< 1 hora)" do
          expect(s3.reload.status).to eq("scheduled")
        end
      end
    end

    context "sessões não elegíveis" do
      context "menos de 1 hora no passado" do
        let!(:recent_session) do
          create(:session, user: patient, status: :scheduled, scheduled_at: 30.minutes.ago)
        end

        it "não altera o status" do
          described_class.new.perform
          expect(recent_session.reload.status).to eq("scheduled")
        end
      end

      context "no futuro" do
        let!(:future_session) do
          create(:session, user: patient, status: :scheduled, scheduled_at: 1.day.from_now)
        end

        it "não altera o status" do
          described_class.new.perform
          expect(future_session.reload.status).to eq("scheduled")
        end
      end

      context "já com status diferente de scheduled" do
        let!(:absent_session)    { create(:session, user: patient, status: :absent,    scheduled_at: 2.hours.ago) }
        let!(:cancelled_session) { create(:session, user: patient, status: :cancelled, scheduled_at: 2.hours.ago) }
        let!(:completed_session) { create(:session, user: patient, status: :completed, scheduled_at: 2.hours.ago) }

        it "não altera sessões absent" do
          described_class.new.perform
          expect(absent_session.reload.status).to eq("absent")
        end

        it "não altera sessões cancelled" do
          described_class.new.perform
          expect(cancelled_session.reload.status).to eq("cancelled")
        end

        it "não altera sessões completed" do
          described_class.new.perform
          expect(completed_session.reload.status).to eq("completed")
        end
      end
    end

    context "idempotência" do
      let!(:session) { create(:session, user: patient, status: :scheduled, scheduled_at: 2.hours.ago) }

      before { 2.times { described_class.new.perform } }

      it "é seguro de executar múltiplas vezes sem efeito colateral" do
        expect(session.reload.status).to eq("completed")
        expect(Session.where(status: :completed).count).to eq(1)
      end
    end
  end
end
