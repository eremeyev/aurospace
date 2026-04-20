# frozen_string_literal: true

class UsersController < ApiController
  def index
    render json: User.all
  end

  def create
    result = Users::Builder.new(email: users_params[:email]).call

    render_result(result)
  end

  private

  def users_params
    params.require(:user).permit(:email)
  end
end
