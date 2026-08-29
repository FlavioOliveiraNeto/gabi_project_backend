require 'rails_helper'

RSpec.describe "Clients::PatientNotes", type: :request do
  let(:parsed_response) do
    json = JSON.parse(response.body)
    json.is_a?(Array) ? json.map(&:deep_symbolize_keys) : json.deep_symbolize_keys
  end

  shared_examples "exige autenticação" do |method, path_helper|
    it "retorna 401 não autorizado" do
      send(method, send(path_helper, id: 'dummy_id'), as: :json)
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /clients/patient_notes" do
    context "quando não autenticado" do
      it_behaves_like "exige autenticação", :get, :clients_patient_notes_path
    end

    context "quando autenticado" do
      let(:therapist) { create(:user, :therapist) }
      let(:user) { create(:user, :client, therapist: therapist) }

      before do
        sign_in user
      end

      context "quando o usuário é uma terapeuta" do
        let(:user) { create(:user, :therapist) }

        it "retorna 403 proibido com a mensagem de erro correta" do
          get clients_patient_notes_path, as: :json

          expect(response).to have_http_status(:forbidden)
          expect(parsed_response[:error]).to eq("Acesso restrito.")
        end
      end

      context "quando o usuário precisa trocar a senha" do
        let(:user) { create(:user, :client, :must_change_password) }

        it "bloqueia o acesso" do
          get clients_patient_notes_path, as: :json

          expect(response).to have_http_status(:forbidden)
          expect(parsed_response[:must_change_password]).to eq(true)
          expect(parsed_response[:error]).to eq("É necessário trocar a senha antes de continuar.")
        end
      end

      context "quando não há anotações" do
        it "retorna 200 com uma lista vazia" do
          get clients_patient_notes_path, as: :json

          expect(response).to have_http_status(:ok)
          expect(parsed_response).to eq([])
        end
      end

      context "quando há anotações" do
        let!(:note1) { create(:patient_note, user: user) }
        let!(:note2) { create(:patient_note, user: user) }

        it "retorna todas as anotações pertencentes ao cliente" do
          get clients_patient_notes_path, as: :json

          expect(response).to have_http_status(:ok)
          ids = parsed_response.map { |n| n[:id] }
          expect(ids).to contain_exactly(note1.id, note2.id)
        end

        context "quando se verifica o isolamento dos dados" do
          let(:other_client) { create(:user, :client, therapist: therapist) }
          let!(:other_note)  { create(:patient_note, user: other_client) }

          it "não retorna anotações de outros clientes" do
            get clients_patient_notes_path, as: :json

            ids = parsed_response.map { |n| n[:id] }
            expect(ids).to include(note1.id)
            expect(ids).not_to include(other_note.id)
          end
        end
      end
    end
  end

  describe "POST /clients/patient_notes" do
    let(:valid_params) { { content: "Minha anotação sobre a sessão de hoje." } }
    let(:invalid_params) { { content: "" } }

    context "quando não autenticado" do
      it_behaves_like "exige autenticação", :post, :clients_patient_notes_path
    end

    context "quando autenticado" do
      let(:therapist) { create(:user, :therapist) }
      let(:user) { create(:user, :client, therapist: therapist) }

      before do
        sign_in user
      end

      context "quando o usuário precisa trocar a senha" do
        let(:user) { create(:user, :client, :must_change_password) }

        it "bloqueia o acesso" do
          post clients_patient_notes_path, params: valid_params, as: :json

          expect(response).to have_http_status(:forbidden)
          expect(parsed_response[:must_change_password]).to eq(true)
          expect(parsed_response[:error]).to eq("É necessário trocar a senha antes de continuar.")
        end
      end

      context "com dados válidos" do
        it "cria a anotação e retorna 201" do
          expect {
            post clients_patient_notes_path, params: valid_params, as: :json
          }.to change(PatientNote, :count).by(1)

          expect(response).to have_http_status(:created)
          note = PatientNote.last
          expect(note.user).to eq(user)
          expect(note.content).to eq(valid_params[:content])
        end
      end

      context "com conteúdo vazio" do
        it "retorna 422 entidade não processável" do
          post clients_patient_notes_path, params: invalid_params, as: :json

          expect(response).to have_http_status(:unprocessable_entity)
          expect(parsed_response[:errors]).to be_present
        end
      end
    end
  end

  describe "PATCH /clients/patient_notes/:id" do
    let(:therapist) { create(:user, :therapist) }
    let(:user) { create(:user, :client, therapist: therapist) }
    let(:note) { create(:patient_note, user: user, content: "Conteúdo original") }

    context "quando não autenticado" do
      it "retorna 401 não autorizado" do
        patch clients_patient_note_path(note), params: { content: "X" }, as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "quando autenticado" do
      before do
        sign_in user
      end

      context "quando o usuário precisa trocar a senha" do
        let(:user) { create(:user, :client, :must_change_password) }

        it "bloqueia o acesso" do
          patch clients_patient_note_path(note), params: { content: "Tentativa" }, as: :json

          expect(response).to have_http_status(:forbidden)
          expect(parsed_response[:must_change_password]).to eq(true)
          expect(parsed_response[:error]).to eq("É necessário trocar a senha antes de continuar.")
        end
      end

      context "ao atualizar a própria anotação" do
        it "retorna 200 com a anotação atualizada" do
          patch clients_patient_note_path(note), params: { content: "Conteúdo atualizado" }, as: :json

          expect(response).to have_http_status(:ok)
          expect(note.reload.content).to eq("Conteúdo atualizado")
        end
      end

      context "com conteúdo inválido" do
        it "retorna 422" do
          patch clients_patient_note_path(note), params: { content: "" }, as: :json

          expect(response).to have_http_status(:unprocessable_entity)
          expect(parsed_response[:errors]).to be_present
        end
      end

      context "ao tentar atualizar a anotação de outro cliente (IDOR)" do
        let(:other_client) { create(:user, :client) }
        let(:other_note) { create(:patient_note, user: other_client) }

        it "retorna 404 não encontrado" do
          patch clients_patient_note_path(other_note), params: { content: "Hack attempt" }, as: :json

          expect(response).to have_http_status(:not_found)
        end
      end
    end
  end

  describe "DELETE /clients/patient_notes/:id" do
    let(:therapist) { create(:user, :therapist) }
    let(:user) { create(:user, :client, therapist: therapist) }
    let(:note) { create(:patient_note, user: user) }

    context "quando não autenticado" do
      it "retorna 401 não autorizado" do
        delete clients_patient_note_path(note), as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "quando autenticado" do
      before do
        sign_in user
      end

      context "quando o usuário precisa trocar a senha" do
        let(:user) { create(:user, :client, :must_change_password) }

        it "bloqueia o acesso" do
          delete clients_patient_note_path(note), as: :json

          expect(response).to have_http_status(:forbidden)
          expect(parsed_response[:must_change_password]).to eq(true)
          expect(parsed_response[:error]).to eq("É necessário trocar a senha antes de continuar.")
        end
      end

      context "ao excluir a própria anotação" do
        it "exclui a anotação e retorna 204" do
          note

          expect {
            delete clients_patient_note_path(note), as: :json
          }.to change(PatientNote, :count).by(-1)

          expect(response).to have_http_status(:no_content)
        end
      end

      context "ao tentar excluir a anotação de outro cliente (IDOR)" do
        let(:other_client) { create(:user, :client) }
        let!(:other_note) { create(:patient_note, user: other_client) }

        it "retorna 404 e não exclui a anotação" do
          expect {
            delete clients_patient_note_path(other_note), as: :json
          }.not_to change(PatientNote, :count)

          expect(response).to have_http_status(:not_found)
        end
      end
    end
  end
end
