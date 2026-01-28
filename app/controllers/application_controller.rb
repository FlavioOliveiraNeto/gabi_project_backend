class ApplicationController < ActionController::Base
  skip_before_action :verify_authenticity_token, if: -> { request.format.json? }
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  #allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  include Pundit::Authorization

  rescue_from Pundit::NotAuthorizedError do
    redirect_to root_path, alert: "Acesso não autorizado"
  end

  protected

  def after_sign_in_path_for(resource)
    if resource.admin?
      admins_dashboard_path # Redireciona Terapeuta
    elsif resource.client?
      clients_dashboard_path # Redireciona Cliente
    else
      root_path # Fallback para página inicial
    end
  end
end
