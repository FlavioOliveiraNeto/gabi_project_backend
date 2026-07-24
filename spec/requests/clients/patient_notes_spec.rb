require 'rails_helper'

RSpec.describe "Clients::PatientNotes", type: :request do
  let(:parsed_response) do
    json = JSON.parse(response.body)
    json.is_a?(Array) ? json.map(&:deep_symbolize_keys) : json.deep_symbolize_keys
  end

  shared_examples "requires authentication" do |method, path_helper|
    it "returns a 401 unauthorized status" do
      send(method, send(path_helper, id: 'dummy_id'), as: :json)
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /clients/patient_notes" do
    context "when not authenticated" do
      it_behaves_like "requires authentication", :get, :clients_patient_notes_path
    end

    context "when authenticated" do
      let(:therapist) { create(:user, :therapist) }
      let(:user) { create(:user, :client, therapist: therapist) }

      before do
        sign_in user
      end

      context "when user is a therapist" do
        let(:user) { create(:user, :therapist) }

        it "returns 403 forbidden with correct error message" do
          get clients_patient_notes_path, as: :json

          expect(response).to have_http_status(:forbidden)
          expect(parsed_response[:error]).to eq("Acesso restrito.")
        end
      end

      context "when user needs a password change" do
        let(:user) { create(:user, :client, :must_change_password) }

        it "blocks access" do
          get clients_patient_notes_path, as: :json

          expect(response).to have_http_status(:forbidden)
          expect(parsed_response[:must_change_password]).to eq(true)
          expect(parsed_response[:error]).to eq("É necessário trocar a senha antes de continuar.")
        end
      end

      context "when there are no notes" do
        it "returns 200 with an empty list" do
          get clients_patient_notes_path, as: :json

          expect(response).to have_http_status(:ok)
          expect(parsed_response).to eq([])
        end
      end

      context "when there are notes" do
        let!(:note1) { create(:patient_note, user: user) }
        let!(:note2) { create(:patient_note, user: user) }

        it "returns all patient notes belonging to the client" do
          get clients_patient_notes_path, as: :json

          expect(response).to have_http_status(:ok)
          ids = parsed_response.map { |n| n[:id] }
          expect(ids).to contain_exactly(note1.id, note2.id)
        end

        context "when verifying data isolation" do
          let(:other_client) { create(:user, :client, therapist: therapist) }
          let!(:other_note)  { create(:patient_note, user: other_client) }

          it "does not return notes from other clients" do
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

    context "when not authenticated" do
      it_behaves_like "requires authentication", :post, :clients_patient_notes_path
    end

    context "when authenticated" do
      let(:therapist) { create(:user, :therapist) }
      let(:user) { create(:user, :client, therapist: therapist) }

      before do
        sign_in user
      end

      context "when user needs a password change" do
        let(:user) { create(:user, :client, :must_change_password) }

        it "blocks access" do
          post clients_patient_notes_path, params: valid_params, as: :json

          expect(response).to have_http_status(:forbidden)
          expect(parsed_response[:must_change_password]).to eq(true)
          expect(parsed_response[:error]).to eq("É necessário trocar a senha antes de continuar.")
        end
      end

      context "with valid data" do
        it "creates a note and returns 201" do
          expect {
            post clients_patient_notes_path, params: valid_params, as: :json
          }.to change(PatientNote, :count).by(1)

          expect(response).to have_http_status(:created)
          note = PatientNote.last
          expect(note.user).to eq(user)
          expect(note.content).to eq(valid_params[:content])
        end
      end

      context "with empty content" do
        it "returns 422 unprocessable entity" do
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

    context "when not authenticated" do
      it "returns a 401 unauthorized status" do
        patch clients_patient_note_path(note), params: { content: "X" }, as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when authenticated" do
      before do
        sign_in user
      end

      context "when user needs a password change" do
        let(:user) { create(:user, :client, :must_change_password) }

        it "blocks access" do
          patch clients_patient_note_path(note), params: { content: "Tentativa" }, as: :json

          expect(response).to have_http_status(:forbidden)
          expect(parsed_response[:must_change_password]).to eq(true)
          expect(parsed_response[:error]).to eq("É necessário trocar a senha antes de continuar.")
        end
      end

      context "updating own note" do
        it "returns 200 with updated note" do
          patch clients_patient_note_path(note), params: { content: "Conteúdo atualizado" }, as: :json

          expect(response).to have_http_status(:ok)
          expect(note.reload.content).to eq("Conteúdo atualizado")
        end
      end

      context "with invalid content" do
        it "returns 422" do
          patch clients_patient_note_path(note), params: { content: "" }, as: :json

          expect(response).to have_http_status(:unprocessable_entity)
          expect(parsed_response[:errors]).to be_present
        end
      end

      context "attempting to update another client's note (IDOR)" do
        let(:other_client) { create(:user, :client) }
        let(:other_note) { create(:patient_note, user: other_client) }

        it "returns 404 Not Found" do
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

    context "when not authenticated" do
      it "returns a 401 unauthorized status" do
        delete clients_patient_note_path(note), as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when authenticated" do
      before do
        sign_in user
      end

      context "when user needs a password change" do
        let(:user) { create(:user, :client, :must_change_password) }

        it "blocks access" do
          delete clients_patient_note_path(note), as: :json

          expect(response).to have_http_status(:forbidden)
          expect(parsed_response[:must_change_password]).to eq(true)
          expect(parsed_response[:error]).to eq("É necessário trocar a senha antes de continuar.")
        end
      end

      context "deleting own note" do
        it "deletes the note and returns 204" do
          note

          expect {
            delete clients_patient_note_path(note), as: :json
          }.to change(PatientNote, :count).by(-1)

          expect(response).to have_http_status(:no_content)
        end
      end

      context "attempting to delete another client's note (IDOR)" do
        let(:other_client) { create(:user, :client) }
        let!(:other_note) { create(:patient_note, user: other_client) }

        it "returns 404 and does not delete the note" do
          expect {
            delete clients_patient_note_path(other_note), as: :json
          }.not_to change(PatientNote, :count)

          expect(response).to have_http_status(:not_found)
        end
      end
    end
  end
end
