Rails.application.routes.draw do
  get 'up' => 'rails/health#show', as: :rails_health_check

  root 'users#index'

  resources :users, only: [:index, :create]
  resources :orders, only: [] do
    post :purchase, on: :member
    post :cancel, on: :member
  end
end
