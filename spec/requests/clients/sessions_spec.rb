require 'rails_helper'

RSpec.describe "Clients::Sessions", type: :request do
  let(:therapist) { create(:user, :therapist) }
  let(:client)    { create(:user, :client, therapist: therapist) }
  let(:headers)   { auth_headers_for(client) }

  describe "GET /clients/sessions" do
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

    context "quando o cliente não tem sessões" do
      before { get clients_sessions_path, headers: headers }

      it "retorna 200 com lista vazia" do
        expect(response).to have_http_status(:ok)
        expect(json_body).to eq([])
      end
    end

    context "com sessões do cliente" do
      let!(:session1) do
        create(:session, user: client, status: :scheduled, scheduled_at: 1.week.from_now)
      end
      let!(:session2) do
        create(:session, user: client, status: :completed, scheduled_at: 1.week.ago)
      end
      let!(:other_session) do
        create(:session, user: create(:user, :client, therapist: therapist), scheduled_at: 2.weeks.from_now)
      end

      before { get clients_sessions_path, headers: headers }

      it "retorna 200" do
        expect(response).to have_http_status(:ok)
      end

      it "retorna as sessões em ordem crescente de scheduled_at" do
        dates = json_body.map { |s| s["scheduled_at"] }
        expect(dates).to eq(dates.sort)
      end

      it "inclui os campos esperados em cada sessão" do
        session_data = json_body.first
        expect(session_data).to include(
          "id", "scheduled_at", "date", "time",
          "status", "status_label", "session_type", "google_meet_link",
          "created_at", "updated_at"
        )
      end

      it "inclui o google_meet_link do cliente autenticado" do
        session_data = json_body.find { |s| s["id"] == session1.id }
        expect(session_data["google_meet_link"]).to eq(client.google_meet_link)
      end

      it "inclui as sessões do cliente autenticado" do
        ids = json_body.map { |s| s["id"] }
        expect(ids).to include(session1.id, session2.id)
      end

      it "não retorna sessões de outros clientes" do
        ids = json_body.map { |s| s["id"] }
        expect(ids).not_to include(other_session.id)
      end
    end
  end
end
