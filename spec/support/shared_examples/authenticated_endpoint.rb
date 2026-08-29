# Shared examples para endpoints protegidos por autenticação JWT.
#
# CONTRATO — o spec pai deve definir via let:
#
#   let(:make_request) { ->(hdrs) { get url, headers: hdrs } }
#
# O lambda recebe os headers como argumento, permitindo que cada contexto
# passe diferentes headers sem precisar redefinir o request inteiro.
#
# Exemplo completo de uso:
#
#   RSpec.describe "GET /api/v1/patients", type: :request do
#     let(:url)          { "/api/v1/patients" }
#     let(:therapist)    { create(:user, :therapist) }
#     let(:make_request) { ->(hdrs) { get url, headers: hdrs } }
#
#     it_behaves_like "exige autenticação"
#     it_behaves_like "exige papel de terapeuta" do
#       let(:patient_user) { create(:user, :patient) }
#     end
#
#     context "autenticado como terapeuta" do
#       before { make_request.call(therapist_auth_headers(therapist)) }
#       it_behaves_like "retorna sucesso"
#     end
#   end
# ---------------------------------------------------------------------------

RSpec.shared_examples "exige autenticação" do
  # O spec pai deve definir: let(:make_request) { ->(hdrs) { ... } }

  context "sem token de autenticação" do
    before { make_request.call({}) }

    it_behaves_like "retorna não autorizado"
  end

  context "com token sintaticamente inválido" do
    before { make_request.call(invalid_token_headers) }

    it_behaves_like "retorna não autorizado"
  end

  context "com token expirado" do
    # Requer que `let(:valid_user)` esteja definido no spec pai ou no bloco
    # passado para it_behaves_like.
    #
    # Exemplo:
    #   it_behaves_like "exige autenticação" do
    #     let(:valid_user) { create(:user, :therapist) }
    #   end
    #
    before { make_request.call(expired_token_headers(valid_user)) }

    it_behaves_like "retorna não autorizado"
  end
end

# ---------------------------------------------------------------------------
# Shared example para endpoints exclusivos da terapeuta.
#
# CONTRATO — o spec pai deve definir via let:
#   let(:make_request) { ->(hdrs) { get url, headers: hdrs } }
#   let(:patient_user) { create(:user, :patient) }  # usuário com role :patient
#
# Exemplo:
#   it_behaves_like "exige papel de terapeuta" do
#     let(:patient_user) { create(:user, :patient) }
#   end
# ---------------------------------------------------------------------------

RSpec.shared_examples "exige papel de terapeuta" do
  context "quando autenticado como paciente" do
    before { make_request.call(patient_auth_headers(patient_user)) }

    it_behaves_like "retorna proibido"
  end
end
