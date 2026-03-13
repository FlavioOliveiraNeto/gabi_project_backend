class ApplicationController < ActionController::Base
  skip_before_action :verify_authenticity_token, if: -> { request.format.json? }

  # Popula Current.user para que os callbacks de auditoria saibam quem agiu.
  before_action :set_current_user

  protected

  def set_current_user
    Current.user = current_user
  end

  def after_sign_in_path_for(resource)
    if resource.therapist?
      therapists_dashboard_path
    elsif resource.client?
      clients_dashboard_path
    else
      root_path
    end
  end

  def enforce_password_change!
    return unless current_user&.must_change_password?

    render json: {
      error: "É necessário trocar a senha antes de continuar.",
      must_change_password: true
    }, status: :forbidden
  end
end
