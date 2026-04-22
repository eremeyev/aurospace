# frozen_string_literal: true

class ApiController < ActionController::API
  include Dry::Monads::Result::Mixin
  include Pundit::Authorization

  rescue_from Pundit::NotAuthorizedError do
    render json: { error: { code: "forbidden", message: "Not authorized" } }, status: :forbidden
  end

  before_action :authenticate_user!

  def current_user
    return @current_user if defined?(@current_user)

    token = bearer_token
    @current_user = token.present? ? User.find_by(api_token: token) : nil
  end

  def render_result(result, adapter: :json, **serializer_options)
    case result
    when Success
      value = result.value!
      return head(:ok) if value.nil?

      render(json: value, adapter: adapter, **serializer_options)
    when Failure
      render(json: { error: normalize_failure(result.failure) }, status: :unprocessable_entity)
    else
      render(json: { error: { code: "internal_error", message: "Unexpected result" } }, status: :internal_server_error)
    end
  end

  private

  def authenticate_user!
    return if current_user.present?

    render json: { error: { code: "unauthorized", message: "Invalid or missing token" } }, status: :unauthorized
  end

  def bearer_token
    auth = request.headers["Authorization"].to_s
    return if auth.blank?

    scheme, token = auth.split(" ", 2)
    return if scheme != "Bearer"

    token.presence
  end

  def normalize_failure(failure)
    case failure
    when Hash
      { code: (failure[:code] || "unprocessable_entity"), message: (failure[:base] || failure[:message] || failure.to_s) }
    else
      { code: "unprocessable_entity", message: failure.to_s }
    end
  end
end
