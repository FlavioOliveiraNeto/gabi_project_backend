require 'rails_helper'

RSpec.describe "Therapists::Sessions", type: :request do
  let(:therapist) { create(:user, :therapist) }
  let(:patient)   { create(:user, :client, therapist: therapist) }
  let(:headers)   { auth_headers_for(therapist) }

  # ─── POST /therapists/sessions ────────────────────────────────────────────────
  describe "POST /therapists/sessions" do
    let(:valid_params) do
      {
        patient_id:   patient.id,
        scheduled_at: 1.week.from_now.noon.iso8601,
        session_type: "extra"
      }
    end

    context "criando sessão extra válida" do
      it "retorna 201 com a sessão criada" do
        expect {
          post therapists_sessions_path, params: valid_params, headers: headers, as: :json
        }.to change(Session, :count).by(1)

        expect(response).to have_http_status(:created)
      end

      it "associa a sessão ao paciente correto" do
        post therapists_sessions_path, params: valid_params, headers: headers, as: :json

        session = Session.last
        expect(session.user).to eq(patient)
        expect(session.session_type).to eq("extra")
        expect(session.status).to eq("scheduled")
      end
    end

    context "criando sessão regular" do
      it "retorna 201" do
        post therapists_sessions_path,
             params: valid_params.merge(session_type: "regular"),
             headers: headers,
             as: :json

        expect(response).to have_http_status(:created)
      end
    end

    context "com tipo de sessão inválido" do
      it "retorna 422" do
        post therapists_sessions_path,
             params: valid_params.merge(session_type: "invalido"),
             headers: headers,
             as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_body["error"]).to match(/Tipo de sessão inválido/)
      end
    end

    context "com conflito de horário" do
      let(:patient_b) { create(:user, :client, therapist: therapist) }
      let(:conflicting_time) { 1.week.from_now.noon }

      before do
        create(:session, user: patient_b, scheduled_at: conflicting_time, status: :scheduled)
      end

      it "retorna 422 com mensagem de conflito" do
        post therapists_sessions_path,
             params: {
               patient_id:   patient.id,
               scheduled_at: (conflicting_time + 30.minutes).iso8601,
               session_type: "extra"
             },
             headers: headers,
             as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_body["errors"].first).to match(/conflita/)
      end
    end

    context "tentando criar sessão para paciente de outro terapeuta" do
      let(:other_therapist) { create(:user, :therapist) }
      let!(:other_patient)  { create(:user, :client, therapist: other_therapist) }

      it "retorna 404" do
        post therapists_sessions_path,
             params: valid_params.merge(patient_id: other_patient.id),
             headers: headers,
             as: :json

        expect(response).to have_http_status(:not_found)
      end
    end

    context "sem autenticação" do
      it "retorna 401" do
        post therapists_sessions_path, params: valid_params, as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "quando autenticado como cliente" do
      let(:client) { create(:user, :client, therapist: therapist) }

      it "retorna 403" do
        post therapists_sessions_path,
             params: valid_params,
             headers: auth_headers_for(client),
             as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  # ─── PUT /therapists/sessions/:id ────────────────────────────────────────────
  describe "PUT /therapists/sessions/:id" do
    context "transições válidas" do
      context "de scheduled para cancelled" do
        let!(:session) do
          create(:session, user: patient, status: :scheduled, scheduled_at: 1.week.from_now)
        end

        it "retorna 200 com status atualizado" do
          put therapists_session_path(session),
              params: { status: "cancelled" },
              headers: headers,
              as: :json

          expect(response).to have_http_status(:ok)
          expect(session.reload.status).to eq("cancelled")
        end
      end

      context "de completed para absent" do
        let!(:session) do
          create(:session, user: patient, status: :completed, scheduled_at: 1.week.ago)
        end

        it "retorna 200" do
          put therapists_session_path(session),
              params: { status: "absent" },
              headers: headers,
              as: :json

          expect(response).to have_http_status(:ok)
          expect(session.reload.status).to eq("absent")
        end
      end

      context "de completed para cancelled" do
        let!(:session) do
          create(:session, user: patient, status: :completed, scheduled_at: 1.week.ago)
        end

        it "retorna 200" do
          put therapists_session_path(session),
              params: { status: "cancelled" },
              headers: headers,
              as: :json

          expect(response).to have_http_status(:ok)
          expect(session.reload.status).to eq("cancelled")
        end
      end

      context "de absent para cancelled" do
        let!(:session) do
          create(:session, user: patient, status: :absent, scheduled_at: 1.week.ago)
        end

        it "retorna 200" do
          put therapists_session_path(session),
              params: { status: "cancelled" },
              headers: headers,
              as: :json

          expect(response).to have_http_status(:ok)
        end
      end
    end

    context "transições inválidas (regra de negócio)" do
      context "tentando marcar falta em sessão agendada (não finalizada)" do
        let!(:session) do
          create(:session, user: patient, status: :scheduled, scheduled_at: 1.week.from_now)
        end

        it "retorna 422 — falta só é permitida após a sessão ser finalizada" do
          put therapists_session_path(session),
              params: { status: "absent" },
              headers: headers,
              as: :json

          expect(response).to have_http_status(:unprocessable_content)
          expect(json_body["error"]).to match(/Transição inválida/)
          expect(session.reload.status).to eq("scheduled")
        end
      end

      context "tentando marcar como completed manualmente" do
        let!(:session) do
          create(:session, user: patient, status: :scheduled, scheduled_at: 1.week.from_now)
        end

        it "retorna 422 — completed é exclusivo do auto-complete job" do
          put therapists_session_path(session),
              params: { status: "completed" },
              headers: headers,
              as: :json

          expect(response).to have_http_status(:unprocessable_content)
          expect(json_body["error"]).to match(/Status inválido/)
        end
      end

      context "tentando marcar como scheduled manualmente" do
        let!(:session) do
          create(:session, user: patient, status: :completed, scheduled_at: 1.week.ago)
        end

        it "retorna 422" do
          put therapists_session_path(session),
              params: { status: "scheduled" },
              headers: headers,
              as: :json

          expect(response).to have_http_status(:unprocessable_content)
        end
      end

      context "sessão já cancelled não pode ser alterada" do
        let!(:session) do
          create(:session, user: patient, status: :cancelled, scheduled_at: 1.week.ago)
        end

        it "retorna 422 para qualquer status" do
          %w[absent scheduled completed].each do |status|
            put therapists_session_path(session),
                params: { status: status },
                headers: headers,
                as: :json

            expect(response).to have_http_status(:unprocessable_content)
          end
        end
      end
    end

    context "tentando atualizar sessão de paciente de outro terapeuta (IDOR)" do
      let(:other_therapist) { create(:user, :therapist) }
      let!(:other_patient)  { create(:user, :client, therapist: other_therapist) }
      let!(:other_session)  do
        create(:session, user: other_patient, status: :scheduled, scheduled_at: 1.week.from_now)
      end

      it "retorna 404" do
        put therapists_session_path(other_session),
            params: { status: "cancelled" },
            headers: headers,
            as: :json

        expect(response).to have_http_status(:not_found)
        expect(other_session.reload.status).to eq("scheduled")
      end
    end

    context "sem autenticação" do
      let!(:session) { create(:session, user: patient, status: :scheduled, scheduled_at: 1.week.from_now) }

      it "retorna 401" do
        put therapists_session_path(session), params: { status: "cancelled" }, as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # ─── DELETE /therapists/sessions/:id ─────────────────────────────────────────
  describe "DELETE /therapists/sessions/:id" do
    let!(:session) do
      create(:session, user: patient, status: :scheduled, scheduled_at: 1.week.from_now)
    end

    context "excluindo sessão do próprio paciente" do
      it "retorna 204 e remove a sessão" do
        expect {
          delete therapists_session_path(session), headers: headers, as: :json
        }.to change(Session, :count).by(-1)

        expect(response).to have_http_status(:no_content)
      end
    end

    context "excluindo sessão com qualquer status" do
      %i[completed absent cancelled].each do |status|
        it "retorna 204 para sessão com status #{status}" do
          session.update_column(:status, Session.statuses[status])

          expect {
            delete therapists_session_path(session), headers: headers, as: :json
          }.to change(Session, :count).by(-1)

          expect(response).to have_http_status(:no_content)
        end
      end
    end

    context "tentando excluir sessão de paciente de outro terapeuta (IDOR)" do
      let(:other_therapist) { create(:user, :therapist) }
      let!(:other_patient)  { create(:user, :client, therapist: other_therapist) }
      let!(:other_session)  do
        create(:session, user: other_patient, status: :scheduled, scheduled_at: 1.week.from_now)
      end

      it "retorna 404 e não exclui a sessão" do
        expect {
          delete therapists_session_path(other_session), headers: headers, as: :json
        }.not_to change(Session, :count)

        expect(response).to have_http_status(:not_found)
      end
    end

    context "sem autenticação" do
      it "retorna 401" do
        delete therapists_session_path(session), as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "quando autenticado como cliente" do
      let(:client) { create(:user, :client, therapist: therapist) }

      it "retorna 403" do
        delete therapists_session_path(session),
               headers: auth_headers_for(client),
               as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
