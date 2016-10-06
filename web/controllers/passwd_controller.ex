defmodule Asdf.PasswdController do
  use Asdf.Web, :controller

  alias Asdf.Repo
  alias Asdf.UserAuth
  
  def index(conn, _params) do
    render conn, "auth.html"
  end

  def auth(conn, params) do
    user_name = params["username"]
    passwd = params["passwd"]
    
    ua = Repo.get_by(UserAuth, user_name: user_name)

    cond do
      ua != nil and passwd != nil and Asdf.Util.check_password(ua.token, passwd) ->
        ua = ua |> Repo.preload(:user)
        conn
        |> Asdf.Session.put_current_user(ua.user)
        |> redirect(to: "/")
      true ->
        conn
        |> put_flash(:error, "fail to login using user/password")
        |> render("auth.html")
    end
  end
end
