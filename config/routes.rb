Rails.application.routes.draw do
  devise_for :users
  root "pages#home"

  resources :projects do
    member do
      get :chat
    end
    resources :messages, only: [ :create ]
  end
end
