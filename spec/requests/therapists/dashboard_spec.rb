require 'rails_helper'

RSpec.describe "Therapists::Dashboard", type: :request do
  include_context "autenticado como terapeuta"

  describe "GET /therapists/dashboard" do
    context "sem autenticação" do
      it "retorna 401" do
        get therapists_dashboard_path
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "com JWT forjado" do
      it "retorna 401" do
        get therapists_dashboard_path,
            headers: { "Authorization" => "Bearer token.invalido.assinado" }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "autenticado como cliente" do
      let!(:client) { create(:user, :client, therapist: therapist) }

      it "retorna 403" do
        get therapists_dashboard_path, headers: auth_headers_for(client)
        expect(response).to have_http_status(:forbidden)
      end
    end

    # Happy path base
    context "com dados mínimos" do
      before { get therapists_dashboard_path, headers: headers }

      it "retorna 200" do
        expect(response).to have_http_status(:ok)
      end

      it "retorna as chaves esperadas no body" do
        expect(json_body).to include("stats", "patients", "calendar_sessions")
      end
    end

    describe "stats" do
      context "sem pacientes nem sessões" do
        before { get therapists_dashboard_path, headers: headers }

        it "retorna as chaves de stats" do
          expect(json_body["stats"]).to include(
            "active_clients",
            "sessions_today",
            "sessions_this_week",
            "sessions_completed_this_week"
          )
        end

        it "retorna zeros quando não há dados" do
          stats = json_body["stats"]
          expect(stats["active_clients"]).to eq(0)
          expect(stats["sessions_today"]).to eq(0)
          expect(stats["sessions_this_week"]).to eq(0)
          expect(stats["sessions_completed_this_week"]).to eq(0)
        end
      end

      context "com pacientes e sessões" do
        let!(:patient1) { create(:user, :client, therapist: therapist) }
        let!(:patient2) { create(:user, :client, therapist: therapist) }

        it "conta apenas pacientes do terapeuta autenticado" do
          other_therapist = create(:user, :therapist)
          create(:user, :client, therapist: other_therapist)

          get therapists_dashboard_path, headers: headers

          expect(json_body["stats"]["active_clients"]).to eq(2)
        end

        context "contagem de sessões por data" do
          before do
            travel_to Time.zone.local(2025, 6, 11, 12, 0, 0) do # quarta-feira
              create(:session, user: patient1, scheduled_at: Time.zone.now, status: :scheduled)
              create(:session, user: patient1, scheduled_at: Time.zone.now - 1.day, status: :completed)
              create(:session, user: patient2, scheduled_at: Time.zone.now + 3.days, status: :scheduled)

              get therapists_dashboard_path, headers: headers
            end
          end

          it "conta sessions_today corretamente" do
            expect(json_body["stats"]["sessions_today"]).to eq(1)
          end

          it "conta sessions_this_week corretamente" do
            expect(json_body["stats"]["sessions_this_week"]).to eq(3)
          end

          it "conta sessions_completed_this_week corretamente" do
            expect(json_body["stats"]["sessions_completed_this_week"]).to eq(1)
          end
        end

        context "isolamento: não conta sessões de outros terapeutas" do
          before do
            other_therapist = create(:user, :therapist)
            other_patient   = create(:user, :client, therapist: other_therapist)
            create(:session, user: other_patient, scheduled_at: Time.zone.now)

            get therapists_dashboard_path, headers: headers
          end

          it "não inclui sessões de outros terapeutas nas stats" do
            expect(json_body["stats"]["sessions_today"]).to eq(0)
          end
        end
      end
    end

    describe "patients" do
      context "sem pacientes" do
        before { get therapists_dashboard_path, headers: headers }

        it "retorna array vazio" do
          expect(json_body["patients"]).to eq([])
        end
      end

      context "com um paciente sem schedule e sem sessões" do
        let!(:patient) { create(:user, :client, therapist: therapist) }

        before { get therapists_dashboard_path, headers: headers }

        it "inclui o paciente na lista" do
          expect(json_body["patients"].length).to eq(1)
        end

        it "retorna o shape completo do patient" do
          p = json_body["patients"].first
          expect(p).to include(
            "id", "name", "email", "google_meet_link",
            "schedule_type", "sessions_per_week", "session_days",
            "session_time", "extra_sessions",
            "completed_sessions", "absent_sessions", "clinical_notes_count"
          )
        end

        it "retorna schedule_type 'extra' quando não há schedule ativo" do
          expect(json_body["patients"].first["schedule_type"]).to eq("extra")
        end

        it "retorna sessions_per_week nil sem schedule ativo" do
          expect(json_body["patients"].first["sessions_per_week"]).to be_nil
        end

        it "retorna completed_sessions 0" do
          expect(json_body["patients"].first["completed_sessions"]).to eq(0)
        end

        it "retorna absent_sessions 0" do
          expect(json_body["patients"].first["absent_sessions"]).to eq(0)
        end

        it "retorna clinical_notes_count zero" do
          expect(json_body["patients"].first["clinical_notes_count"]).to eq(0)
        end

        it "não expõe o conteúdo das notas clínicas no payload do dashboard" do
          expect(json_body["patients"].first).not_to have_key("clinical_notes")
        end
      end

      context "com weekly_schedule ativo" do
        let!(:patient) { create(:user, :client, therapist: therapist) }
        let!(:schedule) do
          create(:weekly_schedule, user: patient, weekday: :monday,
                 time: "10:00", sessions_per_week: 1,
                 effective_from: Date.current, effective_until: nil)
        end

        before { get therapists_dashboard_path, headers: headers }

        it "retorna schedule_type 'regular'" do
          expect(json_body["patients"].first["schedule_type"]).to eq("regular")
        end

        it "retorna sessions_per_week correto" do
          expect(json_body["patients"].first["sessions_per_week"]).to eq(1)
        end

        it "retorna session_days com o weekday do schedule" do
          expect(json_body["patients"].first["session_days"]).to eq([ "monday" ])
        end
      end

      context "com sessões completadas e ausentes" do
        let!(:patient) { create(:user, :client, therapist: therapist) }
        let!(:completed1) { create(:session, :completed, user: patient) }
        let!(:completed2) { create(:session, :completed, user: patient) }
        let!(:absent1)    { create(:session, :absent,    user: patient) }

        before { get therapists_dashboard_path, headers: headers }

        it "conta completed_sessions corretamente" do
          expect(json_body["patients"].first["completed_sessions"]).to eq(2)
        end

        it "conta absent_sessions corretamente" do
          expect(json_body["patients"].first["absent_sessions"]).to eq(1)
        end
      end

      context "com sessões do tipo extra" do
        let!(:patient) { create(:user, :client, therapist: therapist) }
        let!(:extra_session) { create(:session, :extra, user: patient, scheduled_at: 2.days.from_now.noon) }

        before { get therapists_dashboard_path, headers: headers }

        it "inclui a sessão extra em extra_sessions" do
          extra = json_body["patients"].first["extra_sessions"]
          expect(extra.length).to eq(1)
          expect(extra.first["id"]).to eq(extra_session.id)
          expect(extra.first).to include("date", "time", "status")
        end
      end

      context "com clinical_notes do terapeuta" do
        let!(:patient) { create(:user, :client, therapist: therapist) }
        let!(:note_newer) do
          create(:clinical_note, user: patient, therapist: therapist,
                 content: "Nota mais recente", created_at: 1.day.ago)
        end
        let!(:note_older) do
          create(:clinical_note, user: patient, therapist: therapist,
                 content: "Nota mais antiga", created_at: 3.days.ago)
        end

        before { get therapists_dashboard_path, headers: headers }

        it "conta apenas as notas do terapeuta autenticado" do
          other_therapist = create(:user, :therapist)
          create(:clinical_note, user: patient, therapist: other_therapist, content: "Nota alheia")

          get therapists_dashboard_path, headers: headers

          expect(json_body["patients"].first["clinical_notes_count"]).to eq(2)
        end

        it "não expõe o conteúdo das notas em lugar nenhum do payload" do
          expect(response.body).not_to include("Nota mais recente")
          expect(response.body).not_to include("Nota mais antiga")
        end

        it "não inclui a chave clinical_notes" do
          expect(json_body["patients"].first).not_to have_key("clinical_notes")
        end
      end

      context "não retorna pacientes de outros terapeutas" do
        let!(:patient) { create(:user, :client, therapist: therapist) }

        before do
          other_therapist = create(:user, :therapist)
          create(:user, :client, therapist: other_therapist)

          get therapists_dashboard_path, headers: headers
        end

        it "retorna apenas o paciente do terapeuta autenticado" do
          ids = json_body["patients"].map { |p| p["id"] }
          expect(ids).to eq([ patient.id ])
        end
      end
    end

    describe "calendar_sessions" do
      context "sem sessões" do
        before { get therapists_dashboard_path, headers: headers }

        it "retorna array vazio" do
          expect(json_body["calendar_sessions"]).to eq([])
        end
      end

      context "com sessões do terapeuta" do
        let(:fixed_slot) { Time.zone.local(2025, 8, 15, 14, 30, 0) }

        around { |example| travel_to(fixed_slot - 1.day) { example.run } }

        let!(:patient) { create(:user, :client, therapist: therapist) }
        let!(:session) do
          create(:session, user: patient,
                 scheduled_at: fixed_slot,
                 status: :scheduled, session_type: :recurring)
        end

        before { get therapists_dashboard_path, headers: headers }

        it "retorna o shape completo da calendar_session" do
          entry = json_body["calendar_sessions"].first
          expect(entry).to include("id", "date", "time", "status", "session_type", "patient")
        end

        it "formata date como ISO8601" do
          expect(json_body["calendar_sessions"].first["date"]).to eq("2025-08-15")
        end

        it "formata time como HH:MM" do
          expect(json_body["calendar_sessions"].first["time"]).to eq("14:30")
        end

        it "retorna status e session_type corretos" do
          entry = json_body["calendar_sessions"].first
          expect(entry["status"]).to eq("scheduled")
          expect(entry["session_type"]).to eq("recurring")
        end

        it "inclui os dados do paciente" do
          patient_data = json_body["calendar_sessions"].first["patient"]
          expect(patient_data["id"]).to eq(patient.id)
          expect(patient_data["name"]).to eq(patient.name)
          expect(patient_data).to have_key("google_meet_link")
        end
      end

      context "ordenação por scheduled_at" do
        let!(:patient) { create(:user, :client, therapist: therapist) }
        let!(:session_later)  { create(:session, user: patient, scheduled_at: 5.days.from_now.noon) }
        let!(:session_sooner) { create(:session, user: patient, scheduled_at: 1.day.from_now.noon) }

        before { get therapists_dashboard_path, headers: headers }

        it "retorna sessões em ordem crescente de data" do
          ids = json_body["calendar_sessions"].map { |s| s["id"] }
          expect(ids).to eq([ session_sooner.id, session_later.id ])
        end
      end

      context "não inclui sessões de outros terapeutas" do
        let!(:patient) { create(:user, :client, therapist: therapist) }
        let!(:session) { create(:session, user: patient, scheduled_at: 1.day.from_now.noon) }

        before do
          other_therapist = create(:user, :therapist)
          other_patient   = create(:user, :client, therapist: other_therapist)
          create(:session, user: other_patient, scheduled_at: 2.days.from_now.noon)

          get therapists_dashboard_path, headers: headers
        end

        it "retorna apenas a sessão do terapeuta autenticado" do
          expect(json_body["calendar_sessions"].length).to eq(1)
          expect(json_body["calendar_sessions"].first["id"]).to eq(session.id)
        end
      end
    end
  end
end
