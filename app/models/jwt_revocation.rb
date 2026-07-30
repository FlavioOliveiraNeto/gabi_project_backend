module JwtRevocation
  VERSION_CLAIM = "ver"

  class << self
    def jwt_revoked?(payload, user)
      JwtDenylist.jwt_revoked?(payload, user) || stale_version?(payload, user)
    end

    def revoke_jwt(payload, user)
      JwtDenylist.revoke_jwt(payload, user)
    end

    private

    def stale_version?(payload, user)
      payload[VERSION_CLAIM].to_i != user.token_version
    end
  end
end
