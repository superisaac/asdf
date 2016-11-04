defmodule Asdf.Router do
  use Asdf.Web, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers

  end

  pipeline :admin do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug BasicAuth, realm: "Area", username: "admin", password: "1111"
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :fetch_session
    plug :fetch_query_params
    plug Asdf.Plugs.ApiAuth
  end

  pipeline :bot do
    plug :accepts, ["json"]
    plug :fetch_query_params
    plug Asdf.Plugs.BotSignature
  end

  scope "/", Asdf do
    pipe_through :browser # Use the default browser stack

    get "/", PageController, :index
    get "/logout", PageController, :logout

    get "/auth/passwd", PasswdController, :index
    post "/auth/passwd", PasswdController, :auth

    get "/auth/github", GithubController, :auth

    get "/auth/github/callback", GithubController, :auth_callback
    get "/home", HomeController, :index
  end

  # Other scopes may use custom stacks.
  scope "/api", Asdf do
    pipe_through :api

    get  "/profile", Api.ProfileController, :index
    
    get  "/bot.create", Api.BotController, :create_bot
    get  "/bot.deactie", Api.BotController, :deactivate_bot
    get  "/bot.list", Api.BotController, :bot_list

    get  "/room.joined", Api.RoomController, :joined_list
    get  "/room.created", Api.RoomController, :created_list    
    post "/room.create", Api.RoomController, :create
    post "/room.join", Api.RoomController, :join
    post "/room.leave", Api.RoomController, :leave
    post "/room.kick", Api.RoomController, :kick
    get  "/room.members", Api.RoomController, :member_list

    post "/chat.postStartMenu", Api.ChatController, :put_start_menu
    post "/chat.postMessage", Api.ChatController, :add_msg
    
    post "/chat.postGadget", Api.ChatController, :add_gadget
    post "/chat.postGadgetAction", Api.ChatController, :add_gadget_action
    post "/chat.upload", Api.ChatController, :upload_file

    get  "/chat.history", Api.ChatController, :get_msg_list
  end

  scope "/bot", Asdf do
    pipe_through :bot

    post "/assist", Bot.AssistController, :index
  end
  

end
