# spec/support/order_helpers.rb
module OrderHelpers
  def create_pending_order(amount: 100.00, balance: 500.00)
    payment_account = create(:payment_account, balance: balance)
    create(:order, :pending, total_amount: amount, payment_account: payment_account)
  end

  def create_success_order(amount: 100.00, balance: 500.00)
    payment_account = create(:payment_account, balance: balance)
    order = create(:order, :pending, total_amount: amount, payment_account: payment_account)

    Orders::Success.new(order: order, payment_account: payment_account).call
    order.reload
  end

  def create_order_with_items(amount: 100.00, items_count: 3)
    order = create(:order, :pending, total_amount: amount)
    create_list(:order_item, items_count, order: order)
    order.update(total_amount: order.order_items.sum(&:price))
    order
  end

  def create_concurrent_orders(account_balance: 1000, orders_count: 3, amount_per_order: 300)
    payment_account = create(:payment_account, balance: account_balance)

    orders = create_list(:order, orders_count,
      :pending,
      total_amount: amount_per_order,
      payment_account: payment_account
    )

    { payment_account: payment_account, orders: orders }
  end
end
