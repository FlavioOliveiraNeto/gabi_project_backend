class HomeController < ApplicationController
  # pública, então pulamos autenticação
  skip_before_action :verify_authenticity_token, raise: false

  def index
    @sections = [
      {
        title: "Jornadas guiadas por dados",
        description: "Fluxos inteligentes para triagem, sessões e acompanhamento com métricas sempre à vista."
      },
      {
        title: "Experiência cuidadosa",
        description: "Design leve, foco em empatia e comunicação clara em qualquer dispositivo."
      },
      {
        title: "Automação segura",
        description: "Lembretes, documentos e anotações com segurança e rastreabilidade."
      }
    ]
    render json: @sections
  end
end
