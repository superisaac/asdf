defmodule Asdf.Bot.AssistController do
  use Asdf.Web, :controller
  alias Asdf.Repo
  alias Asdf.User
  
  def index(conn, %{"event" => "message", "body" => body}) do
    bot = conn.assigns[:bot_user]
    #content = body["content"]
    room_id = body["room_id"]

    User.post_gadget(conn, bot,
                     "\##{room_id}", "select",
                     %{
                       "options": [
                         %{"label": "Change Name", "value": "change_name"},
                         %{"label": "ok", "value": "3"}
                       ]})
    ok_json conn, %{}
  end

  def index(conn, %{"event" => "select", "body" => body}) do
    value = body["value"]
    spawn(__MODULE__, :menu_selected, [conn, value, body])
    ok_json conn, %{}
  end

  def index(conn, %{"event" => "form", "body" => body}) do
    action = body["action"]
    IO.puts "got form submit"
    IO.inspect body
    form_submited(conn, action, body)
    ok_json conn, %{}
  end


  def menu_selected(conn, "change_name", body) do
    bot = conn.assigns[:bot_user]
    room_id = body["room_id"]
    fields = [%{
                 "label" => "New user name",
                 "name" => "user_name",
                 "type" => "text"
          }]
    User.post_gadget(conn, bot,
                     "\##{room_id}", "form",
                     %{
                       "action": "change_name",
                       "fields": fields})                
  end
  
  def menu_selected(_conn, _value, _body), do: nil

  def form_submited(conn, "change_name", body) do
    bot = conn.assigns[:bot_user]
    room_id = body["room_id"]
    user_id = body["user_id"]
    action = body["action"]
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
    end
  end
  def form_submited(_conn, _action, _body), do: nil

end
