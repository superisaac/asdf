defmodule Asdf.PageController do
  use Asdf.Web, :controller
  
  def index(conn, _params) do
    if logged_in?(conn) do
      redirect conn, to: "/home"
    else
      render conn, "index.html"
    end
  end

  def logout(conn, _params) do
    conn
    |> Plug.Conn.clear_session
    |> redirect(to: "/")
  end
end
