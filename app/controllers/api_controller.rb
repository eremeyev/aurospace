# frozen_string_literal: true

class ApiController < ActionController::API
  include Dry::Monads::Result::Mixin

  # validates user token

  private

  # заглушка
  def current_user
    @current_user ||= User.last
  end

  def render_result(result, adapter: :json, **serializer_options)
    case result
    when Success() then head(:ok)
    when Success then render(json: result.value!, adapter: adapter, **serializer_options)
    when Failure then render(json: result, status: :unprocessable_entity)
    end
  end
end
