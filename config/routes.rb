Rails.application.routes.draw do
  devise_for :users
  root "pages#home"

  resources :projects, only: [ :index, :new, :create, :show ] do
    member do
      patch :publish
    end
  end
end
