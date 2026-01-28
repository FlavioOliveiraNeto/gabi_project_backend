class User < ApplicationRecord
  enum :role, { client: 0, admin: 1 }

  devise :database_authenticatable,
         :registerable,
         :recoverable,
         :rememberable,
         :validatable,
         :confirmable

  has_many :clinical_notes, dependent: :destroy
end
