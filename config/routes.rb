Rails.application.routes.draw do
  root "teams#index"

  resource :session
  resource :registration, only: %i[ new create ]
  resources :passwords, param: :token
  resources :teams, only: %i[ index new create ]

  scope "t/:team_slug" do
    get "" => "dashboards#show", as: :team_root

    resources :customers do
      resources :orders, only: %i[ create destroy ]
      resources :tags, only: %i[ create destroy ], controller: "customer_tags"
    end

    resources :tags, only: %i[ index create edit update destroy ]

    resources :campaigns do
      member do
        get :confirm
        post :deliver
        post :duplicate
      end
    end

    resources :audiences, except: %i[ show ] do
      # 編輯表單帶 _method=patch,預覽按鈕用 formaction 共用同一張表單,所以兩種動詞都收
      match :preview, on: :collection, via: %i[ post patch ]
    end

    resources :import_jobs, only: %i[ index create show ], path: "imports" do
      get :template, on: :collection
    end

    namespace :settings do
      resource :team, only: %i[ show update destroy ]
      resources :memberships, only: %i[ index create destroy ]
    end
  end

  get "unsubscribe/:token" => "unsubscribes#show", as: :unsubscribe
  post "unsubscribe/:token" => "unsubscribes#create"

  mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check
end
