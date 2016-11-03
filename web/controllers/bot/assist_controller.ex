defmodule Asdf.Bot.AssistController do
  use Asdf.Web, :controller
  alias Asdf.Repo
  alias Asdf.User
  alias Asdf.Room
  alias Asdf.RoomMember

  def index(conn, %{"event" => "message", "body" => _body}) do
    ok_json conn, %{}
  end

  def index(conn, %{"event" => "gadget_action", "body" => body}) do
    template = body["template"]
    action = body["action"]
    data = body["data"]
    gadget_act(conn, template, action, data, body)
    ok_json conn, %{}
  end

  def gadget_act(conn, "select", "profile_action", _data, body) do
    bot = conn.assigns[:bot_user]
    room_id = body["room_id"]
    User.post_gadget(conn, bot,
                     "\##{room_id}", "select",
                     %{
                       "options": [
                         %{"label": "Change Name", "value": "change_name"},
                       ]},
                     "Profile actions")
  end

  def gadget_act(conn, "select", "room_action", _data, body) do
    bot = conn.assigns[:bot_user]    
    user_id = body["user_id"]
    room_id = body["room_id"]
    user = Repo.get(User, user_id)
    q = Repo.all(from room in Room,
                 where: room.user_id == ^user.id,
                 where: room.type == 0,
                 order_by: [desc: room.last_msg_id])
    text = q
    |> Enum.map(fn(room) ->
      "#" <> Room.get_full_name(room, user)
    end)
    |> Enum.join(" ")

    text = "Created rooms " <> text
    User.post_gadget(conn, bot,
                     "\##{room_id}", "select",
                     %{
                       "options": [
                         %{"label": "Add Room", "value": "add_room"},
                         %{"label": "Delete Room", "value": "del_room"},
                       ]},
                     text)
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

  def gadget_act(conn, "select", "add_room", _data, body) do
    bot = conn.assigns[:bot_user]
    room_id = body["room_id"]
    fields = [%{
                 "label" => "New room name",
                 "name" => "room_name",
                 "type" => "text"
          }]
    User.post_gadget(conn, bot,
                     "\##{room_id}", "form",
                     %{
                       "action": "add_room",
                       "fields": fields})
  end

  def gadget_act(conn, "select", "del_room", _data, body) do
    bot = conn.assigns[:bot_user]
    room_id = body["room_id"]
    fields = [%{
                 "label" => "Delete room by name",
                 "name" => "room_name",
                 "type" => "text"
          }]
    User.post_gadget(conn, bot,
                     "\##{room_id}", "form",
                     %{
                       "action": "del_room",
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

  def gadget_act(conn, "form", "add_room", data, body) do
    bot = conn.assigns[:bot_user]
    room_id = body["room_id"]
    user_id = body["user_id"]
    user = Repo.get(User, user_id)
    new_room_name = data["room_name"] |> valid_ident

    if new_room_name == nil or Repo.get_by(Room, user_id: user.id, name: new_room_name) do
      User.post_text_msg(conn, bot, "\##{room_id}", "invalid room name")
    else
      new_room = Room.create(user, new_room_name)
      _lm = RoomMember.create(new_room, user, true)
      new_full_room_name = Room.get_full_name(new_room, user)
      User.post_text_msg(conn, bot, "\##{room_id}", "room \##{new_full_room_name} created")
      spawn(fn ->
        topic = "user:#{user.id}"
        Asdf.Endpoint.broadcast!(topic, "data_changed", %{})
      end)
    end
  end

  def gadget_act(conn, "form", "del_room", data, body) do
    bot = conn.assigns[:bot_user]
    room_id = body["room_id"]
    user_id = body["user_id"]
    user = Repo.get(User, user_id)
    room_name = data["room_name"] |> valid_ident

    if room_name == nil do
      User.post_text_msg(conn, bot, "\##{room_id}", "illegal room")
    else
      rm = Repo.get_by(Room, user_id: user.id, name: room_name)
      if rm == nil do
        User.post_text_msg(conn, bot, "\##{room_id}", "room not found")
      else
        case Room.delete_room(rm) do
          {:ok, _} ->
            User.post_text_msg(conn, bot, "\##{room_id}", "room deleted")
            spawn(fn ->
              topic = "user:#{user.id}"
              Asdf.Endpoint.broadcast!(topic, "data_changed", %{})
            end)
          {:error, _} ->
            User.post_text_msg(conn, bot, "\##{room_id}", "room not deleted")          
        end
      end
    end
  end
  
  def gadget_act(_conn, _template, _action, _data, _body), do: nil
end
