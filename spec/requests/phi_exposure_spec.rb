require 'rails_helper'

RSpec.describe "Exposição de PHI e limites de payload", type: :request do
  let(:therapist) { create(:user, :therapist) }
  let(:patient)   { create(:user, :client, therapist: therapist) }
  let(:headers)   { therapist_auth_headers(therapist) }

  describe "Cache-Control em respostas autenticadas" do
    it "envia no-store no dashboard da terapeuta" do
      get therapists_dashboard_path, headers: headers

      expect(response.headers["Cache-Control"]).to eq("no-store")
    end

    it "envia no-store no dashboard do cliente" do
      client_headers = patient_auth_headers(patient)

      get clients_dashboard_path, headers: client_headers

      expect(response.headers["Cache-Control"]).to eq("no-store")
    end

    it "envia no-store nas notas clínicas" do
      get therapists_patient_clinical_notes_path(patient), headers: headers

      expect(response.headers["Cache-Control"]).to eq("no-store")
    end

    it "envia no-store no login" do
      post user_session_path,
           params: { user: { email: patient.email, password: patient.password } },
           as: :json

      expect(response.headers["Cache-Control"]).to eq("no-store")
    end

    it "envia Pragma: no-cache para proxies antigos" do
      get therapists_dashboard_path, headers: headers

      expect(response.headers["Pragma"]).to eq("no-cache")
    end
  end

  describe "conteúdo das notas clínicas fora das listagens" do
    let!(:note) do
      create(:clinical_note, user: patient, therapist: therapist,
             content: "PHI-SENSIVEL-NAO-DEVE-VAZAR")
    end

    it "não aparece no dashboard da terapeuta" do
      get therapists_dashboard_path, headers: headers

      expect(response.body).not_to include("PHI-SENSIVEL-NAO-DEVE-VAZAR")
    end

    it "não aparece na listagem de pacientes" do
      get therapists_patients_path, headers: headers

      expect(response.body).not_to include("PHI-SENSIVEL-NAO-DEVE-VAZAR")
    end

    it "não aparece na ficha individual do paciente" do
      get therapists_patient_path(patient), headers: headers

      expect(response.body).not_to include("PHI-SENSIVEL-NAO-DEVE-VAZAR")
    end

    it "continua acessível pelo endpoint dedicado de notas" do
      get therapists_patient_clinical_notes_path(patient), headers: headers

      expect(response.body).to include("PHI-SENSIVEL-NAO-DEVE-VAZAR")
    end

    it "expõe a contagem para a UI, sem o conteúdo" do
      get therapists_patients_path, headers: headers

      expect(json_body.first["clinical_notes_count"]).to eq(1)
    end
  end

  describe "paginação nas listagens" do
    describe "GET /clients/sessions" do
      let(:client_headers) { patient_auth_headers(patient) }

      before do
        60.times do |i|
          slot = (i + 1).days.from_now.beginning_of_hour
          create(:session, user: patient, scheduled_at: slot,
                 start_time: slot, end_time: slot + 50.minutes)
        end
      end

      it "limita a resposta ao tamanho de página padrão" do
        get clients_sessions_path, headers: client_headers

        expect(json_body.size).to eq(ApplicationController::DEFAULT_PAGE_SIZE)
      end

      it "respeita o parâmetro limit" do
        get clients_sessions_path, params: { limit: 10 }, headers: client_headers

        expect(json_body.size).to eq(10)
      end

      it "impõe um teto ao limit para o parâmetro não virar DoS de novo" do
        get clients_sessions_path, params: { limit: 100_000 }, headers: client_headers

        expect(json_body.size).to be <= ApplicationController::MAX_PAGE_SIZE
      end

      it "pagina por offset" do
        get clients_sessions_path, params: { limit: 5 }, headers: client_headers
        first_page = json_body.map { |s| s["id"] }

        get clients_sessions_path, params: { limit: 5, offset: 5 }, headers: client_headers
        second_page = json_body.map { |s| s["id"] }

        expect(first_page & second_page).to be_empty
      end

      it "mantém a ordem crescente de scheduled_at dentro da página" do
        get clients_sessions_path, headers: client_headers
        dates = json_body.map { |s| s["scheduled_at"] }

        expect(dates).to eq(dates.sort)
      end

      it "ignora limit inválido e usa o padrão" do
        get clients_sessions_path, params: { limit: "abc" }, headers: client_headers

        expect(json_body.size).to eq(ApplicationController::DEFAULT_PAGE_SIZE)
      end

      it "trata offset negativo como zero" do
        get clients_sessions_path, params: { limit: 5, offset: -10 }, headers: client_headers

        expect(response).to have_http_status(:ok)
        expect(json_body.size).to eq(5)
      end
    end

    describe "GET /clients/patient_notes" do
      let(:client_headers) { patient_auth_headers(patient) }

      before { 60.times { |i| create(:patient_note, user: patient, content: "nota #{i}") } }

      it "limita a resposta ao tamanho de página padrão" do
        get clients_patient_notes_path, headers: client_headers

        expect(json_body.size).to eq(ApplicationController::DEFAULT_PAGE_SIZE)
      end

      it "não expõe user_id na serialização" do
        get clients_patient_notes_path, headers: client_headers

        expect(json_body.first).not_to have_key("user_id")
      end
    end
  end

  describe "janela do calendário no dashboard" do
    it "não inclui sessões muito antigas por padrão" do
      old_slot = 2.years.ago.beginning_of_hour
      create(:session, user: patient, scheduled_at: old_slot,
             start_time: old_slot, end_time: old_slot + 50.minutes, status: :completed)

      get therapists_dashboard_path, headers: headers

      expect(json_body["calendar_sessions"]).to be_empty
    end

    it "inclui sessões próximas de hoje" do
      slot = 2.days.from_now.beginning_of_hour
      create(:session, user: patient, scheduled_at: slot,
             start_time: slot, end_time: slot + 50.minutes)

      get therapists_dashboard_path, headers: headers

      expect(json_body["calendar_sessions"].size).to eq(1)
    end

    it "aceita uma janela explícita via from/to" do
      old_slot = 1.year.ago.beginning_of_hour
      create(:session, user: patient, scheduled_at: old_slot,
             start_time: old_slot, end_time: old_slot + 50.minutes, status: :completed)

      get therapists_dashboard_path,
          params: { from: (old_slot - 1.day).to_date.iso8601, to: (old_slot + 1.day).to_date.iso8601 },
          headers: headers

      expect(json_body["calendar_sessions"].size).to eq(1)
    end

    it "limita a janela solicitada a 12 meses" do
      get therapists_dashboard_path,
          params: { from: 10.years.ago.to_date.iso8601, to: Date.current.iso8601 },
          headers: headers

      expect(response).to have_http_status(:ok)
    end

    it "ignora datas inválidas e usa a janela padrão" do
      get therapists_dashboard_path, params: { from: "nao-e-data" }, headers: headers

      expect(response).to have_http_status(:ok)
    end

    it "continua contando as stats fora da janela do calendário" do
      slot = Time.zone.now.beginning_of_hour + 1.hour
      create(:session, user: patient, scheduled_at: slot,
             start_time: slot, end_time: slot + 50.minutes)

      get therapists_dashboard_path,
          params: { from: 5.years.ago.to_date.iso8601, to: 4.years.ago.to_date.iso8601 },
          headers: headers

      expect(json_body["stats"]["sessions_today"]).to eq(1)
    end
  end
end
