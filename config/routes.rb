Rails.application.routes.draw do
  root "pages#home"

  resources :projects, only: [ :index, :new, :create, :show ] do
    member do
      patch :publish
    end
  end
end
