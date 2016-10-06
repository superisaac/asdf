defmodule Asdf.Session do
  
  def current_user(conn) do
    case conn.assigns[:current_user] do
      nil ->
        user_uuid = Plug.Conn.get_session(conn, :cuid)
        if is_binary(user_uuid) do
          user = Asdf.Repo.get_by(Asdf.User,
            uuid: user_uuid,
            is_active: true)
          user
        end
      user -> user
    end
  end

  def put_current_user(conn, user) do
    conn
    |> Plug.Conn.put_session(:cuid, user.uuid)
    |> Plug.Conn.assign(:current_user, user)
    |> gen_session_token
  end

  def put_current_user(conn, user, bot) do
    conn
    |> put_current_user(user)
    |> Plug.Conn.assign(:bot, bot)
  end

  def logged_in?(conn) do
    !!current_user(conn)
  end

  def get_session_token(conn) do
    Plug.Conn.get_session(conn, :session_token)
  end

  def gen_session_token(conn) do
    token = UUID.uuid4()
    Plug.Conn.put_session(conn, :session_token, token)
  end

end
