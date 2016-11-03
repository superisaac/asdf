defmodule Asdf.Bot.AssistController do
  use Asdf.Web, :controller
  alias Asdf.Repo
  alias Asdf.User
  
  def index(conn, %{"event" => "message", "body" => body}) do
    bot = conn.assigns[:bot_user]
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

  def index(conn, %{"event" => "gadget_action", "body" => body}) do
    template = body["template"]
    action = body["action"]
    data = body["data"]
    gadget_act(conn, template, action, data, body)
    ok_json conn, %{}
  end

  def gadget_act(conn, "select", "change_name", _data, body) do
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
  
  def gadget_act(_conn, "form", "change_name", data, body) do
    user_id = body["user_id"]
    user = Repo.get(User, user_id)    
    new_user_name = data["user_name"]
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

  def gadget_act(_conn, _template, _action, _data, _body), do: nil  

end
