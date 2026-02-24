class Users::DevisePasswordsController < Devise::PasswordsController
  respond_to :json

  # POST /users/password
  # Solicita e-mail de recuperação de senha
  def create
    self.resource = resource_class.send_reset_password_instructions(resource_params)

    if successfully_sent?(resource)
      render json: {
        message: "Se o e-mail informado estiver cadastrado, você receberá as instruções em breve."
      }, status: :ok
    else
      render json: { errors: resource.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PUT /users/password
  # Redefine a senha com o token recebido por e-mail
  def update
    self.resource = resource_class.reset_password_by_token(resource_params)

    if resource.errors.empty?
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
