require 'rails_helper'

RSpec.describe "Therapists::Patients agenda por dia", type: :request do
  include_context "autenticado como terapeuta"

  let(:other) { create(:user, :client, therapist: therapist) }

  around { |ex| travel_to(Time.zone.local(2026, 3, 2, 9, 0)) { ex.run } }

  let(:slots) do
    [ { weekday: "saturday", time: "14:30" }, { weekday: "wednesday", time: "14:30" } ]
  end

  def create_patient(payload = {})
    post "/therapists/patients",
         params: {
           name: "Fulana", email: "fulana@example.com",
           schedule_type: "regular", schedule_slots: slots
         }.merge(payload),
         headers: headers, as: :json
  end

  describe "POST /therapists/patients" do
    it "cria o paciente com horários distintos por dia" do
      create_patient(schedule_slots: [
        { weekday: "saturday",  time: "08:00" },
        { weekday: "wednesday", time: "19:00" }
      ])

      expect(response).to have_http_status(:created)
      times = User.find(json_body["id"]).weekly_schedules.pluck(:weekday, :time).to_h
      expect(times).to eq("saturday" => "08:00", "wednesday" => "19:00")
    end

    it "continua aceitando o payload legado weekdays + session_time" do
      create_patient(schedule_slots: nil, weekdays: %w[monday friday],
                     sessions_per_week: 2, session_time: "10:00")

      expect(response).to have_http_status(:created)
      expect(User.find(json_body["id"]).weekly_schedules.pluck(:time).uniq).to eq([ "10:00" ])
    end

    context "com o sábado 14:00 já ocupado por outro paciente" do
      let!(:occupied) do
        create(:session, :scheduled, user: other,
               scheduled_at: Time.zone.local(2026, 3, 7, 14, 0),
               start_time:   Time.zone.local(2026, 3, 7, 14, 0),
               end_time:     Time.zone.local(2026, 3, 7, 14, 50))
      end

      it "responde 422 em vez de criar o paciente pela metade" do
        create_patient
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "não cria o paciente (rollback completo)" do
        expect { create_patient }.not_to change { User.count }
      end

      it "não cria a sessão de quarta, que sozinha não conflitaria" do
        expect { create_patient }.not_to change { Session.count }
      end

      it "devolve a lista de conflitos com dia, horário e data" do
        create_patient

        conflict = json_body["conflicts"].first
        expect(json_body["conflicts"].size).to eq(1)
        expect(conflict).to include("weekday" => "saturday", "time" => "14:30")
        expect(conflict["scheduled_at"]).to start_with("2026-03-07")
      end

      it "devolve mensagem em pt-BR pedindo para alterar o horário" do
        create_patient
        expect(json_body["error"]).to match(/já existe uma sessão/i)
        expect(json_body["error"]).to match(/outro horário/i)
      end

      it "nunca vaza generated_password numa resposta de erro" do
        create_patient
        expect(json_body).not_to have_key("generated_password")
      end
    end
  end

  describe "PUT /therapists/patients/:id/update_schedule" do
    let(:patient) { create(:user, :client, therapist: therapist) }
    let!(:current_schedule) { create(:weekly_schedule, user: patient, weekday: :monday, time: "09:00") }

    def update_schedule(payload)
      put "/therapists/patients/#{patient.id}/update_schedule",
          params: { schedule_type: "regular" }.merge(payload),
          headers: headers, as: :json
    end

    it "troca a agenda para horários distintos por dia" do
      update_schedule(schedule_slots: [
        { weekday: "saturday",  time: "08:00" },
        { weekday: "wednesday", time: "19:00" }
      ])

      expect(response).to have_http_status(:ok)
      expect(patient.weekly_schedules.active.pluck(:weekday, :time).to_h)
        .to eq("saturday" => "08:00", "wednesday" => "19:00")
    end

    it "422 e mantém a agenda antiga intacta quando há conflito" do
      create(:session, :scheduled, user: other,
             scheduled_at: Time.zone.local(2026, 3, 7, 14, 0),
             start_time:   Time.zone.local(2026, 3, 7, 14, 0),
             end_time:     Time.zone.local(2026, 3, 7, 14, 50))

      update_schedule(schedule_slots: slots)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(current_schedule.reload.effective_until).to be_nil
      expect(patient.weekly_schedules.count).to eq(1)
    end

    it "422 com dia da semana inválido" do
      update_schedule(schedule_slots: [ { weekday: "sextou", time: "10:00" } ])
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "422 com horário fora do formato HH:MM" do
      update_schedule(schedule_slots: [ { weekday: "monday", time: "9h" } ])
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "422 com schedule_slots vazio" do
      update_schedule(schedule_slots: [])
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "escopo e autorização" do
    it "não permite que outra terapeuta altere a agenda do paciente" do
      patient  = create(:user, :client, therapist: therapist)
      intruder = create(:user, :therapist)

      put "/therapists/patients/#{patient.id}/update_schedule",
          params: { schedule_type: "regular", schedule_slots: slots },
          headers: therapist_auth_headers(intruder), as: :json

      expect(response).to have_http_status(:not_found)
    end
  end
end
