# frozen_string_literal: true

class OrdersController < ApiController
  before_action :set_order, only: %i[cancel purchase]

  def purchase
    payment_account = PaymentAccount.find(params[:payment_account_id])

    result = Orders::Success.new(
      order: @order, payment_account: payment_account
    ).call

    render_result(result)
  end

  def cancel
    result = Orders::Cancel.new(
      order: @order, transaction: @order.transactions.last
    ).call

    render_result(result)
  end

  private

  def set_order
    @order ||= Order.find(params[:id])
  end
end
