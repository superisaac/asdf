defmodule Asdf.Api.RoomController do
  use Asdf.Web, :controller
  import Ecto.Query

  alias Asdf.RoomMember
  alias Asdf.Room
  alias Asdf.Repo
  alias Asdf.User

  def get_auth_user(conn) do
    cu = current_user(conn)
    if User.is_bot(cu) do
      User.get_parent(cu)
    else
      cu
    end
  end
  
  def create(conn, params) do
    name = params["name"]
    curr_user = get_auth_user(conn)
    if Repo.get_by(Room, user_id: curr_user.id, name: name) do
      error_json conn, "room_exist"
    else
      room = Room.create(curr_user, name)
      _lm = RoomMember.create(room, curr_user, true)
      ok_json conn, %{"room" => Room.get_json_via_user(room, curr_user)}
    end
  end

  def kick(conn, params) do
    room = Room.get_room(params["room"])
    target_user_id = parse_uint(params["user"])
    target_user = Repo.get(Asdf.User, id: target_user_id)
    curr_user = get_auth_user(conn)
    cond do
      room == nil ->
        error_json conn, "room_not_exist"
      target_user == nil ->
        error_json conn, "user_not_exist"
      target_user.id == curr_user.id ->
        error_json conn, "cannot_kick_self"
      Repo.get_by(RoomMember, user_id: curr_user.id, room_id: room.id, is_admin: true) == nil ->
        error_json conn, "cannot_kick_user"
      Repo.get_by(RoomMember, user_id: target_user.id, room_id: room.id) == nil ->
        error_json conn, "user_is_not_member"         
      true ->
        cnt = kick_user(room, target_user)
        ok_json conn, %{kicked: cnt}
    end
  end

  def kick_user(room, user) do
    {cnt, _} = Repo.delete_all(RoomMember, user_id: user.id, room_id: room.id)
    cnt
  end    

  def join(conn, params) do
    room = Room.get_room(params["room"])
    curr_user = current_user(conn)
    case room do
      nil ->
        error_json conn, "room_not_exist"
      room ->
        lm = RoomMember.upsert(room, curr_user)
        ok_json conn, %{room: Room.get_json(room)}
    end
  end

  def leave(conn, params) do
    curr_user = current_user(conn)
    room = Room.get_room(params["room"])
    cond do
      room == nil ->
        error_json conn, "room_not_exist"
      room.user_id == curr_user.id ->
        error_json conn, "leave_self_room"
      true ->
        {cnt, _} = Repo.delete_all(
          from lm in RoomMember,
          where: lm.user_id == ^curr_user.id,
          where: lm.room_id == ^room.id
        )
        ok_json conn, %{deleted: cnt}
    end
  end

  def member_list(conn, params) do
    curr_user = current_user(conn)
    room = Room.get_room(params["room"])
    count = 100
    
    cond do
      curr_user == nil ->
        error_json conn, "user_not_login"
      room == nil ->
        error_json conn, "room_not_exist"
      Repo.get_by(RoomMember, room_id: room.id, user_id: curr_user.id) == nil ->
        error_json conn, "not_member"
      true ->
        q = Repo.all(from user in User,
                     join: member in RoomMember,
                     on: user.id == member.user_id,
                     where: member.room_id == ^room.id,
                     order_by: member.id,
                     #select: [user.id, user.name, member.is_admin],
                     select: [user, member.is_admin],
                     limit: ^count)
        items = q |> Enum.map(fn([user, is_admin]) ->
          %{id: user.id, name: Asdf.User.get_user_name(user), is_admin: is_admin}
        end)
        ok_json conn, %{users: items}
    end    
  end

  def joined_list(conn, _params) do
    curr_user = current_user(conn)
    count = 20
    q = Repo.all(from room in Room,
                 join: member in RoomMember,
                 on: member.room_id == room.id,
                 where: member.user_id == ^curr_user.id,
                 order_by: [desc: room.last_msg_id],
                 limit: ^count)
    items = q |> Enum.map(fn(room) ->
      Room.get_json_via_user(room, curr_user)
    end)
    ok_json conn, %{rooms: items}
  end

  def created_list(conn, _params) do
    curr_user = current_user(conn)
    count = 20
    q = Repo.all(from room in Room,
                 where: room.user_id == ^curr_user.id,
                 where: room.type == 0,
                 order_by: [desc: room.last_msg_id],
                 limit: ^count)
    items = q |> Enum.map(fn(room) ->
      Room.get_json_via_user(room, curr_user)
    end)
    ok_json conn, %{rooms: items}
  end

end
