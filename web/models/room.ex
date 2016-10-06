defmodule Asdf.Room do
  use Asdf.Web, :model
  
  alias Asdf.Repo

  schema "rooms" do
    field :user_id, :integer
    field :name, :string
    field :is_public, :boolean, default: true
    field :first_msg_id, :integer, default: 0
    field :last_msg_id, :integer, default: 0
    field :type, :integer, default: 0

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:user_id, :name, :is_public, :first_msg_id, :last_msg_id, :type])
    |> validate_required([:user_id, :name, :is_public])
  end

  @doc """
  Return the creator of this room
  """
  def user!(room) do
    Repo.get!(Asdf.User, room.user_id)
  end

  def user(room) do
    Repo.get(Asdf.User, room.user_id)
  end

  def get_full_name(room) do
    room_user = user(room)
    "#{room_user.name}/#{room.name}"
  end
  
  def create(user, name) do
    max_msg_id = Repo.one!(from m in Asdf.Msg,
                           select: max(m.id))
    rec = %Asdf.Room{user_id: user.id,
                      name: name,
                      type: 0,
                      is_public: true,
                      first_msg_id: 0,
                      last_msg_id: max_msg_id}
    
    Repo.insert!(rec)
  end

  def get_json(room) do
    if room.user_id == 0 do
      get_json(room, nil)
    else
      user = user(room)
      get_json(room, user)
    end
  end

  def get_json(room, nil) do
    %{id: room.id,
      user_id: 0,
      user_name: "",
      name: room.name,
      first_msg_id: room.first_msg_id,
      last_msg_id: room.last_msg_id,
      type: get_type_display(room)
     }
  end
  
  def get_json(room, user) do
    %{id: room.id,
      user_id: user.id,
      user_name: user.name,
      name: room.name,
      first_msg_id: room.first_msg_id,
      last_msg_id: room.last_msg_id,
      type: get_type_display(room)
     }
  end

  def get_json_via_user(room, curr_user) do
    json = get_json(room)
    if room.type == 1 do
      # directmsg
      peer = Repo.one(from member in Asdf.RoomMember,
        join: user in Asdf.User,
        on: member.user_id == user.id,
        where: member.room_id == ^room.id,
        where: user.id != ^curr_user.id,
        select: user,
        limit: 1)

      start_options =
      if peer.args != nil do
        peer.args["start_options"]
      else
        nil
      end
      
      json
      |> Map.put("peer_id", peer.id)
      |> Map.put("peer_name", Asdf.User.get_user_name(peer))
      |> Map.put("peer_start_menu", start_options)
    else
      json
    end
  end

  def get_room!(room_name) do
    case Asdf.Util.parse_entity(room_name) do
      {:room, user_name, room_name} ->
        user = Repo.get_by!(Asdf.User, name: user_name)
        Repo.get_by!(Asdf.Room, user_id: user.id, name: room_name)
      {:room_id, room_id} ->
        Repo.get!(Asdf.Room, room_id)
      _ ->
        Repo.get!(Asdf.Room, 0)
    end
  end
  
  def get_room(nil), do: nil
  def get_room(room_name) do
    case Asdf.Util.parse_entity(room_name) do
      {:room, user_name, room_name} ->
        user = Repo.get_by(Asdf.User, name: user_name)
        Repo.get_by(Asdf.Room, user_id: user.id, name: room_name)
      {:room_id, room_id} ->
        Repo.get(Asdf.Room, room_id)
      _ -> nil
    end
  end

  def get_chat_room(target, current_user) do
    current_name = current_user.name
    current_user_id = current_user.id
    {:ok, r} = Repo.transaction(fn ->
      case Asdf.Util.parse_entity(target) do
        {:room, user_name, room_name} ->
          user = Repo.get_by(Asdf.User, name: user_name)
          Repo.get_by(Asdf.Room,
            user_id: user.id,
            name: room_name)
        {:room_id, room_id} ->
          Repo.get(Asdf.Room, room_id)
        {:user_id, ^current_user_id} -> nil
        {:user_id, user_id} ->
          Repo.get_by(Asdf.User, id: user_id, is_active: true)
          |> get_directmsg_room(current_user)
        {:user, ^current_name} -> nil            
        {:user, user_name} ->
            Repo.get_by(Asdf.User, name: user_name, is_active: true)
            |> get_directmsg_room(current_user)
          {:bot, user_name, bot_name} ->
            Asdf.User.get_bot_user(user_name, bot_name)
            |> get_directmsg_room(current_user)
        _ -> nil
      end
    end)
    r
  end

  def get_type_display(room) do
    case room.type do
      0 ->
        "regular"
      1 ->
        "directmsg"
    end
  end

  def get_directmsg_room(_user1, nil), do: nil
  def get_directmsg_room(nil, _user2), do: nil
  def get_directmsg_room(user1, user2) when user1 != nil and user2 != nil do
    if user1.id == user2.id do
      nil
    else
      get_directmsg_room_u2u(user1, user2)
    end
  end
  
  def get_directmsg_room_u2u(user1, user2) do
    room_name =
    if user1.id < user2.id do
      "@#{user1.id}-@#{user2.id}"
    else
      "@#{user2.id}-@#{user1.id}"
    end
    case Repo.get_by(Asdf.Room, user_id: 0, name: room_name) do
      nil ->
        max_msg_id = Repo.one!(from m in Asdf.Msg,
                               select: max(m.id))
        room = %Asdf.Room{user_id: 0,
                           name: room_name,
                           is_public: false,
                           type: 1,
                           first_msg_id: 0,
                           last_msg_id: max_msg_id}
        room = room |> Repo.insert!
        Asdf.RoomMember.upsert(room, user1)
        Asdf.RoomMember.upsert(room, user2)
        room
      room -> room
    end
  end

end
