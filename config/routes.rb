Rails.application.routes.draw do
  root "dashboard#show"

  # Sign in and out only - accounts are created from inside the app, and
  # password recovery is by offline code rather than email.
  devise_for :users,
             skip: %i[registrations passwords],
             path: "",
             path_names: { sign_in: "sign-in", sign_out: "sign-out" },
             controllers: { sessions: "sessions" }

  # Forgotten password, redeemed with one of the codes from your profile.
  get  "recover", to: "recoveries#new",    as: :recovery
  post "recover", to: "recoveries#create"

  resource :password, only: %i[edit update], controller: "passwords"
  resource :recovery_codes, only: %i[show create], controller: "recovery_codes"

  # Accounts are created only by accepting an invite link.
  # Tokenless: the first account on a deployment that has none. Declared first
  # so "join" is not swallowed by the token segment.
  get  "join",        to: "signups#new",    as: :first_signup
  post "join",        to: "signups#create"
  get  "join/:token", to: "signups#new",    as: :signup
  post "join/:token", to: "signups#create"

  resources :invitations, only: %i[index create]

  resource  :profile, only: %i[show edit update destroy]
  resource  :email,   only: %i[edit update], controller: "emails"
  resource  :avatar,  only: :update, controller: "avatars" do
    patch :shuffle, on: :member
  end
  resources :people,  only: :index
  resources :friendships, only: %i[create destroy] do
    member { patch :accept }
  end

  # Expenses live at the top level whether or not they belong to a group -
  # expense[group_id] decides, and a blank one means a personal expense.
  resources :expenses do
    member do
      patch :void
      patch :restore
    end
  end

  resources :notifications, only: %i[index update] do
    collection { patch :read_all }
  end

  get "balances", to: "balances#index"
  get "activity", to: "activity#index"
  get "insights", to: "insights#show"

  resources :groups do
    resources :memberships, only: %i[index create destroy]
    resources :settlements, only: %i[index new create edit update] do
      member { patch :void }
    end

    member do
      get :expenses, as: :expenses_for
      get :balances, as: :balances_for
      get :activity, as: :activity_for
      patch :archive
      patch :restore
    end

    resource :settle_up, only: %i[show create], controller: "settle_ups"
  end

  # Server-authoritative previews for the Vue expense form. The client never
  # computes a figure that gets persisted; it asks Rails what the split and
  # the conversion would be, and Rails recalculates again on submit.
  namespace :api do
    post "split_previews", to: "split_previews#create"
    get  "conversions",    to: "conversions#show"
  end

  get "up", to: "rails/health#show", as: :rails_health_check
end
