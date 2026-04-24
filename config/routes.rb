Rails.application.routes.draw do
  get 'up' => 'rails/health#show', as: :rails_health_check

  root 'users#index'

  resources :users, only: [:index, :create]
  resources :orders, only: [:index, :show, :create] do
    member do
      post :purchase   # Оплата заказа
      post :cancel     # Отмена заказа
      post :refund     # Полный возврат
      post :partial_refund  # Частичный возврат
      get :status      # Статус заказа
    end
  end
end
