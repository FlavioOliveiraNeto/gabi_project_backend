require 'rails_helper'

RSpec.describe AutoCompleteSessionsJob, type: :job do
  let(:therapist) { create(:user, :therapist) }
  let(:patient)   { create(:user, :client, therapist: therapist) }

  describe "#perform" do
    context "sessões mais de 1 hora no passado" do
      let!(:overdue_session) do
        create(:session, user: patient, status: :scheduled, scheduled_at: 90.minutes.ago)
      end

      it "marca como completed" do
        described_class.new.perform
        expect(overdue_session.reload.status).to eq("completed")
      end
    end

    context "sessões no limite exato de 1 hora" do
      let!(:limit_session) do
        create(:session, user: patient, status: :scheduled, scheduled_at: 1.hour.ago)
      end

      it "marca como completed (condição <=)" do
        described_class.new.perform
        expect(limit_session.reload.status).to eq("completed")
      end
    end

    context "sessões com menos de 1 hora no passado" do
      let!(:recent_session) do
        create(:session, user: patient, status: :scheduled, scheduled_at: 30.minutes.ago)
      end

      it "não altera o status" do
        described_class.new.perform
        expect(recent_session.reload.status).to eq("scheduled")
      end
    end

    context "sessões no futuro" do
      let!(:future_session) do
        create(:session, user: patient, status: :scheduled, scheduled_at: 1.day.from_now)
      end

      it "não altera o status" do
        described_class.new.perform
        expect(future_session.reload.status).to eq("scheduled")
      end
    end

    context "sessões já com outro status" do
      let!(:absent_session)    { create(:session, user: patient, status: :absent,    scheduled_at: 2.hours.ago) }
      let!(:cancelled_session) { create(:session, user: patient, status: :cancelled, scheduled_at: 2.hours.ago) }

      it "não altera sessões absent" do
        described_class.new.perform
        expect(absent_session.reload.status).to eq("absent")
      end

      it "não altera sessões cancelled" do
        described_class.new.perform
        expect(cancelled_session.reload.status).to eq("cancelled")
      end
    end

    context "múltiplas sessões de múltiplos pacientes" do
      let(:patient_b) { create(:user, :client, therapist: therapist) }
      let!(:s1)       { create(:session, user: patient,   status: :scheduled, scheduled_at: 2.hours.ago) }
      let!(:s2)       { create(:session, user: patient_b, status: :scheduled, scheduled_at: 4.hours.ago) }
      let!(:s3)       { create(:session, user: patient,   status: :scheduled, scheduled_at: 30.minutes.ago) }

      it "completa apenas as elegíveis" do
        described_class.new.perform

        expect(s1.reload.status).to eq("completed")
        expect(s2.reload.status).to eq("completed")
        expect(s3.reload.status).to eq("scheduled")
      end
    end

    context "idempotência" do
      let!(:session) { create(:session, user: patient, status: :scheduled, scheduled_at: 2.hours.ago) }

      it "é seguro de executar múltiplas vezes sem efeito colateral" do
        2.times { described_class.new.perform }
        expect(session.reload.status).to eq("completed")
        expect(Session.where(status: :completed).count).to eq(1)
      end
    end

    it "usa a fila :default" do
      expect(described_class.queue_name).to eq("default")
    end
  end
end
