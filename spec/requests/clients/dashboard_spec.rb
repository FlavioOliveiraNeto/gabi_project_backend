require 'rails_helper'

RSpec.describe "Clients::Dashboard", type: :request do
  let(:parsed_response) { JSON.parse(response.body).deep_symbolize_keys }

  describe "GET /clients/dashboard" do
    context "when not authenticated" do
      it "returns a 401 unauthorized status" do
        get clients_dashboard_path, as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when authenticated" do
      let(:therapist) { create(:user, :therapist) }
      let(:user) { create(:user, :client, therapist: therapist) }

      before do
        sign_in user
      end

      context "when user is not a client" do
        let(:user) { create(:user, :therapist) }

        it "returns 403 forbidden with an error message" do
          get clients_dashboard_path, as: :json
          expect(response).to have_http_status(:forbidden)
          expect(parsed_response[:error]).to eq("Acesso restrito a clientes.")
        end
      end

      context "when user needs a password change" do
        let(:user) { create(:user, :client, :must_change_password) }

        it "blocks access" do
          get clients_dashboard_path, as: :json
          expect(response).to have_http_status(:forbidden)
          expect(parsed_response[:must_change_password]).to eq(true)
          expect(parsed_response[:error]).to eq("É necessário trocar a senha antes de continuar.")
        end
      end

      context "when user is a valid client" do
        let(:completed_session) { create(:session, :completed, user: user) }
        let(:absent_session) { create(:session, :absent, user: user) }
        let(:scheduled_session) { create(:session, status: :scheduled, scheduled_at: 1.day.from_now, user: user) }
        let(:newer_note) { create(:patient_note, user: user, created_at: 1.day.ago) }

        context "with a fully populated dashboard" do
          before do
            completed_session
            absent_session
            scheduled_session
            create(:patient_note, user: user, created_at: 2.days.ago)
            newer_note
          end

          it "returns status 200 and the complete dashboard JSON payload" do
            get clients_dashboard_path, as: :json

            expect(response).to have_http_status(:ok)
            expect(parsed_response[:profile]).to include(
              name: user.name,
              email: user.email
            )
            expect(parsed_response[:stats]).to match(completed_sessions: 1, absent_sessions: 1)
            expect(parsed_response[:next_session][:id]).to eq(scheduled_session.id)
            expect(parsed_response[:notes].length).to eq(2)
          end
        end

        context "when there are multiple future scheduled sessions" do
          let!(:earlier_session) { create(:session, status: :scheduled, scheduled_at: 1.day.from_now, user: user) }
          let!(:later_session) { create(:session, :extra, status: :scheduled, scheduled_at: 2.days.from_now, user: user) }

          it "returns the earliest one as next_session" do
            get clients_dashboard_path, as: :json
            expect(parsed_response[:next_session][:id]).to eq(earlier_session.id)
          end
        end

        context "when the user has no future scheduled sessions" do
          it "returns nil for next_session" do
            get clients_dashboard_path, as: :json
            expect(parsed_response[:next_session]).to be_nil
          end
        end

        context "when the only scheduled session is in the past" do
          let!(:past_scheduled_session) { create(:session, status: :scheduled, scheduled_at: 1.day.ago, user: user) }

          it "returns nil for next_session" do
            get clients_dashboard_path, as: :json
            expect(parsed_response[:next_session]).to be_nil
          end
        end
      end
    end
  end
end
