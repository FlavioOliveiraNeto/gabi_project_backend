class ApplicationController < ActionController::Base
  skip_before_action :verify_authenticity_token, if: -> { request.format.json? }

  include Pundit::Authorization

  rescue_from Pundit::NotAuthorizedError do
    redirect_to root_path, alert: "Acesso não autorizado"
  end

  protected

  def after_sign_in_path_for(resource)
    if resource.admin?
      admins_dashboard_path
    elsif resource.client?
      clients_dashboard_path
    else
      root_path
    end
  end
end
