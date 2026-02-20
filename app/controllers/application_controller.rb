class ApplicationController < ActionController::Base
  skip_before_action :verify_authenticity_token, if: -> { request.format.json? }

  include Pundit::Authorization

  rescue_from Pundit::NotAuthorizedError do
    render json: { error: "Acesso não autorizado" }, status: :forbidden
  end

  protected

  def after_sign_in_path_for(resource)
    if resource.therapist?
      therapists_dashboard_path
    elsif resource.client?
      clients_dashboard_path
    else
      root_path
    end
  end
end
