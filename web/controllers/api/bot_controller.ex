defmodule Asdf.Api.BotController do
  use Asdf.Web, :controller

  alias Asdf.Repo
  
  def create_bot(conn, params) do
    curr_user = Asdf.Session.current_user(conn)
    name = Asdf.Util.valid_ident(params["name"])
    cond do
      name == nil ->
        error_json conn, "invalid_bot_name"
      Repo.get_by(Asdf.User, parent_id: curr_user.id, name: name) != nil ->
        error_json conn, "bot_already_exist"
      true ->
        bot_user = Asdf.User.create_bot(curr_user, name)
        cred = Repo.one(Asdf.Cred, user_id: bot_user.id)
        ok_json conn, %{:user => Asdf.User.get_json(bot_user, curr_user),
                        :cred => Asdf.Cred.get_json(cred)}
    end    
  end

  def deactivate_bot(conn, params) do
    curr_user = Asdf.Session.current_user(conn)
    name = Asdf.Util.valid_ident(params["name"])
    cond do
      name == nil ->
        error_json conn, "invalid_bot_name"
      Repo.get_by(Asdf.User, parent_id: curr_user.id, name: name) == nil ->
        error_json conn, "bot_not_exist"
      true ->
        bot_user = Repo.get_by(Asdf.User, parent_id: curr_user.id, name: name)
        cset = Asdf.User.changeset(bot_user, %{is_active: false})
        bot_user = Repo.update!(cset)
        ok_json conn, %{}
    end    
  end

  def bot_list(conn, _params) do
    curr_user = Asdf.Session.current_user(conn)
    q = Repo.all(from user in Asdf.User,
                 where: user.parent_id == ^curr_user.id)
    items = q |> Enum.map(fn(bot) ->
      cred = Repo.one(Asdf.Cred, user_id: bot.id)
      %{:user => Asdf.User.get_json(bot, curr_user),
        :cred => Asdf.Cred.get_json(cred)}
    end)
    ok_json conn, %{bots: items}
  end
end
