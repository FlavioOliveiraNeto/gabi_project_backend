require 'rails_helper'

RSpec.describe "Clients::Dashboard", type: :request do
  let(:therapist) { create(:user, :therapist) }
  let(:client)    { create(:user, :client, therapist: therapist, google_meet_link: "https://meet.google.com/abc-123") }
  let(:headers)   { auth_headers_for(client) }

  describe "GET /clients/dashboard" do
    
    # Autenticação
    context "sem autenticação ou com token inválido" do
      it "retorna 401 sem token" do
        get clients_dashboard_path
        expect(response).to have_http_status(:unauthorized)
      end

      it "retorna 401 com token forjado" do
        get clients_dashboard_path, headers: { "Authorization" => "Bearer token.invalido.aqui" }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    # Autorização de role
    context "autenticado como terapeuta" do
      let(:therapist_headers) { auth_headers_for(therapist) }

      it "retorna 403 Forbidden" do
        get clients_dashboard_path, headers: therapist_headers
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "com must_change_password ativo" do
      let(:blocked_client)  { create(:user, :client, :must_change_password, therapist: therapist) }
      let(:blocked_headers) { auth_headers_for(blocked_client) }

      it "retorna 403 com flag must_change_password" do
        get clients_dashboard_path, headers: blocked_headers
        expect(response).to have_http_status(:forbidden)
        expect(json_body["must_change_password"]).to be(true)
      end
    end

    # Fluxo feliz
    context "autenticado como cliente" do
      before { get clients_dashboard_path, headers: headers }

      it "retorna 200" do
        expect(response).to have_http_status(:ok)
      end

      it "retorna a estrutura esperada" do
        expect(json_body).to include("profile", "stats", "next_session", "notes")
      end

      # profile
      describe "profile" do
        it "contém os dados do perfil do cliente" do
          profile = json_body["profile"]
          expect(profile["name"]).to eq(client.name)
          expect(profile["email"]).to eq(client.email)
          expect(profile["google_meet_link"]).to eq("https://meet.google.com/abc-123")
        end

        it "inclui o campo phone (pode ser nil)" do
          expect(json_body["profile"]).to have_key("phone")
        end
      end

      # stats
      describe "stats" do
        context "sem sessões registradas" do
          it "retorna zeros" do
            expect(json_body["stats"]["completed_sessions"]).to eq(0)
            expect(json_body["stats"]["absent_sessions"]).to eq(0)
          end
        end
      end
    end

    describe "stats com sessões" do
      before do
        create(:session, user: client, status: :completed, scheduled_at: 1.week.ago)
        create(:session, user: client, status: :completed, scheduled_at: 2.weeks.ago)
        create(:session, user: client, status: :absent,    scheduled_at: 3.weeks.ago)
        get clients_dashboard_path, headers: headers
      end

      it "conta sessões completadas" do
        expect(json_body["stats"]["completed_sessions"]).to eq(2)
      end

      it "conta ausências" do
        expect(json_body["stats"]["absent_sessions"]).to eq(1)
      end

      it "não contamina stats com sessões de outro cliente" do
        other_client = create(:user, :client, therapist: therapist)
        create(:session, user: other_client, status: :completed, scheduled_at: 1.day.ago)
        create(:session, user: other_client, status: :absent,    scheduled_at: 2.days.ago)

        get clients_dashboard_path, headers: headers

        expect(json_body["stats"]["completed_sessions"]).to eq(2)
        expect(json_body["stats"]["absent_sessions"]).to eq(1)
      end
    end

    # next_session
    describe "next_session" do
      context "quando não há sessão futura agendada" do
        before { get clients_dashboard_path, headers: headers }

        it "retorna next_session como null" do
          expect(json_body["next_session"]).to be_nil
        end
      end

      context "quando há apenas sessão no passado" do
        before do
          create(:session, user: client, status: :scheduled, scheduled_at: 1.hour.ago)
          get clients_dashboard_path, headers: headers
        end

        it "retorna next_session como null" do
          expect(json_body["next_session"]).to be_nil
        end
      end

      context "quando há sessão futura agendada" do
        let!(:next_session) do
          create(:session, user: client, status: :scheduled, scheduled_at: 3.days.from_now.noon)
        end

        before { get clients_dashboard_path, headers: headers }

        it "retorna o id da próxima sessão" do
          expect(json_body["next_session"]["id"]).to eq(next_session.id)
        end

        it "retorna o status como scheduled" do
          expect(json_body["next_session"]["status"]).to eq("scheduled")
        end

        it "retorna o shape completo da sessão" do
          ns = json_body["next_session"]
          expect(ns).to include("id", "date", "time", "weekday", "session_type", "status")
          expect(ns["date"]).to eq(next_session.scheduled_at.to_date.iso8601)
          expect(ns["time"]).to eq(next_session.scheduled_at.strftime("%H:%M"))
        end
      end
    end

    # notes
    describe "notes" do
      context "sem anotações" do
        before { get clients_dashboard_path, headers: headers }

        it "retorna array vazio" do
          expect(json_body["notes"]).to eq([])
        end
      end

      context "com anotações" do
        let!(:note1) { create(:patient_note, user: client, content: "Primeira") }
        let!(:note2) { create(:patient_note, user: client, content: "Segunda") }

        before { get clients_dashboard_path, headers: headers }

        it "retorna na ordem decrescente de criação (mais recente primeiro)" do
          ids = json_body["notes"].map { |n| n["id"] }
          expect(ids).to eq([ note2.id, note1.id ])
        end

        it "inclui o shape completo da anotação" do
          note = json_body["notes"].first
          expect(note).to include("id", "content", "created_at")
          expect(note["content"]).to eq("Segunda")
        end

        it "não contamina notes com anotações de outro cliente" do
          other_client = create(:user, :client, therapist: therapist)
          create(:patient_note, user: other_client, content: "Outra")

          get clients_dashboard_path, headers: headers

          expect(json_body["notes"].length).to eq(2)
          expect(json_body["notes"].map { |n| n["content"] }).not_to include("Outra")
        end
      end
    end
  end
end
