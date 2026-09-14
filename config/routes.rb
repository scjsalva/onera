Rails.application.routes.draw do
  root "dashboard#show"

  # Temporary identity. There is no authentication yet: a person picks who
  # they are and that choice lives in the session. Replacing this with real
  # sign-in should only change how Current.user is established.
  get    "welcome", to: "user_selection#new",     as: :user_selection
  post   "welcome", to: "user_selection#create"
  delete "welcome", to: "user_selection#destroy", as: :switch_user

  resource  :profile, only: %i[show edit update]
  resources :people,  only: %i[new create]

  # Expenses live at the top level whether or not they belong to a group -
  # expense[group_id] decides, and a blank one means a personal expense.
  resources :expenses do
    member do
      patch :void
      patch :restore
    end
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
