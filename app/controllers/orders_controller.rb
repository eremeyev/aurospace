# app/controllers/orders_controller.rb
# frozen_string_literal: true

class OrdersController < ApiController
  before_action :authenticate_user!
  before_action :set_order, only: [:show, :cancel, :refund, :status, :purchase]
  before_action :set_payment_account, only: [:create, :purchase]
  before_action :authorize_order_access!, only: [:show, :cancel, :refund, :status, :purchase]

  # GET /orders
  def index
    orders = current_user.orders
                         .includes(payment_account: :user)
                         .order(created_at: :desc)
                         .page(params[:page])
                         .per(params[:per_page] || 20)

    render json: {
      orders: orders.as_json(include: { payment_account: { only: [:id, :account_type, :currency] } }),
      meta: pagination_meta(orders)
    }, status: :ok
  end

  # GET /orders/:id
  def show
    render json: @order.as_json(
      include: {
        payment_account: { only: [:id, :account_type, :currency] },
        transactions: { only: [:id, :amount, :transaction_type, :description, :created_at] }
      }
    ), status: :ok
  end

  # POST /orders
  def create
    @order = Order.new(order_params.merge(payment_account: @payment_account))

    if @order.save
      render json: {
        order: @order,
        message: 'Order created successfully',
        payment_required: true
      }, status: :created
    else
      render json: { errors: @order.errors.full_messages }, status: :unprocessable_content
    end
  end

  # POST /orders/:id/purchase
  def purchase
    @order = Order.find(params[:id])

    idempotency_key = request.headers['Idempotency-Key']

    # Проверка статуса заказа
    unless @order.pending? || (@order.success? && @order.idempotency_key == idempotency_key)
      return render json: {
        error: 'Order cannot be purchased',
        details: "Order status is #{@order.status}"
      }, status: :unprocessable_content
    end

    # Если заказ уже успешно оплачен с таким же ключом
    if @order.success? && @order.idempotency_key == idempotency_key
      return render json: {
        success: true,
        message: 'Payment already processed (idempotent request)',
        order: @order.as_json(include: { transactions: { only: [:id, :amount, :transaction_type, :description] } }),
        balance: @order.payment_account.balance
      }, status: :ok
    end

    # Попытка оплаты
    if @order.pay_with_idempotency!(idempotency_key)
      render json: {
        success: true,
        message: 'Payment processed successfully',
        order: @order.as_json(include: { transactions: { only: [:id, :amount, :transaction_type, :description] } }),
        balance: @order.payment_account.balance
      }, status: :ok
    else
      render json: {
        success: false,
        error: 'Payment failed',
        details: @order.errors.full_messages
      }, status: :unprocessable_content
    end
  end

  # POST /orders/:id/cancel
  def cancel
    if @order.pending?
      @order.transaction do
        if @order.cancel!
          # Логируем отмену (опционально)
          log_activity(:cancel, @order)

          render json: {
            success: true,
            message: 'Order cancelled successfully',
            order: @order
          }, status: :ok
        else
          render json: {
            success: false,
            error: 'Order cancellation failed',
            details: @order.errors.full_messages
          }, status: :unprocessable_content
        end
      end
    else
      render json: {
        success: false,
        error: 'Cannot cancel order',
        details: "Only pending orders can be cancelled. Current status: #{@order.status}"
      }, status: :unprocessable_content
    end
  end

  # POST /orders/:id/refund
  def refund
    # Проверка возможности возврата
    unless @order.success?
      return render json: {
        success: false,
        error: 'Cannot refund order',
        details: "Only successful orders can be refunded. Current status: #{@order.status}"
      }, status: :unprocessable_content
    end

    # Проверка временного лимита для возврата (опционально)
    if refund_time_limit_exceeded?
      return render json: {
        success: false,
        error: 'Refund time limit exceeded',
        details: "Refunds are only allowed within #{REFUND_DAYS_LIMIT} days after purchase"
      }, status: :unprocessable_content
    end

    @order.transaction do
      if @order.refund!
        # Создаем нотификацию (опционально)
        notify_user_about_refund(@order)

        # Логируем возврат
        log_activity(:refund, @order)

        render json: {
          success: true,
          message: 'Refund processed successfully',
          order: @order.as_json(include: { transactions: { only: [:id, :amount, :transaction_type, :description] } }),
          refunded_amount: @order.total_amount,
          new_balance: @order.payment_account.balance
        }, status: :ok
      else
        render json: {
          success: false,
          error: 'Refund failed',
          details: @order.errors.full_messages
        }, status: :unprocessable_content
      end
    end
  end

  # GET /orders/:id/status
  def status
    render json: {
      order_id: @order.id,
      status: @order.status,
      total_amount: @order.total_amount,
      created_at: @order.created_at,
      updated_at: @order.updated_at,
      payment_account_id: @order.payment_account_id
    }, status: :ok
  end

  # # POST /orders/:id/refund/partial
  # def partial_refund
  #   @order = Order.find(params[:id])
  #   refund_amount = params[:amount].to_d

  #   # Проверки
  #   unless @order.success?
  #     return render json: { error: 'Only successful orders can be partially refunded' }, status: :unprocessable_content
  #   end

  #   if refund_amount <= 0
  #     return render json: { error: 'Refund amount must be greater than 0' }, status: :unprocessable_content
  #   end

  #   if refund_amount > @order.total_amount
  #     return render json: { error: 'Refund amount exceeds order total' }, status: :unprocessable_content
  #   end

  #   # Создаем частичный возврат
  #   service = PartialRefundService.new(@order, refund_amount)

  #   if service.call
  #     render json: {
  #       success: true,
  #       message: "Partial refund of #{refund_amount} processed",
  #       refunded_amount: refund_amount,
  #       remaining_amount: @order.total_amount - refund_amount,
  #       order: @order
  #     }, status: :ok
  #   else
  #     render json: {
  #       success: false,
  #       error: 'Partial refund failed',
  #       details: service.errors
  #     }, status: :unprocessable_content
  #   end
  # end

  private

  REFUND_DAYS_LIMIT = 30

  def set_order
    @order = Order.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Order not found' }, status: :not_found
  end

  def set_payment_account
    account_id = params[:payment_account_id] || current_user.primary_account&.id

    unless account_id
      return render json: {
        error: 'Payment account required'
      }, status: :unprocessable_content
    end

    @payment_account = current_user.payment_accounts.find(account_id)
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Payment account not found' }, status: :not_found
  end

  def order_params
    params.require(:order).permit(:total_amount, :notes, :order_number)
  end

  def authorize_order_access!
    unless @order.payment_account.user_id == current_user.id || current_user.admin?
      render json: { error: 'Unauthorized access to order' }, status: :forbidden
    end
  end

  def authorize!(order)
    authorize_order_access! if order.present?
  end

  def pagination_meta(collection)
    {
      current_page: collection.current_page,
      next_page: collection.next_page,
      prev_page: collection.prev_page,
      total_pages: collection.total_pages,
      total_count: collection.total_count
    }
  end

  def refund_time_limit_exceeded?
    return false unless REFUND_DAYS_LIMIT
    @order.created_at < REFUND_DAYS_LIMIT.days.ago
  end

  def log_activity(action, order)
    # Можно использовать Rails.logger или создать ActivityLog модель
    Rails.logger.info("#{action.upcase}: Order ##{order.id} by User ##{current_user.id}")

    # Или создать запись в БД
    # ActivityLog.create!(
    #   user: current_user,
    #   order: order,
    #   action: action,
    #   metadata: { amount: order.total_amount, timestamp: Time.current }
    # )
  end

  def notify_user_about_refund(order)
    # Отправка email или push-уведомления
    # RefundMailer.refund_processed(current_user, order).deliver_later
  end
end
