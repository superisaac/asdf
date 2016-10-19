defmodule Asdf.User do
  use Asdf.Web, :model

  alias Asdf.Repo
  
  schema "users" do
    field :uuid, :string
    field :name, :string
    field :fullname, :string
    field :is_active, :boolean, default: true
    field :parent_id, :integer, null: true, default: 0
    field :args, :map
 
    has_many :auths, Asdf.UserAuth

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:uuid, :name, :fullname, :parent_id, :args])
    |> validate_required([:uuid, :name, :fullname, :parent_id])
  end

  def get_json(user, nil) when user != nil do
    %{id: user.id, name: user.name, parent_id: 0, parent_name: nil}
  end

  def get_json(user, parent) when user != nil and parent != nil do
    %{id: user.id, name: user.name, parent_id: parent.id, parent_name: parent.name}
  end

  def get_user_name(user) do
    if is_bot(user) do
      parent = get_parent(user)
      "#{parent.name}/#{user.name}"
    else
      user.name
    end
  end

  def filter_active_user(user) do
    if user != nil and user.is_active do
      user
    else
      nil
    end
  end
  
  def get_json(user) when user != nil do
    parent = Repo.get(Asdf.User, user.parent_id)
    get_json(user, parent)
  end

  def is_bot(nil), do: false
  def is_bot(user) when user != nil do
    user.parent_id != 0 and user.parent_id != nil
  end

  def get_parent(user) when user != nil do
    if !!user.parent_id do
      Repo.get(Asdf.User, user.parent_id)
    else
      nil
    end
  end

  def create(user_auth) do
    user_uuid = UUID.uuid4()
    user = %Asdf.User{uuid: user_uuid,
                       name: user_auth.user_name,
                       fullname: user_auth.user_name}
    # TODO: unique user name
    user = Repo.insert!(user)
    _cred = Asdf.Cred.create(user, "default")
    cset = Asdf.UserAuth.changeset(user_auth, %{user_id: user.id})
    user_auth = cset |> Repo.update! |> Repo.preload(:user)
    # create default room
    room = Asdf.Room.create(user_auth.user, "general")
    _lm = Asdf.RoomMember.create(room, user_auth.user, true)
    user
  end

  def create(name, parent_id, args \\ %{}) do
    user_uuid = UUID.uuid4()
    user = %Asdf.User{
      uuid: user_uuid,
      name: name,
      fullname: name,
      parent_id: parent_id,
      args: args}
    user = Repo.insert!(user)
    _cred = Asdf.Cred.create(user, "default")
    if parent_id != 0 and parent_id != nil do
      room = Asdf.Room.create(user, "general")
      _lm = Asdf.RoomMember.create(room, user, true)
    end
    user
  end
  
  def create_bot(user, name, args \\ %{}) do
    if Asdf.User.is_bot(user) do
      parent = Asdf.User.get_parent(user)
      create_bot(parent, name)
    else
      create(name, user.id, args)
    end
  end

  def get_bot_user(name, bot_name) do
    parent = Repo.get_by(Asdf.User,
                         name: name, is_active: true)
    if parent != nil do
      Repo.get_by(Asdf.User,
                  name: bot_name,
                  parent_id: parent.id,
                  is_active: true)
    else
      nil
    end
  end

  def post_api(user, url, params \\ []) do
    cred = Repo.get_by!(Asdf.Cred,
                        user_id: user.id,
                        name: "default")
    user_name = Asdf.User.get_user_name(user)
    auth = user_name <> ":" <> cred.secret
    auth = "Basic " <> Base.encode64(auth)

    body = URI.encode_query(params)
    r = HTTPoison.post!(url, body,
                        ["Content-Type": "application/x-www-form-urlencoded",
                         "Authorization": auth])

    Poison.decode!(r.body)
  end


  def post_json_api(user, url, params \\ %{}) do
    cred = Repo.get_by!(Asdf.Cred,
                        user_id: user.id,
                        name: "default")
    user_name = Asdf.User.get_user_name(user)
    auth = user_name <> ":" <> cred.secret
    auth = "Basic " <> Base.encode64(auth)

    body = Poison.encode!(params)
    r = HTTPoison.post!(url, body,
                        ["Content-Type": "application/json;charset=utf-8",
                         "Authorization": auth])

    Poison.decode!(r.body)
  end

  
  
  def get_user(nil), do: nil
  def get_user(username) when username != nil do
    case Asdf.Util.parse_entity("@" <> username) do
      {:user_id, user_id} ->
        Repo.get_by(Asdf.User, id: user_id)
      {:user, user_name} ->
        Repo.get_by(Asdf.User, name: user_name)
      {:bot, user_name, bot_name} ->
        get_bot_user(user_name, bot_name)
      _ -> nil
    end
  end

  def put_args(user, args) do
    new_args =
    if user.args != nil do
      Map.merge(user.args, args)
    else
      args
    end
    cset = changeset(user, new_args)
    Asdf.Repo.update!(cset)
  end
   
end
