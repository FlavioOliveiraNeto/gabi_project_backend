require 'rails_helper'

RSpec.describe "Therapists::Patients", type: :request do
  include_context "autenticado como terapeuta"

  #GET /therapists/patients 
  describe "GET /therapists/patients" do
    let!(:patient1) { create(:user, :client, therapist: therapist) }
    let!(:patient2) { create(:user, :client, therapist: therapist) }

    context "autenticado como terapeuta" do
      before { get therapists_patients_path, headers: headers }

      it "retorna 200" do
        expect(response).to have_http_status(:ok)
      end

      it "retorna a lista com os próprios pacientes" do
        expect(json_body.map { |p| p["id"] }).to contain_exactly(patient1.id, patient2.id)
      end

      it "inclui os campos básicos do paciente" do
        expect(json_body.first).to include("id", "name", "email", "schedule_type", "clinical_notes")
      end
    end

    context "com paciente de outro terapeuta" do
      it "não inclui pacientes de outros terapeutas" do
        other_therapist = create(:user, :therapist)
        create(:user, :client, therapist: other_therapist)

        get therapists_patients_path, headers: headers

        expect(json_body.map { |p| p["id"] }).to contain_exactly(patient1.id, patient2.id)
      end
    end

    context "sem autenticação" do
      it "retorna 401" do
        get therapists_patients_path
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "quando autenticado como cliente" do
      let(:client) { create(:user, :client, therapist: therapist) }

      it "retorna 403" do
        get therapists_patients_path, headers: auth_headers_for(client)
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  #GET /therapists/patients/:id 
  describe "GET /therapists/patients/:id" do
    let!(:patient) { create(:user, :client, therapist: therapist) }

    context "com paciente que pertence ao terapeuta" do
      before { get therapists_patient_path(patient), headers: headers }

      it "retorna 200" do
        expect(response).to have_http_status(:ok)
      end

      it "inclui o shape completo de patient_json" do
        expect(json_body).to include(
          "id", "name", "email", "google_meet_link", "created_at",
          "schedule_type", "sessions_per_week", "session_days", "session_time",
          "completed_sessions", "absent_sessions", "extra_sessions", "clinical_notes"
        )
        expect(json_body["id"]).to eq(patient.id)
        expect(json_body["name"]).to eq(patient.name)
      end
    end

    context "tentando acessar paciente de outro terapeuta (IDOR)" do
      let(:other_therapist) { create(:user, :therapist) }
      let!(:other_patient)  { create(:user, :client, therapist: other_therapist) }

      it "retorna 404" do
        get therapists_patient_path(other_patient), headers: headers
        expect(response).to have_http_status(:not_found)
      end
    end

    context "sem autenticação" do
      it "retorna 401" do
        get therapists_patient_path(patient)
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "quando autenticado como cliente" do
      let(:client) { create(:user, :client, therapist: therapist) }

      it "retorna 403" do
        get therapists_patient_path(patient), headers: auth_headers_for(client)
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  #POST /therapists/patients 
  describe "POST /therapists/patients" do
    let(:base_params) do
      { name: "Novo Paciente", email: "novo@paciente.com" }
    end

    context "sem agendamento" do
      before do
        post therapists_patients_path, params: base_params, headers: headers, as: :json
      end

      it "retorna 201 e cria o paciente" do
        expect(response).to have_http_status(:created)
        expect(User.find_by(email: "novo@paciente.com")).to be_present
      end

      it "define must_change_password como true" do
        patient = User.find_by(email: "novo@paciente.com")
        expect(patient.must_change_password).to be true
      end

      it "retorna a senha gerada" do
        expect(json_body["generated_password"]).to be_present
        expect(json_body["generated_password"].length).to be >= 8
      end
    end

    context "com agenda regular" do
      let(:params_with_regular) do
        base_params.merge(
          schedule_type:     "regular",
          weekdays:          ["monday", "wednesday"],
          sessions_per_week: 2,
          session_time:      "10:00"
        )
      end

      it "cria o paciente e os weekly_schedules" do
        travel_to Time.zone.local(2026, 3, 1) do
          expect {
            post therapists_patients_path, params: params_with_regular, headers: headers, as: :json
          }.to change(WeeklySchedule, :count).by(2)
        end
      end

      it "gera sessões a partir de hoje" do
        travel_to Time.zone.local(2026, 3, 1) do
          expect {
            post therapists_patients_path, params: params_with_regular, headers: headers, as: :json
          }.to change(Session, :count).by_at_least(1)
        end
      end
    end

    context "com agenda extra" do
      let(:params_with_extra) do
        base_params.merge(
          schedule_type: "extra",
          single_date:   "2026-03-15",
          single_time:   "14:00"
        )
      end

      it "cria o paciente e uma sessão extra" do
        expect {
          post therapists_patients_path, params: params_with_extra, headers: headers, as: :json
        }.to change(Session, :count).by(1)

        expect(Session.last.session_type).to eq("extra")
      end
    end

    context "com dados inválidos" do
      it "retorna 422 sem email" do
        post therapists_patients_path,
             params: { name: "Sem Email" },
             headers: headers,
             as: :json

        expect(response).to have_http_status(:unprocessable_content)
      end

      it "retorna 422 com agenda regular sem weekdays" do
        travel_to Time.zone.local(2026, 3, 1) do
          post therapists_patients_path,
               params: base_params.merge(schedule_type: "regular", weekdays: [], session_time: "10:00"),
               headers: headers,
               as: :json

          expect(response).to have_http_status(:unprocessable_content)
        end
      end

      it "retorna 422 com email já cadastrado" do
        create(:user, email: "novo@paciente.com")

        post therapists_patients_path,
             params: base_params,
             headers: headers,
             as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_body["errors"]).to be_present
      end
    end

    context "quando o serviço de agenda falha" do
      before do
        allow_any_instance_of(ScheduleChangeService).to receive(:call)
          .and_raise(ScheduleChangeService::Error, "Conflito de horário")
      end

      it "retorna 422 com mensagem de erro" do
        post therapists_patients_path,
             params: base_params.merge(schedule_type: "regular", weekdays: ["monday"], session_time: "10:00"),
             headers: headers,
             as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_body["error"]).to be_present
      end
    end

    context "sem autenticação" do
      it "retorna 401" do
        post therapists_patients_path, params: base_params, as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "quando autenticado como cliente" do
      let(:client) { create(:user, :client, therapist: therapist) }

      it "retorna 403" do
        post therapists_patients_path,
             params: base_params,
             headers: auth_headers_for(client),
             as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  #PUT /therapists/patients/:id 
  describe "PUT /therapists/patients/:id" do
    let!(:patient) { create(:user, :client, therapist: therapist) }

    context "atualizando dados básicos" do
      it "retorna 200 com nome atualizado" do
        put therapists_patient_path(patient),
            params: { name: "Nome Atualizado" },
            headers: headers,
            as: :json

        expect(response).to have_http_status(:ok)
        expect(patient.reload.name).to eq("Nome Atualizado")
      end
    end

    context "com dados inválidos" do
      it "retorna 422 com email já cadastrado" do
        create(:user, email: "ocupado@exemplo.com")

        put therapists_patient_path(patient),
            params: { email: "ocupado@exemplo.com" },
            headers: headers,
            as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_body["errors"]).to be_present
      end
    end

    context "tentando editar paciente de outro terapeuta (IDOR)" do
      let(:other_therapist) { create(:user, :therapist) }
      let!(:other_patient)  { create(:user, :client, therapist: other_therapist) }

      it "retorna 404" do
        put therapists_patient_path(other_patient),
            params: { name: "Hackeado" },
            headers: headers,
            as: :json

        expect(response).to have_http_status(:not_found)
      end
    end

    context "sem autenticação" do
      it "retorna 401" do
        put therapists_patient_path(patient), params: { name: "Teste" }, as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "quando autenticado como cliente" do
      let(:client) { create(:user, :client, therapist: therapist) }

      it "retorna 403" do
        put therapists_patient_path(patient),
            params: { name: "Teste" },
            headers: auth_headers_for(client),
            as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  #PUT /therapists/patients/:id/update_schedule 
  describe "PUT /therapists/patients/:id/update_schedule" do
    let!(:patient) { create(:user, :client, therapist: therapist) }

    context "transição para agenda regular" do
      it "cria weekly_schedules e cancela sessões futuras anteriores" do
        future_session = create(
          :session, user: patient, status: :scheduled,
          scheduled_at: 2.weeks.from_now, session_type: :regular
        )

        travel_to Time.zone.local(2026, 3, 1) do
          put update_schedule_therapists_patient_path(patient),
              params: {
                schedule_type:     "regular",
                weekdays:          ["tuesday"],
                sessions_per_week: 1,
                session_time:      "09:00",
                effective_from:    "2026-03-08"
              },
              headers: headers,
              as: :json
        end

        expect(response).to have_http_status(:ok)
        expect(future_session.reload.status).to eq("cancelled")
      end
    end

    context "transição para extra (nova sessão)" do
      it "cria uma nova sessão extra" do
        expect {
          put update_schedule_therapists_patient_path(patient),
              params: {
                schedule_type: "extra",
                single_date:   "2026-05-10",
                single_time:   "14:00"
              },
              headers: headers,
              as: :json
        }.to change(Session, :count).by(1)

        expect(response).to have_http_status(:ok)
        expect(Session.last.session_type).to eq("extra")
      end
    end

    context "atualização de sessão extra existente" do
      let!(:extra_session) do
        create(:session, user: patient, session_type: :extra, status: :scheduled,
               scheduled_at: 2.weeks.from_now.noon)
      end

      it "atualiza o horário da sessão sem criar nova" do
        new_date = (2.weeks.from_now + 1.day).to_date.iso8601

        expect {
          put update_schedule_therapists_patient_path(patient),
              params: {
                schedule_type: "extra",
                session_id:    extra_session.id,
                single_date:   new_date,
                single_time:   "15:00"
              },
              headers: headers,
              as: :json
        }.not_to change(Session, :count)

        expect(response).to have_http_status(:ok)
        expect(extra_session.reload.scheduled_at.strftime("%H:%M")).to eq("15:00")
      end
    end

    context "com schedule_type inválido" do
      it "retorna 422 com mensagem de erro" do
        put update_schedule_therapists_patient_path(patient),
            params: { schedule_type: "invalido" },
            headers: headers,
            as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_body["error"]).to be_present
      end
    end

    context "quando o serviço de agenda falha" do
      before do
        allow_any_instance_of(ScheduleChangeService).to receive(:call)
          .and_raise(ScheduleChangeService::Error, "Conflito de horário")
      end

      it "retorna 422 com mensagem de erro" do
        put update_schedule_therapists_patient_path(patient),
            params: {
              schedule_type:     "regular",
              weekdays:          ["monday"],
              sessions_per_week: 1,
              session_time:      "09:00"
            },
            headers: headers,
            as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_body["error"]).to eq("Conflito de horário")
      end
    end

    context "tentando atualizar agenda de paciente de outro terapeuta (IDOR)" do
      let(:other_therapist) { create(:user, :therapist) }
      let!(:other_patient)  { create(:user, :client, therapist: other_therapist) }

      it "retorna 404" do
        put update_schedule_therapists_patient_path(other_patient),
            params: { schedule_type: "regular", weekdays: ["monday"], session_time: "09:00" },
            headers: headers,
            as: :json

        expect(response).to have_http_status(:not_found)
      end
    end

    context "sem autenticação" do
      it "retorna 401" do
        put update_schedule_therapists_patient_path(patient),
            params: { schedule_type: "regular" },
            as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "quando autenticado como cliente" do
      let(:client) { create(:user, :client, therapist: therapist) }

      it "retorna 403" do
        put update_schedule_therapists_patient_path(patient),
            params: { schedule_type: "regular" },
            headers: auth_headers_for(client),
            as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  #DELETE /therapists/patients/:id 
  describe "DELETE /therapists/patients/:id" do
    let!(:patient) { create(:user, :client, therapist: therapist) }

    context "deletando próprio paciente" do
      it "retorna 204 e remove o paciente" do
        expect {
          delete therapists_patient_path(patient), headers: headers
        }.to change(User, :count).by(-1)

        expect(response).to have_http_status(:no_content)
      end

      it "remove em cascata as sessões do paciente" do
        create(:session, user: patient)

        expect {
          delete therapists_patient_path(patient), headers: headers
        }.to change(Session, :count).by(-1)
      end
    end

    context "tentando deletar paciente de outro terapeuta (IDOR)" do
      let(:other_therapist) { create(:user, :therapist) }
      let!(:other_patient)  { create(:user, :client, therapist: other_therapist) }

      it "retorna 404 e não remove o paciente" do
        expect {
          delete therapists_patient_path(other_patient), headers: headers
        }.not_to change(User, :count)

        expect(response).to have_http_status(:not_found)
      end
    end

    context "sem autenticação" do
      it "retorna 401" do
        delete therapists_patient_path(patient)
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "quando autenticado como cliente" do
      let(:client) { create(:user, :client, therapist: therapist) }

      it "retorna 403" do
        delete therapists_patient_path(patient), headers: auth_headers_for(client)
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
