defmodule Asdf.HomeController do
  use Asdf.Web, :controller
  
  def index(conn, _params) do
    cu = current_user(conn)
    IO.puts "current user"
    IO.inspect cu
    IO.puts "ok"
    if cu do
      conn
      |> put_layout(false)
      |> render("index.html")
    else      
      conn
      |> redirect(to: "/")
    end
  end

end
