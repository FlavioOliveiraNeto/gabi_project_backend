# Shared examples para respostas HTTP padrão da API.
#
# Convenção de uso:
#   it_behaves_like "retorna não autorizado"
#   it_behaves_like "retorna não encontrado"
#
# ATENÇÃO: json_response usa symbolize_names: true.
# As chaves são símbolos — use :error, :errors, :data (não strings).
#
# Shared examples de autenticação estão em:
#   spec/support/shared_examples/authenticated_endpoint.rb

RSpec.shared_examples "retorna não autorizado" do
  it "retorna status 401 Unauthorized" do
    expect(response).to have_http_status(:unauthorized)
  end

  it "retorna body com chave :error" do
    expect(json_response).to include(:error)
  end
end

RSpec.shared_examples "retorna proibido" do
  it "retorna status 403 Forbidden" do
    expect(response).to have_http_status(:forbidden)
  end

  it "retorna body com chave :error" do
    expect(json_response).to include(:error)
  end
end

RSpec.shared_examples "retorna não encontrado" do
  it "retorna status 404 Not Found" do
    expect(response).to have_http_status(:not_found)
  end

  it "retorna body com chave :error" do
    expect(json_response).to include(:error)
  end
end

RSpec.shared_examples "retorna entidade não processável" do
  it "retorna status 422 Unprocessable Entity" do
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "retorna body com chave :errors" do
    expect(json_response).to include(:errors)
  end
end

RSpec.shared_examples "retorna sucesso" do
  it "retorna status 200 OK" do
    expect(response).to have_http_status(:ok)
  end
end

RSpec.shared_examples "retorna criado" do
  it "retorna status 201 Created" do
    expect(response).to have_http_status(:created)
  end
end
