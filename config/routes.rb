# frozen_string_literal: true

Rails.application.routes.draw do
  root to: "pages#home"
  devise_for :users

  resources :users, only: [ :show ]

  resources :projects, only: [ :index, :show, :new, :create ] do
    member do
      patch :publish
      get :chat # /projects/:id/chat
    end

    # /projects/:project_id/chat (POST) pour envoyer un message
    resource :chat, only: [ :create ], controller: "chats"
  end
end
