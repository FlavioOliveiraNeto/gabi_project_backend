class Users::RegistrationsController < Devise::RegistrationsController
  respond_to :json

  def create
    build_resource(sign_up_params)
    resource.role = :client

    therapist = User.find_by(role: :therapist, email: ENV["THERAPIST_EMAIL"]) ||
                User.where(role: :therapist).order(:created_at).first
    resource.therapist = therapist if therapist

    resource.save

    if resource.persisted?
      render json: {
        user: {
          id: resource.id,
          name: resource.name,
          email: resource.email,
          role: resource.role
        }
      }, status: :created
    else
      render json: { errors: resource.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def sign_up_params
    params.require(:user).permit(:name, :email, :phone, :password, :password_confirmation)
  end
end
