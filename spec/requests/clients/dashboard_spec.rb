require 'rails_helper'

RSpec.describe "Clients::Dashboard", type: :request do
  let(:parsed_response) { JSON.parse(response.body).deep_symbolize_keys }

  describe "GET /clients/dashboard" do
    context "quando não autenticado" do
      it "retorna 401 não autorizado" do
        get clients_dashboard_path, as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "quando autenticado" do
      let(:therapist) { create(:user, :therapist) }
      let(:user) { create(:user, :client, therapist: therapist) }

      before do
        sign_in user
      end

      context "quando o usuário não é um cliente" do
        let(:user) { create(:user, :therapist) }

        it "retorna 403 proibido com mensagem de erro" do
          get clients_dashboard_path, as: :json
          expect(response).to have_http_status(:forbidden)
          expect(parsed_response[:error]).to eq("Acesso restrito a clientes.")
        end
      end

      context "quando o usuário precisa trocar a senha" do
        let(:user) { create(:user, :client, :must_change_password) }

        it "bloqueia o acesso" do
          get clients_dashboard_path, as: :json
          expect(response).to have_http_status(:forbidden)
          expect(parsed_response[:must_change_password]).to eq(true)
          expect(parsed_response[:error]).to eq("É necessário trocar a senha antes de continuar.")
        end
      end

      context "quando o usuário é um cliente válido" do
        let(:completed_session) { create(:session, :completed, user: user) }
        let(:absent_session) { create(:session, :absent, user: user) }
        let(:scheduled_session) { create(:session, status: :scheduled, scheduled_at: 1.day.from_now, user: user) }
        let(:newer_note) { create(:patient_note, user: user, created_at: 1.day.ago) }

        context "com o dashboard totalmente preenchido" do
          before do
            completed_session
            absent_session
            scheduled_session
            create(:patient_note, user: user, created_at: 2.days.ago)
            newer_note
          end

          it "retorna 200 com o payload JSON completo do dashboard" do
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

        context "quando há várias sessões futuras agendadas" do
          let!(:earlier_session) { create(:session, status: :scheduled, scheduled_at: 1.day.from_now, user: user) }
          let!(:later_session) { create(:session, :extra, status: :scheduled, scheduled_at: 2.days.from_now, user: user) }

          it "retorna a mais próxima como next_session" do
            get clients_dashboard_path, as: :json
            expect(parsed_response[:next_session][:id]).to eq(earlier_session.id)
          end
        end

        context "quando o usuário não tem sessões futuras agendadas" do
          it "retorna nil em next_session" do
            get clients_dashboard_path, as: :json
            expect(parsed_response[:next_session]).to be_nil
          end
        end

        context "quando a única sessão agendada está no passado" do
          let!(:past_scheduled_session) { create(:session, status: :scheduled, scheduled_at: 1.day.ago, user: user) }

          it "retorna nil em next_session" do
            get clients_dashboard_path, as: :json
            expect(parsed_response[:next_session]).to be_nil
          end
        end
      end
    end
  end
end
