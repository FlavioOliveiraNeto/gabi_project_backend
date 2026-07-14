require "rails_helper"

RSpec.describe WeeklySessionGenerationJob, type: :job do
  let(:therapist) { create(:user, :therapist) }
  let(:patient)   { create(:user, :client, therapist: therapist) }

  
  # Atributo de classe (não pertence ao describe '#perform')
  describe ".queue_name" do
    it "usa a fila :default" do
      expect(described_class.queue_name).to eq("default")
    end
  end

  
  # #perform
  describe "#perform" do
    context "nenhum terapeuta cadastrado" do
      it "não gera sessões" do
        travel_to Time.zone.local(2026, 3, 1) do
          expect { described_class.new.perform }.not_to change(Session, :count)
        end
      end
    end

    context "terapeuta sem pacientes" do
      before { therapist }

      it "não gera sessões" do
        travel_to Time.zone.local(2026, 3, 1) do
          expect { described_class.new.perform }.not_to change(Session, :count)
        end
      end
    end

    context "paciente sem agenda semanal" do
      before { patient }

      it "não gera sessões" do
        travel_to Time.zone.local(2026, 3, 1) do
          expect { described_class.new.perform }.not_to change(Session, :count)
        end
      end
    end

    context "paciente com agenda ativa (segunda-feira, 10h, vigente desde fev/2026)" do
      before do
        create(:weekly_schedule, :monday, user: patient,
               time: "10:00", effective_from: Date.new(2026, 2, 1))
      end

      # Todas as asserções sobre a execução padrão compartilham o mesmo travel_to e perform
      context "ao executar no primeiro dia do mês (2026-03-01)" do
        around { |example| travel_to(Time.zone.local(2026, 3, 1)) { example.run } }

        before { described_class.new.perform }

        it "gera sessões do tipo regular" do
          expect(patient.sessions.where(session_type: :regular)).to exist
        end

        it "gera sessões com status scheduled" do
          expect(patient.sessions.where(session_type: :regular).map(&:status)).to all(eq("scheduled"))
        end

        it "gera exatamente 9 sessões (5 segundas em mar/2026 + 4 em abr/2026)" do
          # mar/2026: 2, 9, 16, 23, 30 — abr/2026: 6, 13, 20, 27
          expect(patient.sessions.where(session_type: :regular).count).to eq(9)
        end

        it "não gera sessões fora da janela do mês atual e próximo" do
          patient.sessions.where(session_type: :regular).each do |s|
            expect(s.scheduled_at.to_date).to be >= Date.new(2026, 3, 1)
            expect(s.scheduled_at.to_date).to be <= Date.new(2026, 4, 30)
          end
        end
      end

      it "é idempotente: não duplica sessões ao rodar duas vezes" do
        travel_to Time.zone.local(2026, 3, 1) do
          described_class.new.perform
          count = Session.count
          described_class.new.perform
          expect(Session.count).to eq(count)
        end
      end
    end

    context "paciente com agenda expirada (effective_until no passado)" do
      before do
        create(:weekly_schedule, :expired, user: patient)
      end

      it "não gera sessões" do
        travel_to Time.zone.local(2026, 3, 1) do
          expect { described_class.new.perform }.not_to change(Session, :count)
        end
      end
    end

    context "paciente com agenda futura (effective_from no futuro)" do
      before do
        create(:weekly_schedule, :future, user: patient)
      end

      it "não gera sessões" do
        travel_to Time.zone.local(2026, 3, 1) do
          expect { described_class.new.perform }.not_to change(Session, :count)
        end
      end
    end

    context "paciente com effective_until dentro da janela (até 2026-03-16)" do
      before do
        create(:weekly_schedule, :monday, user: patient,
               time: "10:00",
               effective_from: Date.new(2026, 2, 1),
               effective_until: Date.new(2026, 3, 16))
      end

      it "gera sessões apenas até a data de encerramento da agenda" do
        travel_to Time.zone.local(2026, 3, 1) do
          described_class.new.perform
          # segundas em mar/2026 até 16/03: 2, 9, 16 → 3 sessões
          dates = patient.sessions.where(session_type: :regular).pluck(:scheduled_at).map(&:to_date)
          expect(dates.count).to eq(3)
          expect(dates).to all(be <= Date.new(2026, 3, 16))
        end
      end
    end

    context "execução no meio do mês (2026-03-16)" do
      before do
        create(:weekly_schedule, :monday, user: patient,
               time: "10:00", effective_from: Date.new(2026, 2, 1))
      end

      it "não gera sessões para datas anteriores à data de execução" do
        travel_to Time.zone.local(2026, 3, 16) do
          described_class.new.perform
          dates = patient.sessions.where(session_type: :regular).pluck(:scheduled_at).map(&:to_date)
          expect(dates).to all(be >= Date.new(2026, 3, 16))
        end
      end
    end

    context "múltiplos terapeutas com pacientes e agendas distintas" do
      let(:other_therapist) { create(:user, :therapist) }
      let(:other_patient)   { create(:user, :client, therapist: other_therapist) }

      before do
        create(:weekly_schedule, :monday,  user: patient,       time: "09:00", effective_from: Date.new(2026, 2, 1))
        create(:weekly_schedule, :tuesday, user: other_patient, time: "11:00", effective_from: Date.new(2026, 2, 1))
      end

      it "gera sessões para pacientes de todos os terapeutas" do
        travel_to Time.zone.local(2026, 3, 1) do
          described_class.new.perform
          expect(patient.sessions.where(session_type: :regular)).to exist
          expect(other_patient.sessions.where(session_type: :regular)).to exist
        end
      end
    end
  end
end
