require 'rails_helper'

RSpec.describe "Clients::Dashboard", type: :request do
  let(:therapist) { create(:user, :therapist) }
  let(:client)    { create(:user, :client, therapist: therapist, google_meet_link: "https://meet.google.com/abc-123") }
  let(:headers)   { auth_headers_for(client) }

  describe "GET /clients/dashboard" do
    context "quando autenticado como cliente" do
      it "retorna 200" do
        get clients_dashboard_path, headers: headers
        expect(response).to have_http_status(:ok)
      end

      it "retorna a estrutura esperada (profile, stats, next_session, notes)" do
        get clients_dashboard_path, headers: headers

        body = json_body
        expect(body).to have_key("profile")
        expect(body).to have_key("stats")
        expect(body).to have_key("next_session")
        expect(body).to have_key("notes")
      end

      describe "profile" do
        it "contém os dados do perfil do cliente" do
          get clients_dashboard_path, headers: headers

          profile = json_body["profile"]
          expect(profile["name"]).to eq(client.name)
          expect(profile["email"]).to eq(client.email)
          expect(profile["google_meet_link"]).to eq("https://meet.google.com/abc-123")
        end
      end

      describe "stats" do
        it "retorna contagem de sessões completadas e ausências" do
          create(:session, user: client, status: :completed, scheduled_at: 1.week.ago)
          create(:session, user: client, status: :completed, scheduled_at: 2.weeks.ago)
          create(:session, user: client, status: :absent, scheduled_at: 3.weeks.ago)

          get clients_dashboard_path, headers: headers

          stats = json_body["stats"]
          expect(stats["completed_sessions"]).to eq(2)
          expect(stats["absent_sessions"]).to eq(1)
        end
      end

      describe "next_session" do
        context "quando há sessão futura agendada" do
          let!(:next_session) do
            create(:session, user: client, status: :scheduled, scheduled_at: 3.days.from_now.noon)
          end

          it "retorna os dados da próxima sessão" do
            get clients_dashboard_path, headers: headers

            ns = json_body["next_session"]
            expect(ns).not_to be_nil
            expect(ns["id"]).to eq(next_session.id)
            expect(ns["status"]).to eq("scheduled")
          end
        end

        context "quando não há sessão futura" do
          it "retorna next_session como null" do
            get clients_dashboard_path, headers: headers

            expect(json_body["next_session"]).to be_nil
          end
        end
      end

      describe "notes" do
        it "retorna as anotações do paciente em ordem decrescente" do
          note1 = create(:patient_note, user: client, content: "Primeira")
          note2 = create(:patient_note, user: client, content: "Segunda")

          get clients_dashboard_path, headers: headers

          notes = json_body["notes"]
          expect(notes.length).to eq(2)
          # Mais recente primeiro
          expect(notes.first["id"]).to eq(note2.id)
        end
      end
    end

    context "sem autenticação" do
      it "retorna 401" do
        get clients_dashboard_path
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "quando autenticado como terapeuta" do
      let(:therapist_headers) { auth_headers_for(therapist) }

      it "retorna 403 Forbidden" do
        get clients_dashboard_path, headers: therapist_headers
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "quando must_change_password está ativo" do
      let(:blocked_client) { create(:user, :client, :must_change_password, therapist: therapist) }
      let(:blocked_headers) { auth_headers_for(blocked_client) }

      it "retorna 403 com mensagem de troca de senha obrigatória" do
        get clients_dashboard_path, headers: blocked_headers

        expect(response).to have_http_status(:forbidden)
        expect(json_body["must_change_password"]).to be true
      end
    end

    context "JWT inválido" do
      it "retorna 401 com token forjado" do
        get clients_dashboard_path, headers: { "Authorization" => "Bearer token.invalido.aqui" }
        expect(response).to have_http_status(:unauthorized)
      end

      it "retorna 401 sem token" do
        get clients_dashboard_path
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
