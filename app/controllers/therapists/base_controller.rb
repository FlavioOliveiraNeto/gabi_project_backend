# Autenticação e papel num lugar só: todo controller de /therapists herda daqui,
# então um endpoint novo não tem como esquecer as checagens.
class Therapists::BaseController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_therapist!

  private

  def ensure_therapist!
    render json: { error: "Acesso restrito." }, status: :forbidden unless current_user.therapist?
  end
end
