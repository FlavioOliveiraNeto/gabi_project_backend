require 'rails_helper'

RSpec.describe "Clients::PatientNotes", type: :request do
  let(:therapist) { create(:user, :therapist) }
  let(:client)    { create(:user, :client, therapist: therapist) }
  let(:headers)   { auth_headers_for(client) }

  #GET /clients/patient_notes
  describe "GET /clients/patient_notes" do
    context "quando não há notas" do
      it "retorna 200 com lista vazia" do
        get clients_patient_notes_path, headers: headers

        expect(response).to have_http_status(:ok)
        expect(json_body).to eq([])
      end
    end

    context "quando há notas" do
      let!(:note1) { create(:patient_note, user: client, content: "Primeira nota") }
      let!(:note2) { create(:patient_note, user: client, content: "Segunda nota") }

      before { get clients_patient_notes_path, headers: headers }

      it "retorna 200" do
        expect(response).to have_http_status(:ok)
      end

      it "retorna todas as notas do cliente autenticado" do
        ids = json_body.map { |n| n["id"] }
        expect(ids).to include(note1.id, note2.id)
        expect(ids.length).to eq(2)
      end

      it "retorna em ordem decrescente de criação" do
        expect(json_body.first["id"]).to eq(note2.id)
      end
    end

    context "isolamento entre clientes" do
      let!(:note1) { create(:patient_note, user: client, content: "Minha nota") }
      let(:other_client) { create(:user, :client, therapist: therapist) }
      let!(:other_note)  { create(:patient_note, user: other_client, content: "Nota de outro") }

      it "retorna apenas as notas do cliente autenticado" do
        get clients_patient_notes_path, headers: headers

        ids = json_body.map { |n| n["id"] }
        expect(ids).to include(note1.id)
        expect(ids).not_to include(other_note.id)
      end
    end

    context "sem autenticação" do
      it "retorna 401" do
        get clients_patient_notes_path
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "quando autenticado como terapeuta" do
      it "retorna 403" do
        get clients_patient_notes_path, headers: auth_headers_for(therapist)
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  #POST /clients/patient_notes
  describe "POST /clients/patient_notes" do
    let(:valid_params) { { content: "Minha anotação sobre a sessão de hoje." } }

    context "com dados válidos" do
      it "cria a nota com status 201" do
        expect {
          post clients_patient_notes_path, params: valid_params, headers: headers, as: :json
        }.to change(PatientNote, :count).by(1)

        expect(response).to have_http_status(:created)
      end

      it "associa a nota ao cliente autenticado" do
        post clients_patient_notes_path, params: valid_params, headers: headers, as: :json

        note = PatientNote.last
        expect(note.user).to eq(client)
        expect(note.content).to eq(valid_params[:content])
      end
    end

    context "com conteúdo vazio" do
      it "retorna 422" do
        post clients_patient_notes_path,
             params: { content: "" },
             headers: headers,
             as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_body["errors"]).to be_present
      end
    end

    context "com conteúdo acima de 10.000 caracteres" do
      it "retorna 422" do
        post clients_patient_notes_path,
             params: { content: "a" * 10_001 },
             headers: headers,
             as: :json

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "sem autenticação" do
      it "retorna 401" do
        post clients_patient_notes_path, params: valid_params, as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "quando autenticado como terapeuta" do
      it "retorna 403" do
        post clients_patient_notes_path,
             params: valid_params,
             headers: auth_headers_for(therapist),
             as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  #PATCH /clients/patient_notes/:id
  describe "PATCH /clients/patient_notes/:id" do
    let!(:note) { create(:patient_note, user: client, content: "Conteúdo original") }

    context "atualizando própria nota" do
      it "retorna 200 com nota atualizada" do
        patch clients_patient_note_path(note),
              params: { content: "Conteúdo atualizado" },
              headers: headers,
              as: :json

        expect(response).to have_http_status(:ok)
        expect(note.reload.content).to eq("Conteúdo atualizado")
      end
    end

    context "com conteúdo inválido" do
      it "retorna 422" do
        patch clients_patient_note_path(note),
              params: { content: "" },
              headers: headers,
              as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_body["errors"]).to be_present
      end
    end

    context "tentando atualizar nota de outro cliente (IDOR)" do
      let(:other_client) { create(:user, :client, therapist: therapist) }
      let!(:other_note)  { create(:patient_note, user: other_client) }

      it "retorna 404" do
        patch clients_patient_note_path(other_note),
              params: { content: "Tentativa de modificação" },
              headers: headers,
              as: :json

        expect(response).to have_http_status(:not_found)
      end
    end

    context "sem autenticação" do
      it "retorna 401" do
        patch clients_patient_note_path(note), params: { content: "X" }, as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "quando autenticado como terapeuta" do
      it "retorna 403" do
        patch clients_patient_note_path(note),
              params: { content: "Tentativa de terapeuta" },
              headers: auth_headers_for(therapist),
              as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  #DELETE /clients/patient_notes/:id
  describe "DELETE /clients/patient_notes/:id" do
    let!(:note) { create(:patient_note, user: client) }

    context "deletando própria nota" do
      it "remove a nota e retorna 204" do
        expect {
          delete clients_patient_note_path(note), headers: headers
        }.to change(PatientNote, :count).by(-1)

        expect(response).to have_http_status(:no_content)
      end
    end

    context "tentando deletar nota de outro cliente (IDOR)" do
      let(:other_client) { create(:user, :client, therapist: therapist) }
      let!(:other_note)  { create(:patient_note, user: other_client) }

      it "retorna 404 e não deleta a nota" do
        expect {
          delete clients_patient_note_path(other_note), headers: headers
        }.not_to change(PatientNote, :count)

        expect(response).to have_http_status(:not_found)
      end
    end

    context "sem autenticação" do
      it "retorna 401" do
        delete clients_patient_note_path(note)
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "quando autenticado como terapeuta" do
      it "retorna 403" do
        delete clients_patient_note_path(note), headers: auth_headers_for(therapist)
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
