require 'rails_helper'

RSpec.describe "Therapists::Sessions", type: :request do
  let(:therapist) { create(:user, :therapist) }
  let(:patient)   { create(:user, :client, therapist: therapist) }
  let(:headers)   { auth_headers_for(therapist) }

  #POST /therapists/sessions 
  describe "POST /therapists/sessions" do
    let(:valid_params) do
      {
        patient_id:   patient.id,
        scheduled_at: 1.week.from_now.noon.iso8601,
        session_type: "extra"
      }
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
             params:  valid_params,
             headers: auth_headers_for(client),
             as:      :json

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "com parâmetros válidos" do
      it "retorna 201 e cria a sessão" do
        expect {
          post therapists_sessions_path, params: valid_params, headers: headers, as: :json
        }.to change(Session, :count).by(1)

        expect(response).to have_http_status(:created)
      end

      context "ao examinar a sessão criada" do
        before { post therapists_sessions_path, params: valid_params, headers: headers, as: :json }

        it "associa ao paciente informado" do
          expect(Session.last.user).to eq(patient)
        end

        it "define o session_type informado" do
          expect(Session.last.session_type).to eq("extra")
        end

        it "define o status como scheduled" do
          expect(Session.last.status).to eq("scheduled")
        end

        it "retorna o shape correto na resposta" do
          expect(json_body).to include("id", "status", "session_type", "scheduled_at")
          expect(json_body["session_type"]).to eq("extra")
          expect(json_body["status"]).to eq("scheduled")
        end
      end
    end

    context "quando session_type é omitido" do
      it "usa 'regular' como padrão e retorna 201" do
        post therapists_sessions_path,
             params:  valid_params.except(:session_type),
             headers: headers,
             as:      :json

        expect(response).to have_http_status(:created)
        expect(Session.last.session_type).to eq("regular")
      end
    end

    context "com session_type 'regular' explícito" do
      it "retorna 201" do
        post therapists_sessions_path,
             params:  valid_params.merge(session_type: "regular"),
             headers: headers,
             as:      :json

        expect(response).to have_http_status(:created)
      end
    end

    context "com tipo de sessão inválido" do
      it "retorna 422 com mensagem de erro" do
        post therapists_sessions_path,
             params:  valid_params.merge(session_type: "invalido"),
             headers: headers,
             as:      :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_body["error"]).to match(/Tipo de sessão inválido/)
      end
    end

    context "com conflito de horário" do
      let(:patient_b)       { create(:user, :client, therapist: therapist) }
      let(:conflicting_time) { 1.week.from_now.noon }

      before do
        create(:session, user: patient_b, scheduled_at: conflicting_time, status: :scheduled)
      end

      it "retorna 422 com mensagem de conflito" do
        post therapists_sessions_path,
             params:  {
               patient_id:   patient.id,
               scheduled_at: (conflicting_time + 30.minutes).iso8601,
               session_type: "extra"
             },
             headers: headers,
             as:      :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_body["errors"].first).to match(/conflita/)
      end
    end

    context "tentando criar sessão para paciente de outro terapeuta" do
      let(:other_therapist) { create(:user, :therapist) }
      let!(:other_patient)  { create(:user, :client, therapist: other_therapist) }

      it "retorna 404" do
        post therapists_sessions_path,
             params:  valid_params.merge(patient_id: other_patient.id),
             headers: headers,
             as:      :json

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  #PUT /therapists/sessions/:id 
  describe "PUT /therapists/sessions/:id" do
    context "sem autenticação" do
      let!(:session) { create(:session, user: patient, status: :scheduled, scheduled_at: 1.week.from_now) }

      it "retorna 401" do
        put therapists_session_path(session), params: { status: "cancelled" }, as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "quando autenticado como cliente" do
      let!(:session) { create(:session, user: patient, status: :scheduled, scheduled_at: 1.week.from_now) }
      let(:client)   { create(:user, :client, therapist: therapist) }

      it "retorna 403" do
        put therapists_session_path(session),
            params:  { status: "cancelled" },
            headers: auth_headers_for(client),
            as:      :json

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "sessão não encontrada" do
      it "retorna 404" do
        put therapists_session_path(0),
            params:  { status: "cancelled" },
            headers: headers,
            as:      :json

        expect(response).to have_http_status(:not_found)
      end
    end

    context "transições válidas" do
      [
        { desc: "scheduled → cancelled", from: :scheduled, to: "cancelled", past: false },
        { desc: "completed → absent",    from: :completed, to: "absent",    past: true  },
        { desc: "completed → cancelled", from: :completed, to: "cancelled", past: true  },
        { desc: "absent → cancelled",    from: :absent,    to: "cancelled", past: true  }
      ].each do |t|
        context t[:desc] do
          let!(:session) do
            create(:session,
                   user:         patient,
                   status:       t[:from],
                   scheduled_at: t[:past] ? 1.week.ago : 1.week.from_now)
          end

          it "retorna 200 e atualiza o status no banco" do
            put therapists_session_path(session),
                params:  { status: t[:to] },
                headers: headers,
                as:      :json

            expect(response).to have_http_status(:ok)
            expect(session.reload.status).to eq(t[:to])
          end
        end
      end
    end

    context "status não permitido à terapeuta" do
      let!(:session) { create(:session, user: patient, status: :scheduled, scheduled_at: 1.week.from_now) }

      %w[scheduled completed foo].each do |status|
        it "retorna 422 com 'Status inválido' para status '#{status}'" do
          put therapists_session_path(session),
              params:  { status: status },
              headers: headers,
              as:      :json

          expect(response).to have_http_status(:unprocessable_content)
          expect(json_body["error"]).to match(/Status inválido/)
        end
      end
    end

    context "transições inválidas (regra de negócio)" do
      context "tentando marcar falta em sessão agendada (não finalizada)" do
        let!(:session) { create(:session, user: patient, status: :scheduled, scheduled_at: 1.week.from_now) }

        it "retorna 422 com 'Transição inválida' e preserva o status" do
          put therapists_session_path(session),
              params:  { status: "absent" },
              headers: headers,
              as:      :json

          expect(response).to have_http_status(:unprocessable_content)
          expect(json_body["error"]).to match(/Transição inválida/)
          expect(session.reload.status).to eq("scheduled")
        end
      end

      context "tentando alterar sessão já cancelada" do
        let!(:session) { create(:session, user: patient, status: :cancelled, scheduled_at: 1.week.ago) }

        it "retorna 422 com 'Transição inválida' para status 'absent'" do
          put therapists_session_path(session),
              params:  { status: "absent" },
              headers: headers,
              as:      :json

          expect(response).to have_http_status(:unprocessable_content)
          expect(json_body["error"]).to match(/Transição inválida/)
        end
      end
    end

    context "tentando atualizar sessão de paciente de outro terapeuta (IDOR)" do
      let(:other_therapist) { create(:user, :therapist) }
      let!(:other_patient)  { create(:user, :client, therapist: other_therapist) }
      let!(:other_session)  do
        create(:session, user: other_patient, status: :scheduled, scheduled_at: 1.week.from_now)
      end

      it "retorna 404 e não altera o status" do
        put therapists_session_path(other_session),
            params:  { status: "cancelled" },
            headers: headers,
            as:      :json

        expect(response).to have_http_status(:not_found)
        expect(other_session.reload.status).to eq("scheduled")
      end
    end
  end

  #DELETE /therapists/sessions/:id ─
  describe "DELETE /therapists/sessions/:id" do
    let!(:session) { create(:session, user: patient, status: :scheduled, scheduled_at: 1.week.from_now) }

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
               as:      :json

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "sessão não encontrada" do
      it "retorna 404" do
        delete therapists_session_path(0), headers: headers, as: :json
        expect(response).to have_http_status(:not_found)
      end
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
        context "quando status é #{status}" do
          before { session.update_column(:status, Session.statuses[status]) }

          it "retorna 204 e remove a sessão" do
            expect {
              delete therapists_session_path(session), headers: headers, as: :json
            }.to change(Session, :count).by(-1)

            expect(response).to have_http_status(:no_content)
          end
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
  end
end
