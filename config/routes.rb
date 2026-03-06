# frozen_string_literal: true

Rails.application.routes.draw do
  root to: "pages#home"
  devise_for :users

  resources :users, only: [ :show ]

  resources :projects, only: [ :index, :show, :new, :create, :destroy ] do
  member do
    patch :publish
  end

    # Un chat unique par project (has_one :chat)
    resource :chat, only: [ :show ], controller: "chats" do
      resources :messages, only: [ :create ]
    end
  end
end
