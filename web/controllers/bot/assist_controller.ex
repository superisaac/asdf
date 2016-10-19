defmodule Asdf.Bot.AssistController do
  use Asdf.Web, :controller
  alias Asdf.Repo
  alias Asdf.User
  
  def index(conn, %{"event" => "message", "body" => body}) do
    bot = conn.assigns[:bot_user]
    #content = body["content"]
    room_id = body["room_id"]

    spawn(fn ->
      url = merge_url(conn, "/api/chat.postSelect")
      :timer.sleep(100)  # sleep 0.1 second
      User.post_json_api(bot, url, %{
            "target": "\##{room_id}",
            "text": "What can I do?",
            "options": [
              %{"label": "Change Name", "value": "change_name"},
              %{"label": "ok", "value": "3"}
            ]})
    end)

    ok_json conn, %{}
  end

  def index(conn, %{"event" => "select", "body" => body}) do
    bot = conn.assigns[:bot_user]
    value = body["value"]
    room_id = body["room_id"]
    user_name = body["user_name"]
    spawn(fn ->

      case value do
        "change_name" ->
          url = merge_url(conn, "/api/chat.postForm")
          fields = [%{
                       "label" => "New user name",
                       "name" => "user_name",
                       "type" => "text"
                    }]

          User.post_json_api(bot, url, %{
                "target": "\##{room_id}",
                "text": "@#{user_name} you choosed #{value}",
                "fields": fields
                             })
         _ -> 
          url = merge_url(conn, "/api/chat.postMessage")        
          User.post_json_api(bot, url, %{
                "target": "\##{room_id}",
                "text": "@#{user_name} you choosed #{value}"
                             })
      end
    end)
    ok_json conn, %{}
  end

  def index(conn, %{"event" => "form", "body" => body}) do
    bot = conn.assigns[:bot_user]
    room_id = body["room_id"]
    user_id = body["user_id"]
    new_user_name = body["form_data"]["user_name"]
    user = Repo.get(User, user_id)
    if user != nil do
      old_user_name = User.get_user_name(user)
      cset = User.changeset(user, %{:name => new_user_name})
      user = Repo.update!(cset)
      
      spawn(fn ->
        topic = "user:#{user.id}"
        Asdf.Endpoint.broadcast!(topic, "profile_changed", %{"user_id" => user.id})
      end)
      
      spawn(fn ->
        url = merge_url(conn, "/api/chat.postMessage")
        User.post_json_api(bot, url, %{
              "target": "\##{room_id}",
              "text": "@#{user.name} change from #{old_user_name}"
                              })

      end)
    end
    ok_json conn, %{}
  end

end
