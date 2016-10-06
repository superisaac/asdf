defmodule Asdf.Plugs.BotSignature do
  import Ecto.Query
  alias Asdf.Repo
  alias Asdf.User
  alias Asdf.Util
  alias Asdf.Cred

  def init(default), do: default

  def call(conn, _options) do
    [bot_id] = Plug.Conn.get_req_header(conn, "x-bot-id")

    bot_user = User.get_user(bot_id) |> User.filter_active_user()
    
    [nonce] = Plug.Conn.get_req_header(conn, "x-bot-nonce")
    [sig] = Plug.Conn.get_req_header(conn, "x-bot-signature")

    if check_signature(bot_user, nonce, sig) do
      conn
      |> Plug.Conn.assign(:bot_user, bot_user)
    else
      conn
      |> Plug.Conn.send_resp(403, "403 Access Denied\n")
      |> Plug.Conn.halt
    end
  end

  def check_signature(nil, _nonce, _sig), do: false
  def check_signature(_bot_user, nil, _sig), do: false
  def check_signature(_bot_user, _nonce, nil), do: false
 
  def check_signature(bot_user, nonce, sig) do
      cred = Repo.one(from c in Cred,
                      where: c.user_id == ^bot_user.id,
                      where: c.name == "default")
      if cred do
        sig == Util.make_signature(nonce,
                                         "#{bot_user.id}",
                                         cred.secret)
      else
        false
      end
  end  
end
