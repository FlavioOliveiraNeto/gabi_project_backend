class HomeController < ApplicationController
  # pública, então pulamos autenticação
  skip_before_action :verify_authenticity_token, raise: false

  def index
    render json: {
      message: "Bem-vindo à API da Clínica",
      sections: [
        { title: "Sobre Mim", content: "Texto sobre a terapeuta..." },
        { title: "Serviços", content: "Terapia individual, casais..." }
      ]
    }, status: :ok
  end
end