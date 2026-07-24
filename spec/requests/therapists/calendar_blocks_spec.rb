require "rails_helper"

RSpec.describe "Therapists::CalendarBlocks", type: :request do
  include_context "autenticado como terapeuta"

  let(:other_therapist) { create(:user, :therapist) }

  describe "GET /therapists/calendar_blocks" do
    let!(:own_block)   { create(:calendar_block, :upcoming, therapist: therapist) }
    let!(:other_block) { create(:calendar_block, :upcoming, therapist: other_therapist) }

    it "retorna apenas os bloqueios da terapeuta autenticada" do
      get therapists_calendar_blocks_path, headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_body.map { |b| b["id"] }).to contain_exactly(own_block.id)
    end
  end

  describe "GET /therapists/calendar_blocks/:id" do
    let(:other_block) { create(:calendar_block, therapist: other_therapist) }

    it "não expõe o bloqueio de outra terapeuta (404, não 200)" do
      get therapists_calendar_block_path(other_block), headers: headers
      expect(response).to have_http_status(:not_found)
    end

    it "expõe o próprio bloqueio" do
      own_block = create(:calendar_block, therapist: therapist)
      get therapists_calendar_block_path(own_block), headers: headers
      expect(response).to have_http_status(:ok)
      expect(json_body["id"]).to eq(own_block.id)
    end
  end

  describe "POST /therapists/calendar_blocks" do
    let(:params) do
      {
        calendar_block: {
          start_time: 1.day.from_now.beginning_of_hour,
          end_time:   1.day.from_now.beginning_of_hour + 2.hours,
          reason:     "Consulta médica"
        }
      }
    end

    it "cria o bloqueio atribuído à terapeuta autenticada (ignora therapist_id do body)" do
      expect {
        post therapists_calendar_blocks_path, params: params, headers: headers, as: :json
      }.to change(therapist.calendar_blocks, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(CalendarBlock.find(json_body["id"]).therapist_id).to eq(therapist.id)
    end

    it "retorna 422 com parâmetros inválidos" do
      params[:calendar_block][:reason] = ""
      post therapists_calendar_blocks_path, params: params, headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json_body["errors"]).to be_present
    end
  end

  describe "PATCH /therapists/calendar_blocks/:id" do
    it "atualiza o próprio bloqueio" do
      own_block = create(:calendar_block, therapist: therapist, reason: "Original")
      patch therapists_calendar_block_path(own_block),
            params: { calendar_block: { reason: "Atualizado" } },
            headers: headers,
            as: :json

      expect(response).to have_http_status(:ok)
      expect(own_block.reload.reason).to eq("Atualizado")
    end

    it "retorna 422 ao atualizar o próprio bloqueio com dados inválidos" do
      own_block = create(:calendar_block, therapist: therapist)
      patch therapists_calendar_block_path(own_block),
            params: { calendar_block: { reason: "" } },
            headers: headers,
            as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json_body["errors"]).to be_present
    end

    it "não permite atualizar o bloqueio de outra terapeuta" do
      other_block = create(:calendar_block, therapist: other_therapist)
      patch therapists_calendar_block_path(other_block),
            params: { calendar_block: { reason: "Invadido" } },
            headers: headers,
            as: :json

      expect(response).to have_http_status(:not_found)
      expect(other_block.reload.reason).not_to eq("Invadido")
    end
  end

  describe "DELETE /therapists/calendar_blocks/:id" do
    it "destrói o próprio bloqueio" do
      own_block = create(:calendar_block, therapist: therapist)
      expect {
        delete therapists_calendar_block_path(own_block), headers: headers
      }.to change(CalendarBlock, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end

    it "não permite destruir o bloqueio de outra terapeuta" do
      other_block = create(:calendar_block, therapist: other_therapist)
      expect {
        delete therapists_calendar_block_path(other_block), headers: headers
      }.not_to change(CalendarBlock, :count)

      expect(response).to have_http_status(:not_found)
    end
  end
end
