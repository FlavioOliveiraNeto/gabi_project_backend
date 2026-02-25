require 'rails_helper'

RSpec.describe "Therapists::Dashboard", type: :request do
  let(:therapist) { create(:user, :therapist) }
  let(:headers)   { auth_headers_for(therapist) }

  # ─── GET /therapists/dashboard ────────────────────────────────────────────────
  describe "GET /therapists/dashboard" do
    context "quando autenticado como terapeuta" do
      it "retorna 200" do
        get therapists_dashboard_path, headers: headers
        expect(response).to have_http_status(:ok)
      end

      it "retorna a estrutura esperada (stats, patients, calendar_sessions)" do
        get therapists_dashboard_path, headers: headers

        body = json_body
        expect(body).to have_key("stats")
        expect(body).to have_key("patients")
        expect(body).to have_key("calendar_sessions")
      end

      describe "stats" do
        let!(:patient1) { create(:user, :client, therapist: therapist) }
        let!(:patient2) { create(:user, :client, therapist: therapist) }

        it "retorna a contagem correta de pacientes ativos" do
          get therapists_dashboard_path, headers: headers

          expect(json_body["stats"]["active_clients"]).to eq(2)
        end

        it "conta apenas pacientes do terapeuta autenticado" do
          other_therapist = create(:user, :therapist)
          create(:user, :client, therapist: other_therapist)

          get therapists_dashboard_path, headers: headers

          expect(json_body["stats"]["active_clients"]).to eq(2)
        end

        it "inclui sessions_today, sessions_this_week, sessions_completed_this_week" do
          get therapists_dashboard_path, headers: headers

          stats = json_body["stats"]
          expect(stats).to have_key("sessions_today")
          expect(stats).to have_key("sessions_this_week")
          expect(stats).to have_key("sessions_completed_this_week")
        end
      end

      describe "patients" do
        let!(:patient) { create(:user, :client, therapist: therapist) }

        it "retorna os pacientes do terapeuta" do
          get therapists_dashboard_path, headers: headers

          patients = json_body["patients"]
          expect(patients.length).to eq(1)
          expect(patients.first["id"]).to eq(patient.id)
          expect(patients.first["name"]).to eq(patient.name)
        end

        it "não retorna pacientes de outros terapeutas" do
          other_therapist = create(:user, :therapist)
          create(:user, :client, therapist: other_therapist)

          get therapists_dashboard_path, headers: headers

          ids = json_body["patients"].map { |p| p["id"] }
          expect(ids).to eq([patient.id])
        end

        it "inclui clinical_notes filtradas pelo terapeuta atual" do
          other_therapist = create(:user, :therapist)
          create(:clinical_note, user: patient, therapist: therapist, content: "Minha nota")
          create(:clinical_note, user: patient, therapist: other_therapist, content: "Nota alheia")

          get therapists_dashboard_path, headers: headers

          patient_data = json_body["patients"].first
          expect(patient_data["clinical_notes"].length).to eq(1)
          expect(patient_data["clinical_notes"].first["content"]).to eq("Minha nota")
        end
      end

      describe "calendar_sessions" do
        let!(:patient) { create(:user, :client, therapist: therapist) }
        let!(:session) { create(:session, user: patient, scheduled_at: 1.day.from_now.noon) }

        it "retorna as sessões com dados do paciente" do
          get therapists_dashboard_path, headers: headers

          calendar = json_body["calendar_sessions"]
          expect(calendar.length).to eq(1)

          entry = calendar.first
          expect(entry["id"]).to eq(session.id)
          expect(entry["patient"]["id"]).to eq(patient.id)
          expect(entry["patient"]["name"]).to eq(patient.name)
        end

        it "não inclui sessões de outros terapeutas" do
          other_therapist = create(:user, :therapist)
          other_patient   = create(:user, :client, therapist: other_therapist)
          create(:session, user: other_patient, scheduled_at: 2.days.from_now.noon)

          get therapists_dashboard_path, headers: headers

          calendar = json_body["calendar_sessions"]
          expect(calendar.length).to eq(1)
        end
      end
    end

    context "sem autenticação" do
      it "retorna 401" do
        get therapists_dashboard_path
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "quando autenticado como cliente" do
      let(:client) { create(:user, :client, therapist: therapist) }

      it "retorna 403" do
        get therapists_dashboard_path, headers: auth_headers_for(client)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "JWT inválido" do
      it "retorna 401 com token forjado" do
        get therapists_dashboard_path,
            headers: { "Authorization" => "Bearer token.invalido.assinado" }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
