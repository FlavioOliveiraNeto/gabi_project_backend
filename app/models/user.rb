class User < ApplicationRecord
  enum :role, { client: 0, admin: 1 }

  devise :database_authenticatable,
         :registerable,
         :recoverable,
         :rememberable,
         :validatable,
         :confirmable,
         :jwt_authenticatable,
         jwt_revocation_strategy: JwtDenylist

  has_many :clinical_notes, dependent: :destroy
end
