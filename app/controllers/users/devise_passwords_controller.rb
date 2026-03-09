class Users::DevisePasswordsController < Devise::PasswordsController
  respond_to :json

  def create
    resource_class.send_reset_password_instructions(resource_params)

    render json: {
      message: "Se o e-mail informado estiver cadastrado, você receberá as instruções em breve."
    }, status: :ok
  end

  def update
    self.resource = resource_class.reset_password_by_token(resource_params)

    if resource.errors.empty?
      resource.clear_must_change_password! if resource.must_change_password?
      render json: { message: "Senha redefinida com sucesso. Faça login com sua nova senha." }, status: :ok
    else
      render json: { errors: resource.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def resource_params
    params.require(:user).permit(:email, :password, :password_confirmation, :reset_password_token)
  end
end
