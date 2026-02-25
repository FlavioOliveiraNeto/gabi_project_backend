require 'rails_helper'

RSpec.describe "Clients::Sessions", type: :request do
  let(:therapist) { create(:user, :therapist, google_meet_link: "https://meet.google.com/ther-apist") }
  let(:client)    { create(:user, :client, therapist: therapist, google_meet_link: "https://meet.google.com/cli-ente") }
  let(:headers)   { auth_headers_for(client) }

  # ─── GET /clients/sessions ────────────────────────────────────────────────────
  describe "GET /clients/sessions" do
    context "quando autenticado como cliente" do
      let!(:session1) do
        create(:session, user: client, status: :scheduled, scheduled_at: 1.week.from_now)
      end
      let!(:session2) do
        create(:session, user: client, status: :completed, scheduled_at: 1.week.ago)
      end

      it "retorna 200" do
        get clients_sessions_path, headers: headers
        expect(response).to have_http_status(:ok)
      end

      it "retorna apenas as sessões do cliente autenticado" do
        other_client = create(:user, :client, therapist: therapist)
        create(:session, user: other_client, scheduled_at: 2.weeks.from_now)

        get clients_sessions_path, headers: headers

        ids = json_body.map { |s| s["id"] }
        expect(ids).to include(session1.id, session2.id)
        expect(ids).not_to include(other_client.sessions.first&.id)
      end

      it "retorna as sessões em ordem crescente de scheduled_at" do
        get clients_sessions_path, headers: headers

        dates = json_body.map { |s| s["scheduled_at"] }
        expect(dates).to eq(dates.sort)
      end

      it "inclui os campos esperados em cada sessão" do
        get clients_sessions_path, headers: headers

        session_data = json_body.first
        expect(session_data).to have_key("id")
        expect(session_data).to have_key("date")
        expect(session_data).to have_key("time")
        expect(session_data).to have_key("status")
        expect(session_data).to have_key("session_type")
        expect(session_data).to have_key("google_meet_link")
      end

      it "inclui o google_meet_link do próprio cliente" do
        get clients_sessions_path, headers: headers

        session_data = json_body.find { |s| s["id"] == session1.id }
        expect(session_data["google_meet_link"]).to eq(client.google_meet_link)
      end
    end

    context "sem autenticação" do
      it "retorna 401" do
        get clients_sessions_path
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "quando autenticado como terapeuta" do
      it "retorna 403" do
        get clients_sessions_path, headers: auth_headers_for(therapist)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "quando must_change_password está ativo" do
      let(:blocked_client) { create(:user, :client, :must_change_password, therapist: therapist) }

      it "retorna 403" do
        get clients_sessions_path, headers: auth_headers_for(blocked_client)
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
