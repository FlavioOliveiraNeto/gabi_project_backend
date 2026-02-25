require 'rails_helper'

RSpec.describe "Therapists::ClinicalNotes", type: :request do
  let(:therapist) { create(:user, :therapist) }
  let(:patient)   { create(:user, :client, therapist: therapist) }
  let(:headers)   { auth_headers_for(therapist) }

  # ─── GET /therapists/patients/:patient_id/notes ───────────────────────────────
  describe "GET /therapists/patients/:patient_id/notes" do
    context "quando autenticado como terapeuta" do
      let!(:own_note)    { create(:clinical_note, user: patient, therapist: therapist, content: "Minha nota") }
      let!(:others_note) do
        other = create(:user, :therapist)
        create(:clinical_note, user: patient, therapist: other, content: "Nota alheia")
      end

      it "retorna 200 apenas com as próprias notas" do
        get "/therapists/patients/#{patient.id}/notes", headers: headers

        expect(response).to have_http_status(:ok)
        expect(json_body.length).to eq(1)
        expect(json_body.first["content"]).to eq("Minha nota")
      end

      it "retorna notas em ordem decrescente de criação" do
        note2 = create(:clinical_note, user: patient, therapist: therapist)
        get "/therapists/patients/#{patient.id}/notes", headers: headers

        ids = json_body.map { |n| n["id"] }
        expect(ids.first).to eq(note2.id)
      end
    end

    context "tentando acessar paciente de outro terapeuta" do
      let(:other_therapist) { create(:user, :therapist) }
      let!(:other_patient)  { create(:user, :client, therapist: other_therapist) }

      it "retorna 404" do
        get "/therapists/patients/#{other_patient.id}/notes", headers: headers
        expect(response).to have_http_status(:not_found)
      end
    end

    context "sem autenticação" do
      it "retorna 401" do
        get "/therapists/patients/#{patient.id}/notes"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "quando autenticado como cliente" do
      let(:client_user) { create(:user, :client, therapist: therapist) }

      it "retorna 403" do
        get "/therapists/patients/#{patient.id}/notes",
            headers: auth_headers_for(client_user)
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  # ─── POST /therapists/patients/:patient_id/notes ──────────────────────────────
  describe "POST /therapists/patients/:patient_id/notes" do
    let(:valid_params) { { content: "Paciente apresentou progresso significativo." } }

    context "com dados válidos" do
      it "cria a nota com status 201" do
        expect {
          post "/therapists/patients/#{patient.id}/notes",
               params: valid_params,
               headers: headers,
               as: :json
        }.to change(ClinicalNote, :count).by(1)

        expect(response).to have_http_status(:created)
      end

      it "associa a nota ao terapeuta autenticado e ao paciente correto" do
        post "/therapists/patients/#{patient.id}/notes",
             params: valid_params,
             headers: headers,
             as: :json

        note = ClinicalNote.last
        expect(note.therapist).to eq(therapist)
        expect(note.user).to eq(patient)
        expect(note.content).to eq(valid_params[:content])
      end

      it "inclui id, content, date e created_at na resposta" do
        post "/therapists/patients/#{patient.id}/notes",
             params: valid_params,
             headers: headers,
             as: :json

        body = json_body
        expect(body).to have_key("id")
        expect(body).to have_key("content")
        expect(body).to have_key("date")
        expect(body).to have_key("created_at")
      end
    end

    context "com conteúdo vazio" do
      it "retorna 422" do
        post "/therapists/patients/#{patient.id}/notes",
             params: { content: "" },
             headers: headers,
             as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_body["errors"]).to be_present
      end
    end

    context "com conteúdo acima de 10.000 caracteres" do
      it "retorna 422" do
        post "/therapists/patients/#{patient.id}/notes",
             params: { content: "a" * 10_001 },
             headers: headers,
             as: :json

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "tentando criar nota para paciente de outro terapeuta" do
      let(:other_therapist) { create(:user, :therapist) }
      let!(:other_patient)  { create(:user, :client, therapist: other_therapist) }

      it "retorna 404 e não cria a nota" do
        expect {
          post "/therapists/patients/#{other_patient.id}/notes",
               params: valid_params,
               headers: headers,
               as: :json
        }.not_to change(ClinicalNote, :count)

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  # ─── GET /therapists/patients/:patient_id/notes/:id ──────────────────────────
  describe "GET /therapists/patients/:patient_id/notes/:id" do
    let!(:note) { create(:clinical_note, user: patient, therapist: therapist) }

    context "nota pertencente ao terapeuta" do
      it "retorna 200 com dados da nota" do
        get "/therapists/patients/#{patient.id}/notes/#{note.id}", headers: headers

        expect(response).to have_http_status(:ok)
        expect(json_body["id"]).to eq(note.id)
      end
    end

    context "nota de outro terapeuta (IDOR)" do
      let(:other_therapist) { create(:user, :therapist) }
      let!(:other_note) do
        create(:clinical_note, user: patient, therapist: other_therapist)
      end

      it "retorna 404" do
        get "/therapists/patients/#{patient.id}/notes/#{other_note.id}", headers: headers
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  # ─── PUT /therapists/patients/:patient_id/notes/:id ──────────────────────────
  describe "PUT /therapists/patients/:patient_id/notes/:id" do
    let!(:note) { create(:clinical_note, user: patient, therapist: therapist, content: "Original") }

    context "atualizando própria nota" do
      it "retorna 200 com nota atualizada" do
        put "/therapists/patients/#{patient.id}/notes/#{note.id}",
            params: { content: "Atualizado" },
            headers: headers,
            as: :json

        expect(response).to have_http_status(:ok)
        expect(note.reload.content).to eq("Atualizado")
      end
    end

    context "tentando editar nota de outro terapeuta (IDOR)" do
      let(:other_therapist) { create(:user, :therapist) }
      let!(:other_note) do
        create(:clinical_note, user: patient, therapist: other_therapist)
      end

      it "retorna 404 e não altera a nota" do
        put "/therapists/patients/#{patient.id}/notes/#{other_note.id}",
            params: { content: "Hackeado" },
            headers: headers,
            as: :json

        expect(response).to have_http_status(:not_found)
        expect(other_note.reload.content).not_to eq("Hackeado")
      end
    end
  end

  # ─── DELETE /therapists/patients/:patient_id/notes/:id ───────────────────────
  describe "DELETE /therapists/patients/:patient_id/notes/:id" do
    let!(:note) { create(:clinical_note, user: patient, therapist: therapist) }

    context "deletando própria nota" do
      it "retorna 204 e remove a nota" do
        expect {
          delete "/therapists/patients/#{patient.id}/notes/#{note.id}", headers: headers
        }.to change(ClinicalNote, :count).by(-1)

        expect(response).to have_http_status(:no_content)
      end
    end

    context "tentando deletar nota de outro terapeuta (IDOR)" do
      let(:other_therapist) { create(:user, :therapist) }
      let!(:other_note) do
        create(:clinical_note, user: patient, therapist: other_therapist)
      end

      it "retorna 404 e não remove a nota" do
        expect {
          delete "/therapists/patients/#{patient.id}/notes/#{other_note.id}", headers: headers
        }.not_to change(ClinicalNote, :count)

        expect(response).to have_http_status(:not_found)
      end
    end

    context "sem autenticação" do
      it "retorna 401" do
        delete "/therapists/patients/#{patient.id}/notes/#{note.id}"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
