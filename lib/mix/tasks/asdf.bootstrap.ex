defmodule Mix.Tasks.Asdf.Bootstrap do
  use Mix.Task

  alias Asdf.User
  alias Asdf.Repo
  
  def run(_args) do
    Mix.Task.run "app.start", []

    Repo.transaction(fn -> 
      user = User.create("system", 0)
      IO.puts "create bot system/assist"
      
      User.create_bot(
        user,
        "assist",
        %{"callback_url" => "/bot/assist",
          "start_options"=> [
            %{"label"=> "Profile", "value"=> "profile_action"},
            %{"label"=> "Room", "value"=> "room_action"}
           ]})
    end)

    IO.puts "to create user & password use"
    IO.puts "mix asdf.user.password <username>"
  end

end
